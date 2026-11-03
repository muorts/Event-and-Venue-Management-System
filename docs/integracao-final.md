# Integração e entrega final — 03/11/2026

## Proveniência

- Main de partida: `231abc8`, incluindo os documentos e o Projeto.txt parcial de Murilo.
- PR #4 de João Marcelo: `181a2fd`, protótipo, requirements e fonte Mermaid/PDF.
- PR #5 de Marcela: `b53b0d7`, seis triggers, testes funcionais e documentação.
- Branch de Lucas/Waldrighi: `65ec299`, DML e cinco consultas. Os dois SQLs conferem
  com o ZIP entregue pelo Lucas, após normalização CRLF/LF. Usamos os commits da
  branch para preservar a autoria; o ZIP de apoio não foi importado para o Git.
- Nenhuma entidade, coluna, PK, FK ou cardinalidade foi alterada na integração.
  Os fontes e os PDFs dos diagramas foram preservados.

## Correções verificadas

### Concorrência entre inscrição e capacidade do espaço

O teste nativo com duas conexões reproduziu um defeito na versão recebida:
duas inscrições ainda não commitadas eram ignoradas por uma redução concorrente
da sala; ao final havia duas confirmações para uma capacidade de uma pessoa.

Adicionamos três triggers BEFORE STATEMENT que usam a mesma advisory lock
transacional nas escritas de inscrição, sessão e espaço, antes dos locks de linha.
As funções originais de Marcela foram preservadas. Essa escolha conservadora
serializa essas escritas no volume acadêmico, preservando leituras concorrentes.
Os ensaios usam READ COMMITTED, padrão do PostgreSQL. Não se afirma correção para
qualquer isolamento ou operação administrativa arbitrária.

O teste de regressão mantém a segunda conexão esperando continuamente, commita a
primeira e verifica a decisão final, sem timeout seguido de retry manual.

### Integridade de status e participação mínima

- O controle de vagas não converte mais status inválido/NULL em CONFIRMADA:
  as restrições originais NOT NULL/CHECK voltam a rejeitar essas entradas.
- Quatro constraint triggers adiáveis implementam as participações mínimas já
  existentes no E/R: EVENTO tem alguma EDICAO, EDICAO tem algum PROMOTOR.
  Pai e filhos podem ser cadastrados na mesma transação; a verificação ocorre
  no COMMIT e cobre remoção/transferência de vínculos.
- São 13 objetos de trigger ao todo: seis originais de Marcela, três de
  sincronização e quatro de participação mínima. Há nove funções de trigger.

### Protótipo e portabilidade

- Mantida a implementação de João e a leitura de DDL/consultas de Projeto.txt.
- Projeto.txt ausente agora encerra com código 1, conforme o PDF, em vez de
  permitir uso do modelo sem o arquivo obrigatório.
- O ensaio real do qwen3:8b revelou um filtro indevido por REALIZADA na pergunta
  sobre lotação. Esclarecemos no prompt a diferença entre status e ocupação,
  sem embutir SQL/respostas ou IDs da carga. Uma execução passou a retornar as
  três sessões corretas, mas outras ainda produziram SQL incorreto. Esses casos
  são registrados como limitações, sem contá-los como acertos. O teste também
  verifica a mensagem de erro e a continuidade do menu, conforme o enunciado.
- Dependências diretas fixadas nas versões utilizadas nos testes: ollama 0.6.3
  e psycopg[binary] 3.3.7. Python de integração: 3.12.
- Configuração distribuível possui senha fictícia; configuração local nunca é
  lida pelo empacotador. São preservadas exatamente as chaves previstas no PDF.

## Artefatos e reprodução

`python scripts/preparar_entrega.py` gera `entrega/` a partir das fontes.
Opcionalmente: `--zip-final caminho.zip` gera o compactado principal.

Os oito artefatos são ER.pdf, ER.xml, Relacional.pdf, Relacional.mmd, Projeto.txt,
DML.sql, Prototipo.zip e Instrucoes.txt. ER.drawio de entrega foi renomeado com
git mv para ER.xml; seu conteúdo XML permanece o mesmo do fonte editável.
O fonte ER.drawio continua em docs/modelagem.

O ZIP principal contém a pasta ProjetoBD. Prototipo.zip deve ser extraído dentro
dela, resultando em ProjetoBD/Prototipo/{main.py,config.json,requirements.txt},
com ProjetoBD/Projeto.txt no diretório pai. Não há dependência runtime de sql/.

Projeto.txt é consolidado de 01_tabelas.sql, 02_triggers.sql e das cinco consultas
de 04_consultas.sql. DML.sql copia 03_dml.sql. As cópias de entrega não devem ser
editadas manualmente: corrigir a fonte e regenerar. A cópia de Projeto.txt na
raiz serve ao teste de desenvolvimento e está ignorada no Git.

Não há prompts, conversas, ambientes virtuais, modelos, binários, configurações
reais ou arquivos temporários no pacote final. Os PDFs existentes foram renderizados
e inspecionados: uma página cada, com fontes editáveis correspondentes.

O enunciado deixa incompleto o nome do compactado principal e alterna Instrucoes.txt
com 06.Instrucoes.txt no texto. Adotamos Instrucoes.txt, nome da lista de arquivos,
e SCC0640_Semana_da_Computacao_2026.zip para o compactado. Essa escolha deve ser
ajustada caso exista orientação adicional da disciplina, sem duplicar versões.

## Testes e limites

`tests/test_entrega.py` extrai o ZIP real, cria bases nativas novas numa instância
exclusiva de testes e executa os componentes efetivamente entregues. O relatório
sanitizado fica em `docs/validacao_entrega.json` após o ensaio final.

São verificados os 125 testes originais do DDL em base separada, os testes
funcionais 02–18 de Marcela, as cinco consultas com 19/19/11/12/10 linhas,
rollback após erro, READ ONLY, caminhos relativos, Projeto.txt ausente,
cardinalidades e os quatro cenários concorrentes mencionados acima.

O parâmetro `--testar-ollama` também usa o modelo local real, compara respostas
com consultas de referência e exercita a opção de linguagem natural da CLI.
Teste com mock não conta como aprovação dessa integração.

Limitações mantidas e explicadas em Instrucoes.txt: representação sem sessões
atravessando meia-noite; ausência de validação automática de recursos e de data
da sessão dentro da edição; ausência de bloqueio de inscrição por status da
sessão; limites de exibição da CLI; possível erro semântico do SQL gerado.
As regras de negócio não confirmadas não foram inventadas silenciosamente.
Cancelamento por status é o caminho demonstrado para promover a espera;
exclusão física de inscrição não possui trigger de promoção automática.

## Responsabilidades finais

Lucas escreve as cinco consultas e objetivos. João reutiliza essas consultas no
menu e lê o SQL final de Projeto.txt. Victor consolida e testa os derivados.
Murilo mantém a documentação e os diagramas; Marcela mantém as regras de triggers.
As seis decisões aprovadas permanecem em docs/decisoes.md e no Projeto.txt.

SHA-256 do ZIP recebido de Lucas: `a7de14101f82accc7ccf56491aa2270ff30f9b39396766382d5ac138f0f9bb1b`.
