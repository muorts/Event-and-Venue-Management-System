# Event-and-Venue-Management-System

Projeto de Bases de Dados SCC0640 (USP), sistema de gestão de eventos e espaços.
Entrega informada pelo grupo: **03/11/2026**.

## Integrantes e responsabilidades

| Integrante | Responsabilidade |
| --- | --- |
| Victor | DDL, integração e entrega final |
| Marcela | Triggers |
| João Marcelo | Protótipo Python/Ollama e modelo relacional em Mermaid |
| Waldrighi | DML e consultas SQL |
| Murilo | Documentação, diagramas E/R e instruções |

## Fonte principal

O repositório GitHub é a fonte principal do projeto. O ZIP do Drive e o plano de
execução são materiais de apoio: não substituem os arquivos ou as decisões
versionadas e não foram incorporados a esta reorganização.

## Estado desta etapa

Reorganização inicial na branch `chore/reorganizacao-inicial`, sem implementação.
O E/R editável e o relacional em PDF foram preservados. `sql/01_tabelas.sql`,
`prototipo/main.py` e `entrega/Instrucoes.txt` são marcadores vazios preexistentes,
renomeados quando necessário: não há banco ou aplicação executável.

## Organização

```text
docs/modelagem/    E/R principal e modelo relacional existente
docs/decisoes.md   decisões confirmadas e questões ainda pendentes
docs/legado/       marcadores vazios antigos de preparação da entrega
sql/              scripts-fonte canônicos, na ordem 01 a 04
prototipo/        fontes do protótipo de linha de comando
tests/            reservado para verificações futuras
entrega/          somente artefatos finais derivados das fontes
```

Estrutura-alvo dos scripts: `sql/01_tabelas.sql`, `sql/02_triggers.sql`,
`sql/03_dml.sql`, `sql/04_consultas.sql`. Apenas o primeiro existe, sem SQL.
Não manter scripts paralelos por entidade.

## Tecnologias e requisitos obrigatórios

PostgreSQL, Python **3.11 ou superior** e Ollama **local**. A implementação futura
deverá conter pelo menos quatro triggers de finalidades distintas, cinco consultas
SQL relevantes e protótipo de linha de comando. As instruções de Python exigem
`ollama` e `psycopg[binary]` em `requirements.txt`, execução por `python main.py`,
configuração relativa ao arquivo e `Projeto.txt` no diretório pai do protótipo.
O modelo deve vir da configuração; o grupo ainda precisa confirmar o modelo utilizado.

## Pendências (arquivos ausentes não foram fabricados)

- `docs/modelagem/ER.pdf` e exportação XML de entrega do draw.io.
- `docs/modelagem/Relacional.mmd`: recuperar o fonte Mermaid com João Marcelo.
- Implementar `sql/01_tabelas.sql` e criar os scripts `02_triggers.sql`, `03_dml.sql` e `04_consultas.sql`.
- Implementar `prototipo/main.py`; criar `prototipo/requirements.txt` e configuração local `prototipo/config.json`.
- Confirmar e registrar as respostas Q1–Q6; o arquivo de decisões original estava vazio.
- Completar instruções e gerar os artefatos finais de `entrega/` após a implementação.

## Preparação da entrega futura

O enunciado pede ER.pdf + XML draw.io, Relacional.pdf + fonte Mermaid,
Projeto.txt fiel ao template, DML.sql, Prototipo.zip e Instrucoes.txt, reunidos
em um único arquivo compactado. Não gerar esses produtos nesta etapa.
Projeto.txt deverá reunir o DDL de `01_tabelas.sql` e `02_triggers.sql`, além das
consultas de `04_consultas.sql`; DML.sql deverá derivar de `03_dml.sql`.
Os arquivos em `entrega/` não devem ser editados como uma segunda fonte.

O pacote deverá acomodar `Projeto.txt` imediatamente acima de `Prototipo/`,
conforme o PDF de Python; o diretório-fonte solicitado pelo grupo é `prototipo/`.
O enunciado alterna `Instrucoes.txt` e `06.Instrucoes.txt` e não completa o nome
do arquivo compactado final: confirmar essas ambiguidades antes de empacotar.

`prototipo/config.json` está ignorado no Git para impedir registro de senhas reais.
A configuração distribuível, ainda pendente, deverá usar valores fictícios e
ser incluída no pacote final respeitando o formato exigido.

Veja [AGENTS.md](AGENTS.md) e [decisões e observações](docs/decisoes.md).
