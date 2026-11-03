# Convenções do projeto

## Escopo e preservação

- Reorganização e DDL aprovados. A etapa atual integra os PRs de Marcela/João,
  DML/consultas de Lucas, documentação de Murilo e os artefatos finais.
- Preservar autoria e fontes; fazer correções de integração necessárias com testes
  reproduzíveis, sem alterar silenciosamente entidades/atributos/cardinalidades.
- Preservar o trabalho de Murilo, os formatos originais e os fontes editáveis.
- Não alterar entidades, atributos, relacionamentos ou cardinalidades durante a reorganização.
- Usar `git mv` para movimentações; explicar remoções e não preencher ausências com conteúdo fictício.

## Branches e revisão

- Não trabalhar diretamente na `main`; integrar por Pull Request revisável.
- O DDL está integrado pelo PR #3. Alterações futuras devem usar branch própria e revisão de impacto.
- Convenção para trabalhos futuros: `feat/<tema>`, `fix/<tema>` e `chore/<tema>`;
  são convenções de organização, não indicação de que funcionalidades já existem.
- Commits e PRs devem descrever escopo e verificação; não misturar modelagem e reorganização.

## Fontes e estrutura

- `docs/modelagem/ER.drawio` e `Relacional.pdf`: diagramas principais existentes.
- `ER.pdf`, `ER.drawio`, `Relacional.mmd` e `Relacional.pdf` estão disponíveis; preservar os fontes editáveis.
- O GitHub é a fonte principal. ZIP do Drive e plano de execução são apoio externo;
  não importar suas versões nem transformar sugestões em decisões sem solicitação do grupo.
- `docs/decisoes.md`: separar fatos confirmados, observações dos modelos e propostas não validadas.
- `sql/01_tabelas.sql`: tabelas e demais estruturas; `02_triggers.sql`: funções e triggers;
  `03_dml.sql`: dados; `04_consultas.sql`: cinco consultas e respectivos objetivos.
- `prototipo/main.py`, configuração local `config.json`, dependências `requirements.txt`.
- `tests/`: baseline DDL, triggers e ensaio do pacote; `entrega/`: derivados finais, sem cópias-fonte divergentes.
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
- Q1–Q6 foram confirmadas pelo usuário e estão registradas em `docs/decisoes.md`.
- Modelo local utilizado: qwen3:8b. Integração validada em PostgreSQL 18.6 e Python 3.12;
  requisito acadêmico permanece PostgreSQL e Python 3.11+. Versões Python em requirements.txt.
- Consultar `docs/ddl.md` para colunas, restrições, integração dos triggers e resultados dos testes.

As instruções dos PDFs descrevem os requisitos acadêmicos. Exercícios de treinamento
e sugestões nos documentos de referência não autorizam mudanças de escopo nem
devem ser tratados como o esquema do grupo.

## Entrega e validação finais

- Gerar artefatos por `python scripts/preparar_entrega.py`; não editar derivados.
- Projeto.txt é a fonte runtime do DDL e das cinco consultas. Não depender de sql/ no ZIP.
- Nunca incluir config.json local; o empacotador gera exemplo sem senha real.
- Testar o ZIP extraído por `tests/test_entrega.py` em instância exclusiva de testes.
- Evidências em docs/validacao_entrega.json; limitações em docs/integracao-final.md.
- Usar o isolamento padrão READ COMMITTED nos fluxos de escrita demonstrados.
- Não considerar teste com mock como aprovação do Ollama local real.
