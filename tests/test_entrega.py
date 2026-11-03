"""Teste real do pacote extraido. Requer psycopg e ollama do requirements.txt.

Cria bases novas numa instancia EXCLUSIVA de testes, nunca altera a base original.
Uso: python tests/test_entrega.py --conexao conexao-teste.json --pacote entrega.zip
     --trabalho pasta-temporaria --relatorio resultado.json [--testar-ollama]
"""
from pathlib import Path
import argparse
import concurrent.futures
import contextlib
import hashlib
import importlib.util
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import uuid
import zipfile

import psycopg
from psycopg import sql

ROOT = Path(__file__).resolve().parent.parent


class Validacao:
    def __init__(self, args):
        self.args = args
        self.cfg = json.loads(args.conexao.read_text(encoding='utf-8'))
        self.resultados = []
        self.evidencia = {'testes':self.resultados}
        args.trabalho.mkdir(parents=True,exist_ok=True)
        self.pasta = Path(tempfile.mkdtemp(prefix='pacote-extraido-',dir=args.trabalho)).resolve()

    def verificar(self, condicao, nome, detalhe=None):
        self.resultados.append({'teste':nome,'aprovado':bool(condicao),'detalhe':detalhe})
        print(('PASS: ' if condicao else 'FALHA: ')+nome,flush=True)
        if not condicao:
            raise AssertionError(f'{nome}: {detalhe}')

    def conexao(self, nome=None, **kwargs):
        cfg = {**self.cfg}
        if nome:
            cfg['dbname'] = nome
        kwargs.setdefault('connect_timeout',5)
        return psycopg.connect(**cfg, **kwargs)

    def criar_base(self, tipo):
        nome = 'scc0640_'+tipo+'_'+uuid.uuid4().hex[:10]
        with self.conexao(autocommit=True) as c:
            c.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(nome)))
        return nome

    def extrair(self, arquivo, destino):
        with zipfile.ZipFile(arquivo) as z:
            for i in z.infolist():
                p = (destino/i.filename).resolve()
                if not p.is_relative_to(destino.resolve()) or i.file_size > 20_000_000:
                    raise ValueError('Entrada de ZIP inesperada')
            z.extractall(destino)

    @staticmethod
    def executar_script(c, texto):
        resultados = []
        with c.cursor() as cur:
            cur.execute(texto,prepare=False)
            while True:
                if cur.description:
                    nomes = [x.name for x in cur.description]
                    resultados += [dict(zip(nomes,linha)) for linha in cur.fetchall()]
                if not cur.nextset():
                    break
        return resultados

    def carregar_pacote(self):
        self.extrair(self.args.pacote,self.pasta)
        raiz = self.pasta/'ProjetoBD'
        esperados = {'ER.pdf','ER.xml','Relacional.pdf','Relacional.mmd',
                     'Projeto.txt','DML.sql','Prototipo.zip','Instrucoes.txt'}
        self.verificar({x.name for x in raiz.iterdir()} == esperados,'oito artefatos finais, sem arquivos estranhos')
        self.extrair(raiz/'Prototipo.zip',raiz)
        self.verificar({x.name for x in (raiz/'Prototipo').iterdir()} == {'main.py','config.json','requirements.txt'},
                       'prototipo contem somente os tres arquivos exigidos')
        config = json.loads((raiz/'Prototipo/config.json').read_text(encoding='utf-8'))
        self.verificar(config['database']['password']=='ALTERE_AQUI','configuracao distribuivel nao usa senha real')
        self.verificar((raiz/'DML.sql').read_bytes()==(ROOT/'sql/03_dml.sql').read_bytes(),'DML entregue identico a fonte de Lucas')
        self.verificar((raiz/'ER.xml').read_bytes()==(ROOT/'docs/modelagem/ER.drawio').read_bytes(),'XML E/R preserva fonte editavel')
        self.verificar((raiz/'Relacional.mmd').read_bytes()==(ROOT/'docs/modelagem/Relacional.mmd').read_bytes(),'fonte Mermaid entregue preservado')
        spec=importlib.util.spec_from_file_location('prototipo_extraido',raiz/'Prototipo/main.py')
        self.mod=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.raiz=raiz
        self.texto=(raiz/'Projeto.txt').read_text(encoding='utf-8')
        self.ddl=self.mod.extrair_ddl(self.texto)
        self.consultas=self.mod.extrair_consultas(self.texto)
        instr=(raiz/'Instrucoes.txt').read_text(encoding='utf-8')
        comando=re.search(r'^  python -c "(.*)"$',instr,re.MULTILINE).group(1)
        subprocess.run([sys.executable,'-c',comando],cwd=raiz,check=True,timeout=10)
        self.verificar((raiz/'DDL_extraido.sql').read_text(encoding='utf-8').strip()==self.ddl.strip(),
                       'comando de extracao das instrucoes reproduz o DDL usado pelo prototipo')
        self.verificar(not self.mod.validar_consultas(self.consultas),'parser le exatamente as cinco consultas do Projeto.txt')
        for n in range(1,7):
            self.verificar(bool(re.search(rf'^Q{n}: .+\S$',self.texto,re.MULTILINE)),f'Q{n} final em uma linha')
        self.verificar(not re.search(r'\[(resposta|consulta|Inserir|Descreva)',self.texto),'Projeto.txt sem placeholders')
        for consulta, fonte in zip(self.consultas,self._consultas_fonte()):
            self.verificar(consulta['sql'].strip()==fonte.strip(),f"consulta {consulta['numero']} identica a fonte de Lucas")

    def _consultas_fonte(self):
        texto=(ROOT/'sql/04_consultas.sql').read_text(encoding='utf-8')
        partes=re.split(r'^-- CONSULTA \d+\s*$',texto,flags=re.MULTILINE)[1:]
        return ['\n'.join(l for l in p.splitlines() if not l.startswith('--')).strip() for p in partes]

    def testar_baseline(self):
        nome=self.criar_base('ddl')
        with self.conexao(nome,autocommit=True) as c:
            self.executar_script(c,(ROOT/'sql/01_tabelas.sql').read_text(encoding='utf-8'))
            dados=self.executar_script(c,(ROOT/'tests/ddl_integridade.sql').read_text(encoding='utf-8'))
            aprovados=next(x['testes_aprovados'] for x in dados if 'testes_aprovados' in x)
            self.verificar(aprovados==125,'125 testes originais do DDL em base separada',aprovados)

    def testar_demo(self):
        self.demo=self.criar_base('entrega')
        with self.conexao(self.demo,autocommit=True) as c:
            self.evidencia['postgresql']=c.execute('select version()').fetchone()[0]
            self.executar_script(c,self.ddl)
            self.executar_script(c,(self.raiz/'DML.sql').read_text(encoding='utf-8'))
            self.verificar(c.execute("SELECT count(*) FROM pg_tables WHERE schemaname='public'").fetchone()[0]==16,'DDL extraido cria 16 tabelas')
            self.evidencia['triggers']=c.execute("SELECT tgname FROM pg_trigger t JOIN pg_class r ON r.oid=t.tgrelid WHERE r.relnamespace='public'::regnamespace AND NOT t.tgisinternal ORDER BY tgname").fetchall()
            self.verificar(len(self.evidencia['triggers'])==13,'treze triggers finais instalados (seis originais e sete de integracao)')
            self.verificar(c.execute('SELECT count(*) FROM pessoa').fetchone()[0]==30,'carga contem 30 pessoas sinteticas')
            self.verificar(c.execute('SELECT count(*) FROM historico_sessao WHERE id_sessao=13').fetchone()[0]==2,'historico da sessao 13 gerado por triggers')
            self.verificar(c.execute("SELECT status FROM inscricao_sessao WHERE id_sessao=9 AND id_pessoa=18").fetchone()[0]=='CONFIRMADA','cancelamento do DML promove a pessoa correta')
            self.verificar(c.execute("SELECT status FROM inscricao_sessao WHERE id_sessao=9 AND id_pessoa=19").fetchone()[0]=='LISTA_ESPERA','Q5 aceita espera sem inscricao geral')
        config={**self.cfg,'dbname':self.demo}
        exemplo={'database':config,'ollama':{'host':self.args.ollama_host,'model':self.args.modelo}}
        (self.raiz/'Prototipo/config.json').write_text(json.dumps(exemplo),encoding='utf-8')
        self.evidencia['query_counts']=[]
        with self.conexao(self.demo) as c:
            for consulta,esperado in zip(self.consultas,[19,19,11,12,10]):
                colunas,linhas=self.mod.executar_select(c,consulta['sql'])
                self.evidencia['query_counts'].append(len(linhas))
                self.verificar(len(linhas)==esperado,f"consulta {consulta['numero']} executada pelo prototipo",len(linhas))
            try:
                self.mod.executar_select(c,'SELECT coluna_inexistente FROM pessoa')
            except psycopg.errors.UndefinedColumn:
                pass
            else:
                raise AssertionError('Consulta invalida nao foi rejeitada')
            self.verificar(self.mod.executar_select(c,'SELECT count(*) FROM pessoa')[1][0][0]==30,'consulta valida apos erro SQL funciona')
            try:
                self.mod.executar_select(c,'DELETE FROM pessoa')
            except psycopg.errors.ReadOnlySqlTransaction:
                pass
            else:
                raise AssertionError('Escrita nao foi bloqueada')
            self.verificar(self.mod.executar_select(c,'SELECT count(*) FROM pessoa')[1][0][0]==30,'READ ONLY bloqueia escrita e recupera conexao')
            colunas,linhas=self.mod.executar_select(c,'SELECT nome FROM pessoa WHERE false')
            saida=io.StringIO()
            with contextlib.redirect_stdout(saida):self.mod.imprimir_tabela(colunas,linhas)
            self.verificar('nenhuma linha' in saida.getvalue(),'resultado vazio tem mensagem clara')
        env={**os.environ,'PYTHONIOENCODING':'utf-8'}
        entradas=''.join('1\n'+str(i)+'\n' for i in range(1,6))+'0\n'
        proc=subprocess.run([sys.executable,str(self.raiz/'Prototipo/main.py')],input=entradas,text=True,encoding='utf-8',capture_output=True,cwd=self.pasta,env=env,timeout=30)
        self.verificar(proc.returncode==0 and '[ERRO]' not in proc.stdout and proc.stdout.count('CONSULTA ')>=5,
                       'CLI extraida executa as cinco opcoes a partir de outra pasta',proc.stderr)
        (self.args.trabalho/'cli-consultas.log').write_text(proc.stdout,encoding='utf-8')
        projeto=self.raiz/'Projeto.txt'
        backup=self.raiz/'Projeto.txt.bak'
        projeto.rename(backup)
        try:
            proc=subprocess.run([sys.executable,str(self.raiz/'Prototipo/main.py')],input='0\n',text=True,encoding='utf-8',capture_output=True,cwd=self.pasta,env=env,timeout=15)
            self.verificar(proc.returncode==1 and 'nao encontrado' in proc.stdout,'Projeto.txt ausente encerra com erro conforme PDF')
        finally:backup.rename(projeto)

    def fixture(self,c,capacidade=2,limite=None):
        uid=uuid.uuid4().hex[:10]
        with c.transaction():
            e=c.execute('INSERT INTO evento(nome) VALUES (%s) RETURNING id_evento',('Fixture '+uid,)).fetchone()[0]
            p=c.execute("INSERT INTO promotor(nome,tipo,documento) VALUES (%s,'ORGANIZACAO',%s) RETURNING id_promotor",('Fixture '+uid,uid)).fetchone()[0]
            ed=c.execute("INSERT INTO edicao(id_evento,ano,data_inicio,data_fim) VALUES (%s,2026,'2026-11-01','2026-11-03') RETURNING id_edicao",(e,)).fetchone()[0]
            c.execute("INSERT INTO edicao_promotor VALUES (%s,%s,'principal')",(ed,p))
            a=c.execute("INSERT INTO atividade(id_edicao,titulo,tipo) VALUES (%s,%s,'teste') RETURNING id_atividade",(ed,'Fixture '+uid)).fetchone()[0]
            sala=c.execute("INSERT INTO espaco(nome,tipo,capacidade) VALUES (%s,'teste',%s) RETURNING id_espaco",('Fixture '+uid,capacidade)).fetchone()[0]
            s=c.execute("INSERT INTO sessao(id_atividade,id_espaco,data,hora_inicio,hora_fim,vagas_limite) VALUES (%s,%s,'2026-11-02','09:00','10:00',%s) RETURNING id_sessao",(a,sala,limite)).fetchone()[0]
            pessoas=[c.execute('INSERT INTO pessoa(nome,email) VALUES (%s,%s) RETURNING id_pessoa',('Fixture '+uid+str(i),uid+str(i)+'@example.invalid')).fetchone()[0] for i in range(3)]
        return {'evento':e,'edicao':ed,'atividade':a,'espaco':sala,'sessao':s,'pessoas':pessoas}

    def concorrencia(self,base,preparar,concorrente,nome,esperado):
        t1=self.conexao(base)
        try:
            preparar(t1)
            pronto=threading.Event()
            backend={}
            def executar():
                try:
                    with self.conexao(base) as t2:
                        t2.execute("SET LOCAL lock_timeout='6s'")
                        backend['pid']=t2.info.backend_pid
                        pronto.set()
                        concorrente(t2)
                    return 'COMMIT'
                except psycopg.Error as e:
                    return e.sqlstate
            with concurrent.futures.ThreadPoolExecutor() as pool:
                futuro=pool.submit(executar)
                pronto.wait(timeout=2)
                espera=None
                with self.conexao(base,autocommit=True) as observador:
                    limite=time.monotonic()+2
                    while backend.get('pid') and time.monotonic()<limite and not futuro.done():
                        espera=observador.execute('SELECT wait_event_type,wait_event FROM pg_stat_activity WHERE pid=%s',(backend['pid'],)).fetchone()
                        if espera and espera[0]=='Lock':break
                        time.sleep(0.05)
                bloqueado=bool(espera and espera[0]=='Lock' and espera[1]=='advisory')
                t1.commit()
                resultado=futuro.result(timeout=10)
            self.verificar(bloqueado and resultado==esperado,nome,{'aguardou_sem_retry':bloqueado,'wait_event':espera,'resultado':resultado})
        finally:t1.close()

    def testar_integridade(self):
        base=self.criar_base('regressao')
        with self.conexao(base,autocommit=True) as c:
            self.executar_script(c,self.ddl)
            notices=[]
            c.add_notice_handler(lambda n:notices.append(n.message_primary))
            self.executar_script(c,(ROOT/'tests/test_triggers.sql').read_text(encoding='utf-8'))
            self.verificar(all(any(f'TESTE {i:02d} APROVADO' in n for n in notices) for i in range(2,19)),
                           'testes funcionais 02 a 18 de Marcela aprovados')
            f=self.fixture(c)
            self.concorrencia(base,
                lambda t:t.execute('INSERT INTO inscricao_sessao(id_sessao,id_pessoa) VALUES (%s,%s),(%s,%s)',(f['sessao'],f['pessoas'][0],f['sessao'],f['pessoas'][1])),
                lambda t:t.execute('UPDATE espaco SET capacidade=1 WHERE id_espaco=%s',(f['espaco'],)),
                'corrida inscricao versus reducao da sala corrigida','P0001')
            self.verificar(c.execute("SELECT count(*) FROM inscricao_sessao WHERE id_sessao=%s AND status='CONFIRMADA'",(f['sessao'],)).fetchone()[0]==2 and c.execute('SELECT capacidade FROM espaco WHERE id_espaco=%s',(f['espaco'],)).fetchone()[0]==2,'capacidade final comporta todas as confirmacoes')
            f=self.fixture(c,1,1)
            self.concorrencia(base,
                lambda t:t.execute('INSERT INTO inscricao_sessao(id_sessao,id_pessoa) VALUES (%s,%s)',(f['sessao'],f['pessoas'][0])),
                lambda t:t.execute('INSERT INTO inscricao_sessao(id_sessao,id_pessoa) VALUES (%s,%s)',(f['sessao'],f['pessoas'][1])),
                'duas conexoes disputam ultima vaga sem retry','COMMIT')
            self.verificar(c.execute("SELECT status FROM inscricao_sessao WHERE id_sessao=%s AND id_pessoa=%s",(f['sessao'],f['pessoas'][1])).fetchone()[0]=='LISTA_ESPERA','segunda inscricao concorrente entra na espera')
            f=self.fixture(c)
            self.concorrencia(base,
                lambda t:t.execute("INSERT INTO sessao(id_atividade,id_espaco,data,hora_inicio,hora_fim) VALUES (%s,%s,'2026-11-02','13:00','14:00')",(f['atividade'],f['espaco'])),
                lambda t:t.execute("INSERT INTO sessao(id_atividade,id_espaco,data,hora_inicio,hora_fim) VALUES (%s,%s,'2026-11-02','13:30','14:30')",(f['atividade'],f['espaco'])),
                'agendamentos concorrentes conflitantes rejeitados sem retry','P0001')
            f=self.fixture(c,3,2)
            self.concorrencia(base,
                lambda t:t.execute('INSERT INTO inscricao_sessao(id_sessao,id_pessoa) VALUES (%s,%s),(%s,%s)',(f['sessao'],f['pessoas'][0],f['sessao'],f['pessoas'][1])),
                lambda t:t.execute('UPDATE sessao SET vagas_limite=1 WHERE id_sessao=%s',(f['sessao'],)),
                'reducao concorrente de limite rejeitada apos novas inscricoes','P0001')
            for rotulo,comando,params,codigo in [
                ('status invalido nao e convertido silenciosamente',"INSERT INTO inscricao_sessao(id_sessao,id_pessoa,status) VALUES (%s,%s,'INVALIDO')",(f['sessao'],f['pessoas'][2]),'23514'),
                ('status NULL nao e convertido silenciosamente',"INSERT INTO inscricao_sessao(id_sessao,id_pessoa,status) VALUES (%s,%s,NULL)",(f['sessao'],f['pessoas'][2]),'23502'),
                ('edicao nao pode perder seu ultimo promotor','DELETE FROM edicao_promotor WHERE id_edicao=%s',(f['edicao'],),'23514'),
                ('evento sem edicao rejeitado no COMMIT',"INSERT INTO evento(nome) VALUES ('Orfao')",None,'23514'),
                ('edicao sem promotor rejeitada no COMMIT',"INSERT INTO edicao(id_evento,ano,data_inicio,data_fim) VALUES (%s,2027,'2027-01-01','2027-01-02')",(f['evento'],),'23514'),
            ]:
                try:
                    with c.transaction():c.execute(comando,params)
                except psycopg.Error as err:self.verificar(err.sqlstate==codigo,rotulo,err.sqlstate)
                else:self.verificar(False,rotulo,'operacao indevida aceita')
            with c.transaction():
                evento=c.execute("INSERT INTO evento(nome) VALUES ('Pai minimo') RETURNING id_evento").fetchone()[0]
                edicao=c.execute("INSERT INTO edicao(id_evento,ano,data_inicio,data_fim) VALUES (%s,2030,'2030-01-01','2030-01-02') RETURNING id_edicao",(evento,)).fetchone()[0]
                promotor=c.execute("INSERT INTO promotor(nome,tipo,documento) VALUES ('Pai minimo','PESSOA',%s) RETURNING id_promotor",(uuid.uuid4().hex,)).fetchone()[0]
                c.execute("INSERT INTO edicao_promotor VALUES (%s,%s,'principal')",(edicao,promotor))
            try:
                with c.transaction():
                    c.execute('DELETE FROM edicao_promotor WHERE id_edicao=%s',(edicao,))
                    c.execute('DELETE FROM edicao WHERE id_edicao=%s',(edicao,))
            except psycopg.errors.CheckViolation:self.verificar(True,'evento nao pode perder sua ultima edicao')
            else:self.verificar(False,'evento nao pode perder sua ultima edicao')
            with c.transaction():
                c.execute('DELETE FROM edicao_promotor WHERE id_edicao=%s',(edicao,))
                c.execute('DELETE FROM edicao WHERE id_edicao=%s',(edicao,))
                c.execute('DELETE FROM evento WHERE id_evento=%s',(evento,))
                c.execute('DELETE FROM promotor WHERE id_promotor=%s',(promotor,))
            self.verificar(not c.execute('SELECT 1 FROM evento WHERE id_evento=%s',(evento,)).fetchone(),'remocao completa do conjunto nao gera falso orfao')
            f=self.fixture(c,1,1)
            c.execute('INSERT INTO inscricao_sessao(id_sessao,id_pessoa) VALUES (%s,%s),(%s,%s)',(f['sessao'],f['pessoas'][0],f['sessao'],f['pessoas'][1]))
            c.execute("UPDATE inscricao_sessao SET status='CANCELADA' WHERE id_sessao=%s AND id_pessoa=%s",(f['sessao'],f['pessoas'][1]))
            self.verificar(c.execute("SELECT count(*) FROM inscricao_sessao WHERE id_sessao=%s AND status='CONFIRMADA'",(f['sessao'],)).fetchone()[0]==1,'cancelamento da espera nao promove nem remove confirmacao')
            c.execute("UPDATE sessao SET status='CANCELADA' WHERE id_sessao=%s",(f['sessao'],))
            c.execute("INSERT INTO sessao(id_atividade,id_espaco,data,hora_inicio,hora_fim) VALUES (%s,%s,'2026-11-02','09:00','10:00')",(f['atividade'],f['espaco']))
            try:
                c.execute("UPDATE sessao SET status='AGENDADA' WHERE id_sessao=%s",(f['sessao'],))
            except psycopg.Error:self.verificar(True,'reativacao revalida conflito com sessao nova')
            else:self.verificar(False,'reativacao revalida conflito com sessao nova')

    def testar_ollama(self):
        cliente=self.mod.criar_cliente_ollama({'host':self.args.ollama_host})
        self.evidencia['ollama_version']=cliente.version().get('version')
        self.evidencia['modelo']=self.args.modelo
        esquema=self.mod.resumir_esquema(self.ddl)
        perguntas=[
            ('Quantas pessoas estao cadastradas? Retorne uma unica coluna total com COUNT(*).',[(30,)]),
            ('Liste somente id_atividade e titulo das atividades do tipo workshop, ordenadas por id_atividade.',None),
            ('Quais sessoes estao lotadas? Retorne somente id_sessao em ordem crescente.',[(8,),(9,),(18,)]),
        ]
        with self.conexao(self.demo) as c:
            perguntas[1]=(perguntas[1][0],self.mod.executar_select(c,"SELECT id_atividade,titulo FROM atividade WHERE tipo='workshop' ORDER BY id_atividade")[1])
            detalhes=[]
            for pergunta,esperado in perguntas:
                inicio=time.monotonic()
                comando=self.mod.gerar_sql(cliente,self.args.modelo,esquema,pergunta)
                validado,erro=self.mod.validar_sql_gerado(comando)
                self.verificar(not erro,'Ollama real gera consulta unica de leitura',erro)
                colunas,linhas=self.mod.executar_select(c,validado)
                self.verificar(linhas==esperado,'resultado do Ollama real confere com banco',{'pergunta':pergunta,'sql':validado,'linhas':linhas})
                detalhes.append({'pergunta':pergunta,'sql':validado,'linhas':linhas,'segundos':round(time.monotonic()-inicio,2)})
            self.evidencia['ollama_perguntas']=detalhes
        env={**os.environ,'PYTHONIOENCODING':'utf-8'}
        proc=subprocess.run([sys.executable,str(self.raiz/'Prototipo/main.py')],
            input='2\nQuantas pessoas estao cadastradas? Retorne COUNT(*) AS total.\n0\n',
            text=True,encoding='utf-8',capture_output=True,cwd=self.pasta,env=env,timeout=600)
        self.verificar(proc.returncode==0 and '[ERRO]' not in proc.stdout and '30' in proc.stdout,
                       'CLI extraida completa caminho pergunta-Ollama-banco-resultado',proc.stderr)
        (self.args.trabalho/'cli-ollama.log').write_text(proc.stdout,encoding='utf-8')

    def executar(self):
        try:
            if self.args.retomar:
                contexto=json.loads((self.args.trabalho/'contexto-validacao.json').read_text(encoding='utf-8'))
                atual=hashlib.sha256(self.args.pacote.read_bytes()).hexdigest()
                if atual!=contexto['pacote_sha256']:
                    raise ValueError('Pacote mudou; executar novamente a validacao completa')
                self.evidencia=json.loads(self.args.relatorio.read_text(encoding='utf-8'))
                self.resultados=self.evidencia['testes']
                self.raiz=Path(contexto['raiz']);self.demo=contexto['demo']
                spec=importlib.util.spec_from_file_location('prototipo_extraido',self.raiz/'Prototipo/main.py')
                self.mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.mod)
                self.ddl=self.mod.extrair_ddl((self.raiz/'Projeto.txt').read_text(encoding='utf-8'))
            else:
                self.carregar_pacote()
                self.testar_baseline()
                self.testar_demo()
                self.testar_integridade()
                (self.args.trabalho/'contexto-validacao.json').write_text(json.dumps({
                    'raiz':str(self.raiz),'demo':self.demo,
                    'pacote_sha256':hashlib.sha256(self.args.pacote.read_bytes()).hexdigest()}),encoding='utf-8')
            if self.args.testar_ollama:self.testar_ollama()
            self.evidencia['ollama_testado']=self.args.testar_ollama
            self.evidencia['aprovado']=True
        except Exception as err:
            self.evidencia['aprovado']=False
            self.evidencia['erro']=str(err)
            raise
        finally:
            self.evidencia['quantidade_testes']=len(self.resultados)
            self.evidencia['pacote_sha256']=hashlib.sha256(self.args.pacote.read_bytes()).hexdigest()
            self.evidencia['python']=sys.version.split()[0]
            self.args.relatorio.parent.mkdir(parents=True,exist_ok=True)
            self.args.relatorio.write_text(json.dumps(self.evidencia,ensure_ascii=False,indent=2,default=str),encoding='utf-8')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--conexao',type=Path,required=True)
    p.add_argument('--pacote',type=Path,required=True)
    p.add_argument('--trabalho',type=Path,required=True)
    p.add_argument('--relatorio',type=Path,required=True)
    p.add_argument('--testar-ollama',action='store_true')
    p.add_argument('--retomar',action='store_true',help='Retoma apenas Ollama sobre o mesmo pacote/base ja validados')
    p.add_argument('--ollama-host',default='http://localhost:11434')
    p.add_argument('--modelo',default='qwen3:8b')
    Validacao(p.parse_args()).executar()
