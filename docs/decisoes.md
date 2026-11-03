# Decisões e observações da reorganização

## Confirmado pelo grupo nesta solicitação

Reorganização inicial autorizada pelo proprietário, em branch própria, preservando
o trabalho existente e sem implementação ou alterações na modelagem. Tecnologias:
PostgreSQL, Python 3.11+ e Ollama local; CLI, quatro triggers de finalidades distintas
e cinco consultas. Responsabilidades e entrega em 03/11/2026 constam no README.

## O que os modelos existentes registram

O E/R principal distingue EVENTO e EDICAO, ATIVIDADE e SESSAO, mantém uma PESSOA
com papéis por contexto, PROMOTOR relacionado a EDICAO em N:N, recursos associados
a espaços e atividades e HISTORICO_SESSAO. Sua legenda referencia Q1–Q6.
Essas são observações dos arquivos existentes, não novas decisões desta reorganização.
O PDF relacional contém as nove entidades e sete tabelas associativas correspondentes.

## Fonte principal e material de apoio

O GitHub é a fonte principal, conforme confirmado pelo usuário. O ZIP do Drive e
o plano de execução gerado são apenas apoio externo. Nenhum arquivo desses
materiais foi incorporado ao resultado desta reorganização. As propostas de
regras, consultas e triggers não são decisões confirmadas por estarem nesses documentos.
O arquivo `docs/decisoes` do GitHub estava vazio na reorganização. Posteriormente,
o usuário confirmou as seis decisões abaixo e autorizou o DDL.

## Preservação e fontes

- O E/R e o relacional existentes no GitHub foram mantidos integralmente e apenas movidos.
- O ZIP GitHub fornecido corresponde aos arquivos do clone, desconsideradas quebras CRLF/LF.
- Os 16 scripts SQL eram marcadores de uma quebra de linha. `01_evento.sql` foi
  movido para `sql/01_tabelas.sql`; os outros 15 foram removidos por não conterem SQL,
  eliminando a estrutura antiga sem descartar implementação. O histórico Git os preserva.
- `prototipo/prototipo` vazio foi movido para `prototipo/main.py`, ainda vazio.
- `build_projeto_txt.py` e `template_projeto.txt`, ambos vazios, foram preservados em
  `docs/legado/` para não misturar ferramentas/template com artefatos finais.
- Nenhum documento existente foi apagado. `entrega/Instrucoes.txt` continua vazio.

## Pendências e inconsistências

- ER.pdf e XML E/R foram disponibilizados por Murilo; João forneceu Relacional.mmd e PDF.
  Os quatro artefatos correspondentes são gerados em entrega/ a partir dessas fontes.
- DDL, triggers, DML, consultas e protótipo integrados. Evidências finais em
  `validacao_entrega.json`; fontes e correções em `integracao-final.md`.
- O fonte Mermaid de João foi confrontado com as 16 tabelas e os diagramas;
  PDFs finais foram renderizados e inspecionados, sem alteração de entidades/cardinalidades.
- O PDF relacional especifica `HISTORICO_SESSAO.espaco_anterior` como `varchar`.
  Preservar os identificadores e atributos do modelo do GitHub; dúvidas serão
  documentadas em `ddl.md`, sem mudança de atributos.
- No pacote futuro, reconciliar `prototipo/` do repositório com `Prototipo/` do PDF e
  garantir `Projeto.txt` no diretório pai, inclusive ao descompactar Prototipo.zip.
- O enunciado lista `Instrucoes.txt`, mas o parágrafo seguinte diz `06.Instrucoes.txt`;
  a frase sobre o nome do arquivo compactado final está incompleta. Confirmar na entrega.
- O modelo local adotado na integração é `qwen3:8b`, usado por João e configurado no pacote final.
- As tabelas e alterações do PDF de treinamento são exemplos independentes, não mudanças para este modelo.

## Entrega futura sem fontes divergentes

Gerar Projeto.txt das fontes SQL e decisões finais, DML.sql de `sql/03_dml.sql`,
PDFs dos respectivos fontes e Prototipo.zip do protótipo. Incluir configuração
distribuível sem senhas reais e instruções de instalação/execução. Manter o template
exato do professor e Q1–Q6 em uma linha cada. Não gerar artefatos finais vazios.

## Decisões definitivas aprovadas para o DDL

Q1: Promotores são entidade própria para pessoas ou organizações e se associam às edições por N:N, permitindo promoção conjunta.
Q2: Pessoas têm cadastro único e podem acumular participante, organizador e palestrante/instrutor em associações específicas.
Q3: Cada atividade pertence a uma edição e pode ter várias sessões; dados gerais ficam na atividade e data, horário, espaço e vagas na sessão.
Q4: Evento é a iniciativa recorrente e edição é a realização identificada por evento e ano, com programação e inscrições próprias.
Q5: A inscrição na edição é independente da inscrição em sessões; sessões com inscrição específica usam o menor limite entre capacidade física e vagas próprias, com lista de espera.
Q6: A sessão guarda a programação atual e mudanças de data, horário ou espaço são preservadas em histórico por trigger.

As propostas anteriores do material de apoio não acrescentam regras a estas decisões.
Não exigir vínculo em `inscricao_edicao` como pré-requisito de `inscricao_sessao`.
O contrato técnico e as limitações das cardinalidades mínimas estão em [ddl.md](ddl.md).

## Contrato final de execucao

O main.py le DDL e as cinco consultas do Projeto.txt, localizado no diretorio pai
de Prototipo. sql/04_consultas.sql e a fonte de desenvolvimento de Lucas. O
empacotador consolida os derivados, sem depender da pasta sql/ na entrega.
NULL em vagas_limite significa ausencia de limite proprio, mantendo a capacidade
fisica no controle de inscricoes, como implementado por Marcela e Lucas.
