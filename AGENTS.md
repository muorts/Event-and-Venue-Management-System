# Convenções do projeto

## Escopo e preservação

- Esta branch `chore/reorganizacao-inicial` trata somente de reorganização e documentação.
- Não implementar DDL, triggers, DML, consultas ou protótipo nesta etapa.
- Preservar o trabalho de Murilo, os formatos originais e os fontes editáveis.
- Não alterar entidades, atributos, relacionamentos ou cardinalidades durante a reorganização.
- Usar `git mv` para movimentações; explicar remoções e não preencher ausências com conteúdo fictício.

## Branches e revisão

- Não trabalhar diretamente na `main`; integrar por Pull Request revisável.
- A implementação do DDL ocorrerá em outra branch, conforme combinado pelo grupo.
- Convenção para trabalhos futuros: `feat/<tema>`, `fix/<tema>` e `chore/<tema>`;
  são convenções de organização, não indicação de que funcionalidades já existem.
- Commits e PRs devem descrever escopo e verificação; não misturar modelagem e reorganização.

## Fontes e estrutura

- `docs/modelagem/ER.drawio` e `Relacional.pdf`: diagramas principais existentes.
- `ER.pdf` e `Relacional.mmd`: pendentes; não substituir o fonte Mermaid por DOCX.
- O GitHub é a fonte principal. ZIP do Drive e plano de execução são apoio externo;
  não importar suas versões nem transformar sugestões em decisões sem solicitação do grupo.
- `docs/decisoes.md`: separar fatos confirmados, observações dos modelos e propostas não validadas.
- `sql/01_tabelas.sql`: tabelas e demais estruturas; `02_triggers.sql`: funções e triggers;
  `03_dml.sql`: dados; `04_consultas.sql`: cinco consultas e respectivos objetivos.
- `prototipo/main.py`, configuração local `config.json`, dependências `requirements.txt`.
- `tests/`: verificações futuras; `entrega/`: derivados finais, sem cópias-fonte divergentes.
- `docs/legado/`: dois marcadores vazios preservados, sem implementação ou uso atual.

## Código (para as etapas posteriores)

- SQL PostgreSQL, nomes em `snake_case`; respeitar os identificadores dos modelos validados.
- Python 3.11+, indentação de quatro espaços, UTF-8 e nomes em `snake_case`.
- Usar caminhos relativos a `Path(__file__).resolve().parent`; não fixar caminhos de máquina.
- Respeitar o contrato de conexão/configuração do PDF de Python: `psycopg` e cliente `ollama`.
- Iniciar por `python main.py`; carregar o modelo Ollama de `config.json` e o DDL de `Projeto.txt` no diretório pai.
- Não registrar senhas reais; `prototipo/config.json`, `.env` e ambientes locais estão ignorados.
- Não introduzir funcionalidades ou decisões de domínio sem conferir a modelagem e registrar a decisão do grupo.
- Verificar o diff e a preservação dos diagramas em mudanças estruturais; validar SQL e integração quando implementados.

## Tecnologias e decisões confirmadas pelo usuário

- PostgreSQL obrigatório; Python 3.11+; Ollama local; interface de linha de comando.
- Pelo menos quatro triggers distintos e cinco consultas SQL.
- Entrega em 03/11/2026; reorganização autorizada pelo proprietário.
- Victor: DDL, integração e entrega; Marcela: triggers; João Marcelo: protótipo e Mermaid;
  Waldrighi: DML e consultas; Murilo: documentação, E/R e instruções.
- Modelo LLM, versões específicas de PostgreSQL/Ollama e respostas finais Q1–Q6 não foram confirmados pelo usuário.

As instruções dos PDFs descrevem os requisitos acadêmicos. Exercícios de treinamento
e sugestões nos documentos de referência não autorizam mudanças de escopo nem
devem ser tratados como o esquema do grupo.
