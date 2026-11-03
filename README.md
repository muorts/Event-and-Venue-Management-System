# Event-and-Venue-Management-System

Sistema de Gestão de Eventos e Espaços — Semana da Computação.
Projeto SCC0640, USP. Entrega: **03/11/2026**.

## Integrantes

| Integrante | Responsabilidade |
| --- | --- |
| Victor Kayky Zaneti Antunes | DDL, integração e entrega |
| Marcela Caprioli Alves | Funções e triggers |
| João Marcelo Abreu dos Santos | Protótipo Python/Ollama e relacional Mermaid |
| Lucas Waldrighi Lima | DML e cinco consultas SQL |
| Murilo Ortega Pereira | Documentação, E/R e instruções |

## Fontes e execução

GitHub é a fonte principal. As seis decisões estão aprovadas em
[docs/decisoes.md](docs/decisoes.md). O contrato das 16 tabelas, 16 PKs e 19 FKs
está em [docs/ddl.md](docs/ddl.md).

```text
sql/01_tabelas.sql       tabelas, restrições e índices
sql/02_triggers.sql      funções e triggers
sql/03_dml.sql           carga sintética de Lucas
sql/04_consultas.sql     cinco consultas e objetivos de Lucas
prototipo/              CLI Python, requirements e configuração LOCAL ignorada
docs/modelagem/         E/R e Mermaid com fontes e PDFs
scripts/                geração reproduzível da entrega
tests/                  baseline do DDL, triggers e teste do pacote
entrega/                oito artefatos finais derivados
```

Tecnologias: PostgreSQL, Python 3.11+ e Ollama local. Modelo de integração:
`qwen3:8b`. Não versionar senhas reais nem ambientes virtuais.

## Preparar a entrega

```sh
python scripts/preparar_entrega.py --zip-final SCC0640_Semana_da_Computacao_2026.zip
```

O script lê exclusivamente as fontes e gera Projeto.txt completo, DML.sql,
Prototipo.zip com configuração fictícia, PDFs/fontes e Instrucoes.txt.
Não editar essas cópias manualmente: corrigir a fonte e gerar novamente.

No pacote, extrair Prototipo.zip dentro de ProjetoBD, mantendo Projeto.txt no
diretório pai de Prototipo/main.py. O programa lê tanto o DDL quanto as cinco
consultas desse Projeto.txt; não depende da pasta sql/ na entrega.
Seguir [entrega/Instrucoes.txt](entrega/Instrucoes.txt) para instalação e execução.

## Validação e limites

O baseline do DDL passou em 125 verificações no PostgreSQL 18.6 nativo.
O ensaio final usa uma base vazia e o pacote extraído, incluindo testes concorrentes
e, com --testar-ollama, inferência local real.

Detalhes e correções: [docs/integracao-final.md](docs/integracao-final.md).
Resultados: [docs/validacao_entrega.json](docs/validacao_entrega.json).
As limitações restantes estão nas instruções, sem declarar como concluído o que
não foi validado. O material de apoio do Drive não substitui as fontes do GitHub.
