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
O arquivo `docs/decisoes` do GitHub estava vazio; as respostas finais Q1–Q6
ainda precisam ser validadas e registradas pelo grupo.

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

- Ausentes ER.pdf, exportação XML de entrega e fonte Relacional.mmd; o draw.io já é XML editável,
  mas a exportação com formato/nome de entrega ainda não foi preparada.
- DDL, triggers, DML, consultas e protótipo não estão implementados; não há dependências ou configuração.
- O fonte Mermaid ausente impede auditar automaticamente as cardinalidades do relacional.
  Não declarar a consistência completa entre diagramas sem revisão visual e recuperação do fonte.
- O PDF relacional especifica `HISTORICO_SESSAO.espaco_anterior` como `varchar`.
  Preservar os identificadores e atributos do modelo do GitHub; dúvidas serão
  discutidas antes do DDL, sem correções nesta etapa.
- No pacote futuro, reconciliar `prototipo/` do repositório com `Prototipo/` do PDF e
  garantir `Projeto.txt` no diretório pai, inclusive ao descompactar Prototipo.zip.
- O enunciado lista `Instrucoes.txt`, mas o parágrafo seguinte diz `06.Instrucoes.txt`;
  a frase sobre o nome do arquivo compactado final está incompleta. Confirmar na entrega.
- O exemplo de configuração cita `qwen3:8b`; isso não confirma a escolha do grupo.
- As tabelas e alterações do PDF de treinamento são exemplos independentes, não mudanças para este modelo.

## Entrega futura sem fontes divergentes

Gerar Projeto.txt das fontes SQL e decisões finais, DML.sql de `sql/03_dml.sql`,
PDFs dos respectivos fontes e Prototipo.zip do protótipo. Incluir configuração
distribuível sem senhas reais e instruções de instalação/execução. Manter o template
exato do professor e Q1–Q6 em uma linha cada. Não gerar artefatos finais vazios.
