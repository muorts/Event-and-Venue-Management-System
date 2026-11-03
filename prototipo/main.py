"""
SCC0640 - Bases de Dados - Prototipo em linha de comando
Sistema de Gestao de Eventos e Espacos

Execucao:  python main.py
Configuracao: editar apenas config.json (conexao PostgreSQL e modelo Ollama).

Fluxo:
  1. Le config.json (mesma pasta deste arquivo).
  2. Le Projeto.txt (pasta imediatamente acima) e extrai:
       - o DDL  (entre "3. DDL COMPLETO" e "4. CONSULTAS")  -> contexto do esquema para o LLM
       - as 5 consultas (secao "4. CONSULTAS")             -> menu de consultas predefinidas
  3. Conecta ao PostgreSQL (psycopg) e ao Ollama (ollama.Client).
  4. Menu: consultas predefinidas, pergunta em linguagem natural, configurar conexao.
"""

import json
import re
import sys
from pathlib import Path

import ollama
import psycopg

# ------------------------------------------------------------------
# Caminhos (sempre relativos a este arquivo; nada de caminho absoluto)
# ------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
# Estrutura exigida: ProjetoBD/Projeto.txt e ProjetoBD/Prototipo/main.py.
PROJETO_PATH = BASE_DIR.parent / "Projeto.txt"
NUM_CONSULTAS = 5

MAX_LINHAS_EXIBIDAS = 50   # linhas mostradas por resultado
MAX_LARGURA_COLUNA = 40    # caracteres por celula antes de truncar
TIMEOUT_CONSULTA = "30s"   # statement_timeout de cada consulta
NUM_CTX = 6144             # janela de contexto do Ollama (maior = mais RAM; prompt ~3.4k tokens)
KEEP_ALIVE = "2m"          # tempo que o modelo fica carregado na memoria apos usar


# ==================================================================
# 1. Leitura de arquivos
# ==================================================================
def carregar_config():
    """Le config.json. Encerra com mensagem clara se faltar algo."""
    try:
        with open(CONFIG_PATH, encoding="utf-8") as f:
            cfg = json.load(f)
    except FileNotFoundError:
        sys.exit(f"[ERRO] config.json nao encontrado em {CONFIG_PATH}")
    except json.JSONDecodeError as e:
        sys.exit(f"[ERRO] config.json invalido: {e}")

    for chave in ("database", "ollama"):
        if chave not in cfg:
            sys.exit(f"[ERRO] config.json sem a secao '{chave}'")
    return cfg


def ler_projeto():
    """Retorna o texto do Projeto.txt (ou None se nao existir)."""
    if not PROJETO_PATH.is_file():
        return None
    return PROJETO_PATH.read_text(encoding="utf-8")


def extrair_secao(texto, inicio, fim=None):
    """
    Devolve o trecho entre o titulo 'inicio' e o titulo 'fim'
    (ou ate o fim do documento, se 'fim' nao existir).
    Remove apenas as linhas formadas so por '=' que emolduram os titulos do template.
    """
    pos = texto.find(inicio)
    if pos == -1:
        return ""
    trecho = texto[pos + len(inicio):]
    if fim:
        pos_fim = trecho.find(fim)
        if pos_fim != -1:
            trecho = trecho[:pos_fim]
    linhas = [l for l in trecho.splitlines() if not re.fullmatch(r"\s*=+\s*", l)]
    return "\n".join(linhas).strip()


def dividir_comandos(sql):
    """
    Divide SQL em comandos pelo ';' respeitando strings '...', identificadores "...",
    comentarios (-- e /* */) e corpos $$...$$ / $tag$...$tag$ de funcoes.
    Comentarios sao descartados. (split(';') simples quebraria esses casos.)
    """
    comandos, atual = [], []
    i, n = 0, len(sql)
    while i < n:
        c = sql[i]
        if c == "-" and sql.startswith("--", i):          # comentario de linha
            fim = sql.find("\n", i)
            i = n if fim == -1 else fim
            continue
        if c == "/" and sql.startswith("/*", i):          # comentario de bloco
            fim = sql.find("*/", i + 2)
            i = n if fim == -1 else fim + 2
            atual.append(" ")
            continue
        if c in ("'", '"'):                                # string ou identificador
            j = i + 1
            while j < n:
                if sql[j] == c:
                    if j + 1 < n and sql[j + 1] == c:      # aspas escapadas ''
                        j += 2
                        continue
                    break
                j += 1
            atual.append(sql[i:j + 1])
            i = j + 1
            continue
        if c == "$":                                       # dollar quoting
            m = re.match(r"\$([A-Za-z_]\w*)?\$", sql[i:])
            if m:
                tag = m.group(0)
                fim = sql.find(tag, i + len(tag))
                fim = n if fim == -1 else fim + len(tag)
                atual.append(sql[i:fim])
                i = fim
                continue
        if c == ";":
            comandos.append("".join(atual).strip())
            atual = []
            i += 1
            continue
        atual.append(c)
        i += 1
    resto = "".join(atual).strip()
    if resto:
        comandos.append(resto)
    return [cmd for cmd in comandos if cmd]


def extrair_ddl(texto):
    return extrair_secao(texto, "3. DDL COMPLETO", "4. CONSULTAS")


def extrair_consultas(texto):
    """
    Le a secao '4. CONSULTAS' no formato do template:

        CONSULTA 1
        OBJETIVO: <uma frase>
        SQL: <consulta, podendo ocupar varias linhas>

    Retorna lista de dicts: {"numero", "objetivo", "sql"}, ordenada pelo numero.
    """
    secao = extrair_secao(texto, "4. CONSULTAS", "FIM DO ARQUIVO")
    if not secao:
        return []

    # Divide nos cabecalhos "CONSULTA <n>" (inicio de linha)
    blocos = re.split(r"(?m)^\s*CONSULTA\s+(\d+)\s*$", secao)
    # re.split com grupo -> ['', '1', bloco1, '2', bloco2, ...]
    consultas = []
    for i in range(1, len(blocos) - 1, 2):
        numero = int(blocos[i])
        corpo = blocos[i + 1]
        m_obj = re.search(r"OBJETIVO:\s*(.*?)\s*(?=^\s*SQL:)", corpo, re.DOTALL | re.MULTILINE)
        m_sql = re.search(r"^\s*SQL:\s*(.*)", corpo, re.DOTALL | re.MULTILINE)
        if not m_sql:
            continue
        objetivo = " ".join(m_obj.group(1).split()) if m_obj else "(sem objetivo)"
        sql = m_sql.group(1).strip()
        if sql and not sql.startswith("["):  # ignora placeholder "[consulta]" do template
            consultas.append({"numero": numero, "objetivo": objetivo, "sql": sql})
    return sorted(consultas, key=lambda c: c["numero"])


def validar_consultas(consultas):
    """Devolve lista de avisos se nao houver exatamente as consultas 1..5, sem repeticao."""
    avisos = []
    numeros = [c["numero"] for c in consultas]
    repetidos = sorted({n for n in numeros if numeros.count(n) > 1})
    faltando = [n for n in range(1, NUM_CONSULTAS + 1) if n not in numeros]
    extras = sorted({n for n in numeros if not 1 <= n <= NUM_CONSULTAS})
    if repetidos:
        avisos.append(f"consulta(s) repetida(s): {repetidos}")
    if faltando:
        avisos.append(f"consulta(s) ausente(s) ou sem SQL: {faltando}")
    if extras:
        avisos.append(f"numeracao fora de 1-{NUM_CONSULTAS}: {extras}")
    return avisos


def resumir_esquema(ddl):
    """
    Para o prompt do LLM, mantem so o que descreve a estrutura
    (CREATE TABLE/TYPE/DOMAIN/VIEW, ALTER TABLE e COMMENT ON) e descarta
    funcoes, triggers, indices e BEGIN/COMMIT, que gastam contexto e nao ajudam a gerar SELECT.
    """
    if not ddl:
        return ""
    uteis = [
        compactar_create_table(c) + ";" for c in dividir_comandos(ddl)
        if re.match(r"(?i)(CREATE\s+(TABLE|TYPE|DOMAIN|(OR\s+REPLACE\s+)?VIEW)|ALTER\s+TABLE|COMMENT\s+ON)", c)
    ]
    return "\n\n".join(uteis) if uteis else ddl


def compactar_create_table(comando):
    """
    Enxuga um CREATE TABLE para o prompt (menos tokens = menos RAM no Ollama):
    remove CHECKs de texto nao vazio/datas finitas e clausulas ON DELETE/ON UPDATE,
    que nao ajudam a escrever SELECT. Mantem colunas, tipos, PK, FK, UNIQUE e
    CHECKs com valores permitidos (ex.: status IN (...)).
    """
    m = re.match(r"(?is)(CREATE\s+TABLE\s+\w+\s*)\((.*)\)\s*$", comando)
    if not m:
        return comando
    cabecalho, corpo = m.group(1).strip(), m.group(2)
    itens, atual, nivel, i = [], [], 0, 0
    while i < len(corpo):                       # separa itens pelas virgulas de nivel 0
        c = corpo[i]
        if c == "'":                            # nao contar parenteses/virgulas em strings
            j = corpo.find("'", i + 1)
            j = len(corpo) - 1 if j == -1 else j
            atual.append(corpo[i:j + 1])
            i = j + 1
            continue
        if c == "(":
            nivel += 1
        elif c == ")":
            nivel -= 1
        if c == "," and nivel == 0:
            itens.append("".join(atual))
            atual = []
        else:
            atual.append(c)
        i += 1
    itens.append("".join(atual))

    mantidos = []
    for item in itens:
        item = " ".join(item.split())
        if not item or re.match(r"(?i)CONSTRAINT\s+\w+\s+CHECK\s*\(\s*\(?\s*(btrim|isfinite)\b", item):
            continue
        item = re.sub(r"(?i)\s+ON\s+(DELETE|UPDATE)\s+(RESTRICT|CASCADE|SET\s+NULL|SET\s+DEFAULT|NO\s+ACTION)", "", item)
        mantidos.append("  " + item)
    return f"{cabecalho} (\n" + ",\n".join(mantidos) + "\n)"


# ==================================================================
# 2. Banco de dados
# ==================================================================
def conectar_banco(db_cfg):
    """Abre a conexao conforme config.json. Retorna conexao ou None."""
    try:
        conn = psycopg.connect(
            host=db_cfg.get("host", "localhost"),
            port=db_cfg.get("port", 5432),
            dbname=db_cfg["dbname"],
            user=db_cfg["user"],
            password=db_cfg.get("password", ""),
            connect_timeout=5,
        )
        print(f"[OK] Conectado ao PostgreSQL: {db_cfg['dbname']}@{db_cfg.get('host', 'localhost')}")
        return conn
    except KeyError as e:
        print(f"[ERRO] config.json: falta o campo database.{e.args[0]}")
    except psycopg.Error as e:
        print(f"[ERRO] Falha ao conectar ao PostgreSQL:\n  {e}")
    return None


def executar_select(conn, sql):
    """
    Executa a consulta em transacao SOMENTE LEITURA (protege o banco caso o
    LLM gere INSERT/UPDATE/DELETE/DROP) e desfaz tudo ao final.
    Retorna (colunas, linhas). Propaga psycopg.Error para quem chamou tratar.
    """
    try:
        with conn.cursor() as cur:
            cur.execute("SET TRANSACTION READ ONLY")
            cur.execute(f"SET LOCAL statement_timeout = '{TIMEOUT_CONSULTA}'")
            cur.execute(sql)
            if cur.description is None:
                return [], []
            colunas = [d.name for d in cur.description]
            linhas = cur.fetchall()
            return colunas, linhas
    finally:
        conn.rollback()


# ==================================================================
# 3. Apresentacao de resultados (sem bibliotecas extras)
# ==================================================================
def formatar_celula(valor):
    if valor is None:
        return "NULL"
    texto = str(valor).replace("\n", " ")
    if len(texto) > MAX_LARGURA_COLUNA:
        texto = texto[: MAX_LARGURA_COLUNA - 3] + "..."
    return texto


def imprimir_tabela(colunas, linhas):
    if not colunas:
        print("(comando executado, sem resultado tabular)")
        return
    if not linhas:
        print("(nenhuma linha retornada)")
        return

    exibidas = linhas[:MAX_LINHAS_EXIBIDAS]
    celulas = [[formatar_celula(v) for v in linha] for linha in exibidas]
    larguras = [
        max(len(str(col)), *(len(l[i]) for l in celulas))
        for i, col in enumerate(colunas)
    ]

    def linha_fmt(valores):
        return " | ".join(v.ljust(larguras[i]) for i, v in enumerate(valores))

    separador = "-+-".join("-" * w for w in larguras)
    print(linha_fmt([str(c) for c in colunas]))
    print(separador)
    for l in celulas:
        print(linha_fmt(l))

    total = len(linhas)
    if total > MAX_LINHAS_EXIBIDAS:
        print(f"... ({total} linhas no total; exibindo as {MAX_LINHAS_EXIBIDAS} primeiras)")
    else:
        print(f"({total} linha{'s' if total != 1 else ''})")


# ==================================================================
# 4. Ollama: linguagem natural -> SQL
# ==================================================================
def criar_cliente_ollama(ol_cfg):
    return ollama.Client(host=ol_cfg.get("host", "http://localhost:11434"))


def montar_prompt_sistema(esquema):
    return (
        "Voce converte perguntas em portugues para UMA consulta SQL do PostgreSQL.\n"
        "Regras:\n"
        "- Use SOMENTE as tabelas e colunas do esquema abaixo; nao invente nomes.\n"
        "- Gere apenas SELECT (ou WITH ... SELECT). Nunca altere dados.\n"
        "- Responda SOMENTE com o SQL, sem explicacoes e sem markdown.\n"
        "- Para termos citados pelo usuario (nomes, titulos, tipos), use ILIKE '%termo%',\n"
        "  nunca '=' com texto exato, e escolha a coluna que realmente guarda esse dado.\n"
        "  Na duvida entre colunas de texto (ex.: tipo e titulo), combine-as com OR.\n\n"
        "SIGNIFICADO DAS TABELAS PRINCIPAIS:\n"
        "- evento: iniciativa recorrente (ex.: 'Semana da Computacao'); edicao: realizacao\n"
        "  de um evento em um ano.\n"
        "- atividade: item da programacao de uma edicao; atividade.tipo e o formato\n"
        "  (palestra, workshop, minicurso, painel...) e atividade.titulo e o nome.\n"
        "- sessao: realizacao concreta de uma atividade (data, horario, espaco).\n"
        "- espaco: sala/auditorio/laboratorio; recurso: equipamento (projetor etc.).\n"
        "- pessoa: cadastro unico; seus papeis estao em inscricao_edicao, inscricao_sessao,\n"
        "  equipe_edicao (organizador/voluntario) e atividade_pessoa (palestrante/instrutor/mediador).\n"
        "- Status ficam em MAIUSCULAS (ex.: 'CONFIRMADA'); papeis em minusculas.\n"
        "- So filtre por status (de sessao, edicao ou inscricao) se a pergunta pedir.\n\n"
        "REGRAS DE VAGAS E OCUPACAO:\n"
        "- Vagas efetivas de uma sessao = LEAST(COALESCE(sessao.vagas_limite, espaco.capacidade),\n"
        "  espaco.capacidade); vagas_limite NULL significa sem limite proprio.\n"
        "- Ocupacao = numero de inscricao_sessao com status 'CONFIRMADA' na sessao\n"
        "  (LISTA_ESPERA e CANCELADA nao ocupam vaga).\n"
        "- Sessao lotada: ocupacao >= vagas efetivas (use GROUP BY ... HAVING).\n"
        "- Lista de espera: inscricao_sessao com status 'LISTA_ESPERA', ordenada por posicao_espera.\n\n"
        "ESQUEMA DO BANCO:\n"
        f"{esquema}"
    )


def limpar_sql_gerado(resposta):
    """Remove raciocinio <think>, cercas ``` e texto antes do SQL; devolve so o SQL."""
    texto = re.sub(r"<think>.*?</think>", "", resposta, flags=re.DOTALL).strip()
    m = re.search(r"```(?:sql)?\s*(.*?)```", texto, re.DOTALL | re.IGNORECASE)
    if m:
        texto = m.group(1).strip()
    # comeca no primeiro SELECT/WITH
    m = re.search(r"(?is)\b(WITH|SELECT)\b.*", texto)
    if m:
        texto = m.group(0)
    return texto.strip()


def validar_sql_gerado(sql):
    """
    Aceita um unico comando de leitura. Devolve (sql_normalizado, None) ou (None, motivo).
    Defesa pratica, nao sandbox: a protecao principal e a transacao READ ONLY no banco.
    """
    comandos = dividir_comandos(sql)
    if not comandos:
        return None, "resposta sem comando SQL"
    if len(comandos) > 1:
        return None, f"o modelo gerou {len(comandos)} comandos; so um e permitido"
    comando = comandos[0]
    if not re.match(r"(?i)(SELECT|WITH)\b", comando):
        return None, "apenas consultas de leitura (SELECT/WITH) sao permitidas"
    return comando, None


def perguntar_ao_modelo(cliente, modelo, mensagens):
    """Chama o Ollama. Tenta desligar o modo 'thinking' (qwen3); cai fora se a versao nao suportar."""
    opcoes = {"temperature": 0, "num_ctx": NUM_CTX}
    try:
        resp = cliente.chat(model=modelo, messages=mensagens, options=opcoes,
                            think=False, keep_alive=KEEP_ALIVE)
    except TypeError:
        resp = cliente.chat(model=modelo, messages=mensagens, options=opcoes)
    return resp["message"]["content"]


def gerar_sql(cliente, modelo, esquema, pergunta, erro_anterior=None, sql_anterior=None):
    mensagens = [
        {"role": "system", "content": montar_prompt_sistema(esquema)},
        {"role": "user", "content": pergunta},
    ]
    if erro_anterior:
        mensagens += [
            {"role": "assistant", "content": sql_anterior},
            {"role": "user", "content": (
                f"Essa consulta falhou no PostgreSQL com o erro:\n{erro_anterior}\n"
                "Corrija e responda somente com o SQL."
            )},
        ]
    return limpar_sql_gerado(perguntar_ao_modelo(cliente, modelo, mensagens))


# ==================================================================
# 5. Telas do menu
# ==================================================================
def tela_consultas(conn, consultas):
    if not consultas:
        print("\n[AVISO] Nenhuma consulta encontrada na secao '4. CONSULTAS' do Projeto.txt.")
        return

    print("\n--- CONSULTAS PREDEFINIDAS ---")
    for c in consultas:
        print(f"  {c['numero']}. {c['objetivo']}")
    escolha = input("Numero da consulta (Enter para voltar): ").strip()
    if not escolha:
        return

    consulta = next((c for c in consultas if str(c["numero"]) == escolha), None)
    if consulta is None:
        print("[ERRO] Opcao invalida.")
        return

    print(f"\nCONSULTA {consulta['numero']}: {consulta['objetivo']}")
    print(f"SQL:\n{consulta['sql']}\n")
    try:
        colunas, linhas = executar_select(conn, consulta["sql"])
        imprimir_tabela(colunas, linhas)
    except psycopg.Error as e:
        print(f"[ERRO] A consulta falhou:\n  {e}")


def tela_linguagem_natural(conn, cfg, esquema):
    if not esquema:
        print("\n[AVISO] DDL nao encontrado no Projeto.txt; o modelo ficara sem o esquema.")

    pergunta = input("\nSua pergunta (Enter para voltar): ").strip()
    if not pergunta:
        return

    modelo = cfg["ollama"].get("model", "qwen3:8b")
    cliente = criar_cliente_ollama(cfg["ollama"])

    print(f"Gerando SQL com {modelo}... (pode levar alguns segundos)")
    try:
        sql = gerar_sql(cliente, modelo, esquema, pergunta)
    except Exception as e:  # conexao recusada, modelo nao baixado etc.
        print(f"[ERRO] Falha ao consultar o Ollama: {e}")
        print("  Verifique se o Ollama esta rodando e se o modelo foi baixado (ollama pull <modelo>).")
        return

    if not sql:
        print("[ERRO] O modelo nao devolveu uma consulta SQL.")
        return

    # Uma tentativa de correcao automatica se o SQL falhar
    for tentativa in (1, 2):
        rotulo = "SQL gerado" if tentativa == 1 else "SQL corrigido"
        print(f"\n{rotulo}:\n{sql}\n")
        sql_ok, motivo = validar_sql_gerado(sql)
        if motivo:
            print(f"[ERRO] Consulta recusada: {motivo}.")
            return
        try:
            colunas, linhas = executar_select(conn, sql_ok)
            imprimir_tabela(colunas, linhas)
            return
        except psycopg.Error as e:
            erro = str(e).strip()
            print(f"[ERRO] A consulta gerada esta incorreta:\n  {erro}")
            if tentativa == 2:
                return
            print("Pedindo ao modelo uma correcao...")
            try:
                sql = gerar_sql(cliente, modelo, esquema, pergunta, erro, sql)
            except Exception as e2:
                print(f"[ERRO] Falha ao consultar o Ollama: {e2}")
                return
            if not sql:
                print("[ERRO] O modelo nao devolveu uma correcao.")
                return


def tela_configurar_conexao(cfg):
    """Permite informar os parametros de conexao em tempo de execucao (Enter mantem o valor atual)."""
    db = cfg["database"]
    print("\n--- PARAMETROS DE CONEXAO (Enter mantem o valor atual) ---")
    for campo in ("host", "port", "dbname", "user", "password"):
        atual = db.get(campo, "")
        exibido = "****" if campo == "password" and atual else atual
        novo = input(f"  {campo} [{exibido}]: ").strip()
        if novo:
            db[campo] = int(novo) if campo == "port" and novo.isdigit() else novo
    return conectar_banco(db)


# ==================================================================
# 6. Programa principal
# ==================================================================
def main():
    print("=" * 60)
    print("SCC0640 - Gestao de Eventos e Espacos - Prototipo")
    print("=" * 60)

    cfg = carregar_config()

    texto = ler_projeto()
    if texto is None:
        print(f"[ERRO] Projeto.txt nao encontrado em {PROJETO_PATH}")
        print("  Ele deve ficar na pasta acima de Prototipo/ (ProjetoBD/Projeto.txt).")
        raise SystemExit(1)
    else:
        ddl = extrair_ddl(texto)
        consultas = extrair_consultas(texto)
        print(f"[OK] Projeto.txt lido: DDL com {len(ddl.splitlines())} linhas, "
              f"{len(consultas)} consulta(s) encontrada(s).")
        if not ddl:
            print("[AVISO] Secao '3. DDL COMPLETO' ausente ou vazia; o modelo ficara sem o esquema.")
        for aviso in validar_consultas(consultas):
            print(f"[AVISO] Secao '4. CONSULTAS': {aviso}.")
    esquema = resumir_esquema(ddl)

    conn = conectar_banco(cfg["database"])

    while True:
        print("\n" + "-" * 60)
        status = "conectado" if conn and not conn.closed else "DESCONECTADO"
        print(f"MENU  (banco: {status} | modelo: {cfg['ollama'].get('model', '?')})")
        print("  1. Executar consulta predefinida")
        print("  2. Fazer pergunta em linguagem natural")
        print("  3. Informar parametros de conexao")
        print("  0. Sair")
        opcao = input("Opcao: ").strip()

        if opcao == "0":
            break
        if opcao == "3":
            if conn and not conn.closed:
                conn.close()
            conn = tela_configurar_conexao(cfg)
            continue
        if opcao in ("1", "2"):
            if conn is None or conn.closed:
                print("[ERRO] Sem conexao com o banco. Use a opcao 3 para informar os parametros.")
                continue
            if opcao == "1":
                tela_consultas(conn, consultas)
            else:
                tela_linguagem_natural(conn, cfg, esquema)
            continue
        print("[ERRO] Opcao invalida.")

    if conn and not conn.closed:
        conn.close()
    print("Ate logo!")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        print("\nEncerrado pelo usuario.")
