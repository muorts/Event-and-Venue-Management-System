"""Gera os artefatos finais exclusivamente a partir das fontes do repositorio.

Uso: python scripts/preparar_entrega.py [--zip-final caminho.zip]
Nao le configuracoes locais nem inclui senhas reais, modelos ou ambientes virtuais.
"""
from pathlib import Path
import argparse
import json
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / 'entrega'
SEPARADOR = '=' * 60
MEMBROS = [
    ('Murilo Ortega Pereira', '16893917'),
    ('Victor Kayky Zaneti Antunes', '15491132'),
    ('João Marcelo Abreu dos Santos', '16876021'),
    ('Marcela Caprioli Alves', '16314271'),
    ('Lucas Waldrighi Lima', '16885286'),
]
MODELO = 'qwen3:8b'
CONFIG_EXEMPLO = {
    'database': {'host':'localhost','port':5432,'dbname':'eventos','user':'postgres','password':'ALTERE_AQUI'},
    'ollama': {'host':'http://localhost:11434','model':MODELO},
}
ARQUIVOS = ['ER.pdf','ER.xml','Relacional.pdf','Relacional.mmd',
            'Projeto.txt','DML.sql','Prototipo.zip','Instrucoes.txt']


def ler(nome):
    return (ROOT/nome).read_text(encoding='utf-8').strip()


def consultas():
    texto = ler('sql/04_consultas.sql')
    partes = re.split(r'^-- CONSULTA (\d+)\s*$', texto, flags=re.MULTILINE)
    resultado = []
    for i in range(1, len(partes), 2):
        numero, corpo = int(partes[i]), partes[i+1]
        objetivo = re.search(r'^-- OBJETIVO:\s*(.+)$', corpo, flags=re.MULTILINE)
        if objetivo is None:
            raise ValueError(f'Consulta {numero} sem objetivo')
        # Remove somente comentarios de linha de documentacao do Lucas.
        # SQL das cinco consultas e mantido, incluindo CTEs e multiplas linhas.
        linhas = corpo.splitlines()
        while linhas and (not linhas[0].strip() or linhas[0].startswith('--')):
            linhas.pop(0)
        sql = '\n'.join(linhas).strip()
        if not sql or not sql.endswith(';'):
            raise ValueError(f'Consulta {numero} incompleta')
        resultado.append((numero, objetivo.group(1).strip(), sql))
    if [n for n,_,_ in resultado] != [1,2,3,4,5]:
        raise ValueError('Esperadas exatamente as consultas 1 a 5')
    return resultado


def projeto():
    integrantes = '; '.join(f'{nome} - {nusp}' for nome,nusp in MEMBROS)
    decisoes = [
        'Promotores são entidade própria para pessoas ou organizações e se associam às edições por N:N, permitindo promoção conjunta.',
        'Pessoas têm cadastro único e podem acumular participante, organizador e palestrante/instrutor em associações específicas.',
        'Cada atividade pertence a uma edição e pode ter várias sessões; dados gerais ficam na atividade e data, horário, espaço e vagas na sessão.',
        'Evento é a iniciativa recorrente e edição é a realização identificada por evento e ano, com programação e inscrições próprias.',
        'A inscrição na edição é independente da inscrição em sessões; sessões com inscrição específica respeitam o menor limite entre capacidade física e vagas próprias, com lista de espera.',
        'A sessão guarda a programação atual e mudanças de data, horário ou espaço são preservadas em histórico por trigger.',
    ]
    descricao = (
        'Sistema de gestão da Semana da Computação e de outros eventos, distinguindo iniciativas recorrentes, '
        'edições anuais, atividades e suas sessões. Mantém promotores, pessoas e papéis por contexto, espaços, '
        'recursos, inscrições gerais e específicas, cancelamentos, fila de espera e histórico de programação. '
        'PostgreSQL implementa as 16 tabelas e as restrições, com triggers para vagas, promoção da espera, '
        'histórico, conflitos e proteção da capacidade; validações adiadas preservam as participações mínimas '
        'dos pais. O protótipo Python em linha de comando lê deste arquivo o esquema e as cinco consultas, '
        'conecta ao PostgreSQL, mostra resultados e usa Ollama local para converter perguntas em português em SQL de leitura.'
    )
    linhas = [SEPARADOR,'SCC0640 - PROJETO DE BASES DE DADOS',SEPARADOR,
              'GRUPO: Semana da Computação','INTEGRANTES: '+integrantes,
              'MODELO UTILIZADO NO OLLAMA: '+MODELO,SEPARADOR,
              '1. DESCRICAO FINAL DO SISTEMA',SEPARADOR,descricao,SEPARADOR,
              '2. DECISOES DE PROJETO',SEPARADOR]
    linhas += [f'Q{i}: {resposta}' for i,resposta in enumerate(decisoes,1)]
    linhas += [SEPARADOR,'3. DDL COMPLETO',SEPARADOR,ler('sql/01_tabelas.sql'),
               '', 'BEGIN;',ler('sql/02_triggers.sql'),'COMMIT;',SEPARADOR,
               '4. CONSULTAS',SEPARADOR]
    for numero,objetivo,sql in consultas():
        linhas += [f'CONSULTA {numero}','OBJETIVO: '+objetivo,'SQL:',sql,'']
    linhas += [SEPARADOR,'FIM DO ARQUIVO',SEPARADOR,'']
    return '\n'.join(linhas)


def instrucoes():
    membros = '\n'.join(f'- {nome} - NUSP {nusp}' for nome,nusp in MEMBROS)
    return f'''SCC0640 - INSTALACAO E EXECUCAO
Grupo: Semana da Computação

INTEGRANTES
{membros}

REQUISITOS
- PostgreSQL (validado no PostgreSQL 18.6).
- Python 3.11 ou superior com pip (integração validada com Python 3.12).
- Ollama executado LOCALMENTE. Modelo: {MODELO}.
- Conectividade para instalar dependências e baixar o modelo; depois, inferência local.
- Não é necessário clonar o GitHub, instalar Docker ou acessar a pasta sql/.

1. EXTRAIR OS ARQUIVOS
Extraia o compactado principal. Entre na pasta ProjetoBD criada por ele.
Extraia Prototipo.zip NESTA pasta. No PowerShell, pode usar:
  Expand-Archive -LiteralPath Prototipo.zip -DestinationPath .
O resultado obrigatório é:
  ProjetoBD/Projeto.txt
  ProjetoBD/Prototipo/main.py
  ProjetoBD/Prototipo/config.json
  ProjetoBD/Prototipo/requirements.txt
Evite pastas Prototipo/Prototipo/. Projeto.txt fica imediatamente acima de main.py.

2. CRIAR UMA BASE VAZIA
Execute no terminal, a partir de ProjetoBD (substitua o usuário, se necessário):
  createdb -h localhost -U postgres eventos
Se psql/createdb não estiverem no PATH, use a pasta bin da instalação PostgreSQL.
A senha é solicitada pelo terminal. Não é necessário usar a senha dos integrantes.

3. EXTRAIR E EXECUTAR O DDL
O DDL COMPLETO está na seção 3 de Projeto.txt e inclui tabelas, índices, funções
e triggers, na ordem de execução. Pode copiá-lo para o Query Tool do pgAdmin,
sem as linhas decorativas de sinais de igual, conectado à base vazia eventos.
Alternativamente, gere um arquivo local de execução com este comando Python:
  python -c "from pathlib import Path; t=Path('Projeto.txt').read_text(encoding='utf-8'); d=t.split('3. DDL COMPLETO',1)[1].split('4. CONSULTAS',1)[0]; Path('DDL_extraido.sql').write_text('\\n'.join(l for l in d.splitlines() if set(l.strip()) != {{'='}}),encoding='utf-8')"
Depois execute:
  psql -X -h localhost -U postgres -d eventos -v ON_ERROR_STOP=1 -f DDL_extraido.sql
DDL_extraido.sql é derivado local, não uma segunda fonte. Não reaplique o DDL
sobre tabelas existentes. Para repetir o ensaio, use outra base vazia.

4. POPULAR A BASE
  psql -X -h localhost -U postgres -d eventos -v ON_ERROR_STOP=1 -f DML.sql
A carga usa IDs gerados a partir de 1; deve ser executada UMA vez em base nova,
antes de inserir dados de teste manualmente. Não executar testes que consumam
sequências antes desta carga. Não desabilitar triggers.

5. PREPARAR O OLLAMA LOCAL
Instale Ollama a partir de https://ollama.com/download.
Inicie o aplicativo/serviço local e baixe o modelo:
  ollama pull {MODELO}
Confira com:
  ollama list
O host padrão é http://localhost:11434. Não executar outra instância na mesma
porta caso o aplicativo já esteja ativo. O download do modelo é de vários GB;
reserve memória/espaço e faça-o antes do teste. Nenhum serviço de IA em nuvem
ou chave de API paga é necessário.

6. INSTALAR AS BIBLIOTECAS PYTHON
Entre na pasta Prototipo. Em um ambiente Python 3.11+, execute:
  python -m pip install -r requirements.txt
As dependências são ollama e psycopg[binary], nas versões registradas no arquivo.
Recomenda-se venv local; não há ambiente virtual embutido na entrega.

7. EDITAR SOMENTE config.json
O arquivo distribuído contém uma senha FICTÍCIA, ALTERE_AQUI.
Configure database.host, port, dbname, user e password para sua base.
Configure ollama.host e model; o modelo utilizado é {MODELO}.
Não é necessário modificar main.py nem Projeto.txt para informar a conexão.
O programa também oferece parâmetros de conexão em tempo de execução no menu.

8. EXECUTAR
Dentro de Prototipo:
  python main.py
Menu 1: escolher uma das cinco consultas lidas de Projeto.txt.
Menu 2: pergunta em português, geração local de SQL, execução e resultado/erro.
Menu 3: informar parâmetros de conexão. Menu 0: sair.
Consultas geradas são executadas em transação somente leitura com tempo máximo.
Após erro SQL o programa reverte a transação e permite nova consulta.
O programa resolve os arquivos relativamente ao próprio main.py, não ao diretório
de trabalho. Projeto.txt continua sendo necessário no diretório pai.

9. VERIFICACAO RAPIDA DA CARGA
As cinco consultas devem retornar, respectivamente, 19, 19, 11, 12 e 10 linhas.
As sessões 8, 9 e 18 ficam lotadas; há pessoas em espera. A sessão 13 possui
duas alterações no histórico e a 11 possui uma. Inscrições gerais e específicas
são independentes: há pessoas inscritas em sessão sem inscrição na edição.

LIMITACOES E CONVENCOES
- Horários são locais e cada sessão usa uma data; não há sessão atravessando meia-noite.
- vagas_limite NULL indica ausência de limite próprio; a capacidade física continua valendo.
- Operações sobre inscrições/sessões/espaços são serializadas na transação para
  consistência. Usar o isolamento padrão READ COMMITTED; esse mecanismo privilegia
  correção no volume acadêmico, não alto paralelismo de escritas.
- Todo evento precisa de edição, e toda edição de promotor, validados no COMMIT.
  Ao cadastrar novos conjuntos, inserir pai e filhos na mesma transação.
- Recursos são cadastrados/disponibilizados/exigidos; a compatibilidade entre
  todos os recursos e a agenda é consultável, mas não validada automaticamente.
- Não há bloqueio automático de inscrição por status CANCELADA da sessão, nem
  validação entre a data da sessão e o período da edição; não foram acrescentadas
  regras de negócio não confirmadas. A carga fornecida respeita os períodos.
- SQL gerado pelo LLM pode estar errado; o programa apresenta erros e faz no
  máximo uma tentativa de correção. Nem toda pergunta tem interpretação única.
- A defesa de leitura não é um sandbox geral para funções SQL arbitrárias;
  recomenda-se usuário de consulta com privilégios mínimos no ambiente do avaliador.
- O menu exibe até 50 linhas e pode abreviar células longas; as cinco consultas
  fornecidas têm menos de 50 linhas. O banco mantém os dados completos.
'''


def zip_escrever(z, nome, dados):
    info = zipfile.ZipInfo(nome, date_time=(2026,11,3,0,0,0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    z.writestr(info, dados)


def gerar(zip_final=None):
    DEST.mkdir(exist_ok=True)
    conteudo = projeto().encode('utf-8')
    (DEST/'Projeto.txt').write_bytes(conteudo)
    # Copia local ignorada: permite testar a pasta-fonte do prototipo.
    (ROOT/'Projeto.txt').write_bytes(conteudo)
    (DEST/'DML.sql').write_bytes((ROOT/'sql/03_dml.sql').read_bytes())
    (DEST/'Instrucoes.txt').write_text(instrucoes(),encoding='utf-8',newline='\n')
    for origem,destino in [('ER.pdf','ER.pdf'),('ER.drawio','ER.xml'),
                           ('Relacional.pdf','Relacional.pdf'),('Relacional.mmd','Relacional.mmd')]:
        shutil.copyfile(ROOT/'docs/modelagem'/origem, DEST/destino)
    with zipfile.ZipFile(DEST/'Prototipo.zip','w') as z:
        for nome in ['main.py','requirements.txt']:
            zip_escrever(z,'Prototipo/'+nome,(ROOT/'prototipo'/nome).read_bytes())
        zip_escrever(z,'Prototipo/config.json',
                     (json.dumps(CONFIG_EXEMPLO,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    if zip_final:
        zip_final = Path(zip_final).resolve()
        zip_final.parent.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(zip_final,'w') as z:
            for nome in ARQUIVOS:
                zip_escrever(z,'ProjetoBD/'+nome,(DEST/nome).read_bytes())
    print('Artefatos gerados:',', '.join(ARQUIVOS))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--zip-final',type=Path)
    args=parser.parse_args()
    gerar(args.zip_final)
