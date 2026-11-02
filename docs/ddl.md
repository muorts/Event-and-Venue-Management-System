# Contrato do DDL — Victor

Fonte canônica: `sql/01_tabelas.sql`. Base de desenvolvimento: `main` no commit
`76c3da0`; branch `feat/ddl-victor`. Modelagem oficial: `docs/modelagem/ER.drawio`
e `docs/modelagem/Relacional.pdf`. As seis decisões foram aprovadas pelo grupo.
Não foram criados os triggers, o DML de entrega, as cinco consultas ou o protótipo.

## Execução

Criar uma base PostgreSQL vazia e executar o script completo:

```sh
createdb -h localhost -U postgres scc0640_ddl_teste
psql -X -h localhost -U postgres -d scc0640_ddl_teste -v ON_ERROR_STOP=1 -f sql/01_tabelas.sql
psql -X -h localhost -U postgres -d scc0640_ddl_teste -v ON_ERROR_STOP=1 -f tests/ddl_integridade.sql
```

Executar da raiz do repositório. A criação é atômica (`BEGIN`/`COMMIT`) e não contém
DROP nem substituição silenciosa de tabelas. O teste pressupõe base sem dados,
utiliza fixtures sintéticas e funções temporárias e termina com `ROLLBACK`.
Fixtures de teste não são o DML do trabalho. Não executar o teste em base com dados do grupo.

## As 16 tabelas, colunas, PKs e FKs

`integer` = int do modelo; `character varying` = varchar sem limite artificial;
timestamps e horários são locais, sem fuso, conforme o PDF. PK e NOT NULL são
obrigatórios. Colunas listadas como NULL são opcionais.

### `evento`

Iniciativa recorrente, independente de uma realização anual.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_evento` | `integer` | não | `identity BY DEFAULT` |
| `nome` | `character varying` | não | `—` |
| `descricao` | `text` | sim | `—` |
| `area` | `character varying` | sim | `—` |

- `pk_evento`: `PRIMARY KEY (id_evento)`.

### `promotor`

Pessoa ou organização que promove edições.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_promotor` | `integer` | não | `identity BY DEFAULT` |
| `nome` | `character varying` | não | `—` |
| `tipo` | `character varying` | não | `—` |
| `documento` | `character varying` | não | `—` |

- `pk_promotor`: `PRIMARY KEY (id_promotor)`.
- `uq_promotor_documento`: `UNIQUE (documento)`.

### `pessoa`

Cadastro único das pessoas que assumem papéis por contexto.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_pessoa` | `integer` | não | `identity BY DEFAULT` |
| `nome` | `character varying` | não | `—` |
| `email` | `character varying` | não | `—` |
| `instituicao` | `character varying` | sim | `—` |

- `pk_pessoa`: `PRIMARY KEY (id_pessoa)`.
- `uq_pessoa_email`: `UNIQUE (email)`.

### `espaco`

Local físico, com tipo, capacidade e prédio.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_espaco` | `integer` | não | `identity BY DEFAULT` |
| `nome` | `character varying` | não | `—` |
| `tipo` | `character varying` | não | `—` |
| `capacidade` | `integer` | não | `—` |
| `predio` | `character varying` | sim | `—` |

- `pk_espaco`: `PRIMARY KEY (id_espaco)`.

### `recurso`

Catálogo de recursos disponíveis ou exigidos.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_recurso` | `integer` | não | `identity BY DEFAULT` |
| `nome` | `character varying` | não | `—` |

- `pk_recurso`: `PRIMARY KEY (id_recurso)`.
- `uq_recurso_nome`: `UNIQUE (nome)`.

### `edicao`

Realização de um evento em determinado ano, com período e situação.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_edicao` | `integer` | não | `identity BY DEFAULT` |
| `id_evento` | `integer` | não | `—` |
| `ano` | `integer` | não | `—` |
| `data_inicio` | `date` | não | `—` |
| `data_fim` | `date` | não | `—` |
| `cidade` | `character varying` | sim | `—` |
| `status` | `character varying` | não | `'PLANEJADA'::character varying` |

- `fk_edicao_evento`: `FOREIGN KEY (id_evento) REFERENCES evento(id_evento) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_edicao`: `PRIMARY KEY (id_edicao)`.
- `uq_edicao_evento_ano`: `UNIQUE (id_evento, ano)`.

### `atividade`

Item da programação de uma edição, com seus dados gerais.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_atividade` | `integer` | não | `identity BY DEFAULT` |
| `id_edicao` | `integer` | não | `—` |
| `titulo` | `character varying` | não | `—` |
| `descricao` | `text` | sim | `—` |
| `tipo` | `character varying` | não | `—` |
| `carga_horaria` | `integer` | sim | `—` |

- `fk_atividade_edicao`: `FOREIGN KEY (id_edicao) REFERENCES edicao(id_edicao) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_atividade`: `PRIMARY KEY (id_atividade)`.

### `sessao`

Realização concreta de uma atividade, com data, horário, espaço e limite próprio.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_sessao` | `integer` | não | `identity BY DEFAULT` |
| `id_atividade` | `integer` | não | `—` |
| `id_espaco` | `integer` | não | `—` |
| `data` | `date` | não | `—` |
| `hora_inicio` | `time without time zone` | não | `—` |
| `hora_fim` | `time without time zone` | não | `—` |
| `vagas_limite` | `integer` | sim | `—` |
| `status` | `character varying` | não | `'AGENDADA'::character varying` |
| `duracao_min` | `integer` | sim | `gerada STORED` |

- `fk_sessao_atividade`: `FOREIGN KEY (id_atividade) REFERENCES atividade(id_atividade) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `fk_sessao_espaco`: `FOREIGN KEY (id_espaco) REFERENCES espaco(id_espaco) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_sessao`: `PRIMARY KEY (id_sessao)`.

### `historico_sessao`

Registro da programação anterior de uma sessão; será preenchido pelo trigger.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_historico` | `integer` | não | `identity BY DEFAULT` |
| `id_sessao` | `integer` | não | `—` |
| `espaco_anterior` | `character varying` | não | `—` |
| `data_anterior` | `date` | não | `—` |
| `hora_inicio_anterior` | `time without time zone` | não | `—` |
| `hora_fim_anterior` | `time without time zone` | não | `—` |
| `alterado_em` | `timestamp without time zone` | não | `CURRENT_TIMESTAMP` |
| `motivo` | `text` | sim | `—` |

- `fk_historico_sessao_sessao`: `FOREIGN KEY (id_sessao) REFERENCES sessao(id_sessao) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_historico_sessao`: `PRIMARY KEY (id_historico)`.

### `edicao_promotor`

Associação N:N entre edições e promotores, com papel.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_edicao` | `integer` | não | `—` |
| `id_promotor` | `integer` | não | `—` |
| `papel` | `character varying` | não | `—` |

- `fk_edicao_promotor_edicao`: `FOREIGN KEY (id_edicao) REFERENCES edicao(id_edicao) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `fk_edicao_promotor_promotor`: `FOREIGN KEY (id_promotor) REFERENCES promotor(id_promotor) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_edicao_promotor`: `PRIMARY KEY (id_edicao, id_promotor)`.

### `inscricao_edicao`

Inscrição geral da pessoa em uma edição.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_pessoa` | `integer` | não | `—` |
| `id_edicao` | `integer` | não | `—` |
| `data_inscricao` | `timestamp without time zone` | não | `CURRENT_TIMESTAMP` |
| `status` | `character varying` | não | `'CONFIRMADA'::character varying` |

- `fk_inscricao_edicao_edicao`: `FOREIGN KEY (id_edicao) REFERENCES edicao(id_edicao) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `fk_inscricao_edicao_pessoa`: `FOREIGN KEY (id_pessoa) REFERENCES pessoa(id_pessoa) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_inscricao_edicao`: `PRIMARY KEY (id_pessoa, id_edicao)`.

### `equipe_edicao`

Papel da pessoa na equipe de uma edição.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_pessoa` | `integer` | não | `—` |
| `id_edicao` | `integer` | não | `—` |
| `papel` | `character varying` | não | `—` |

- `fk_equipe_edicao_edicao`: `FOREIGN KEY (id_edicao) REFERENCES edicao(id_edicao) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `fk_equipe_edicao_pessoa`: `FOREIGN KEY (id_pessoa) REFERENCES pessoa(id_pessoa) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_equipe_edicao`: `PRIMARY KEY (id_pessoa, id_edicao)`.

### `espaco_recurso`

Quantidade de cada recurso disponível em um espaço.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_espaco` | `integer` | não | `—` |
| `id_recurso` | `integer` | não | `—` |
| `quantidade` | `integer` | não | `—` |

- `fk_espaco_recurso_espaco`: `FOREIGN KEY (id_espaco) REFERENCES espaco(id_espaco) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `fk_espaco_recurso_recurso`: `FOREIGN KEY (id_recurso) REFERENCES recurso(id_recurso) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_espaco_recurso`: `PRIMARY KEY (id_espaco, id_recurso)`.

### `atividade_pessoa`

Papel da pessoa que ministra uma atividade.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_atividade` | `integer` | não | `—` |
| `id_pessoa` | `integer` | não | `—` |
| `papel` | `character varying` | não | `—` |

- `fk_atividade_pessoa_atividade`: `FOREIGN KEY (id_atividade) REFERENCES atividade(id_atividade) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `fk_atividade_pessoa_pessoa`: `FOREIGN KEY (id_pessoa) REFERENCES pessoa(id_pessoa) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_atividade_pessoa`: `PRIMARY KEY (id_atividade, id_pessoa)`.

### `atividade_recurso`

Quantidade mínima de cada recurso exigido por uma atividade.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_atividade` | `integer` | não | `—` |
| `id_recurso` | `integer` | não | `—` |
| `quantidade_minima` | `integer` | não | `—` |

- `fk_atividade_recurso_atividade`: `FOREIGN KEY (id_atividade) REFERENCES atividade(id_atividade) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `fk_atividade_recurso_recurso`: `FOREIGN KEY (id_recurso) REFERENCES recurso(id_recurso) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_atividade_recurso`: `PRIMARY KEY (id_atividade, id_recurso)`.

### `inscricao_sessao`

Inscrição específica, situação e posição na lista de espera de uma sessão.

| Coluna | Tipo | Nulo? | Geração/default |
| --- | --- | --- | --- |
| `id_sessao` | `integer` | não | `—` |
| `id_pessoa` | `integer` | não | `—` |
| `data_inscricao` | `timestamp without time zone` | não | `CURRENT_TIMESTAMP` |
| `status` | `character varying` | não | `'CONFIRMADA'::character varying` |
| `posicao_espera` | `integer` | sim | `—` |

- `fk_inscricao_sessao_pessoa`: `FOREIGN KEY (id_pessoa) REFERENCES pessoa(id_pessoa) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `fk_inscricao_sessao_sessao`: `FOREIGN KEY (id_sessao) REFERENCES sessao(id_sessao) ON UPDATE CASCADE ON DELETE RESTRICT`.
- `pk_inscricao_sessao`: `PRIMARY KEY (id_sessao, id_pessoa)`.
- `uq_inscricao_sessao_posicao`: `UNIQUE (id_sessao, posicao_espera) DEFERRABLE`.

## Escolhas técnicas e restrições

- As nove PKs simples usam `integer GENERATED BY DEFAULT AS IDENTITY`, permitindo
  INSERTs com ou sem ID explícito. Não misturar IDs manuais e geração automática
  sem ajustar a sequência correspondente após carga com IDs explícitos. As sete
  associações preservam exatamente as PKs compostas do PDF, sem IDs artificiais.
- Todas as 19 FKs são obrigatórias, `ON DELETE RESTRICT ON UPDATE CASCADE`. A exclusão
  física de pais referenciados é rejeitada para não apagar inscrições/histórico nem
  contornar triggers de cancelamento. Atualização de identificadores propaga às FKs.
  Preferir identificadores estáveis e cancelamento por status.
- `UNIQUE(id_evento, ano)` impede duas edições do mesmo evento/ano. Há UNIQUE também
  em `promotor.documento`, `pessoa.email` e `recurso.nome`. A comparação é literal,
  conforme a collation da base: não foi adicionada normalização de CPF/CNPJ ou email.
- Datas devem ser finitas; `data_fim >= data_inicio`; `ano > 0`. Não se exige que
  todo o período esteja no mesmo ano: esse requisito não consta no modelo.
- Capacidade, quantidades, carga horária informada e limite próprio informado são
  estritamente positivos. `hora_fim > hora_inicio`; sessões que cruzem a meia-noite
  não são representáveis pelo modelo com uma única data e dois horários.
- `duracao_min` é gerada e armazenada pelo banco: minutos completos (arredondamento
  para baixo) da diferença dos horários. Não incluí-la no INSERT/UPDATE do DML ou do
  trigger; consultar NEW após armazenamento ou calcular dos horários em BEFORE.
- Status em maiúsculas conforme o PDF: edição `PLANEJADA`, `EM_ANDAMENTO`,
  `ENCERRADA`, `CANCELADA`; sessão `AGENDADA`, `REALIZADA`, `CANCELADA`; inscrição
  de edição `CONFIRMADA`, `CANCELADA`; inscrição de sessão acrescenta `LISTA_ESPERA`.
- Papéis em minúsculas: promoção `principal`/`co-promotor`; equipe
  `organizador`/`voluntario`; atividade `palestrante`/`instrutor`/`mediador`.
  Tipos de atividade e espaço são texto não vazio: os exemplos do PDF terminam
  em reticências, portanto não foram fechados em um enum inventado.
- `LISTA_ESPERA` exige posição positiva; `CONFIRMADA` e `CANCELADA` exigem posição
  NULL. A posição é única por sessão. A UNIQUE é adiável para reordenar a fila:
  `SET CONSTRAINTS uq_inscricao_sessao_posicao DEFERRED`, realizar alterações e
  validar ao final da transação. Não usar essa UNIQUE adiável como alvo de
  `ON CONFLICT`; usar a PK para upserts de inscrições.
- Datas de inscrição e alteração têm `DEFAULT CURRENT_TIMESTAMP`; status iniciais
  são `PLANEJADA`, `AGENDADA` e `CONFIRMADA`. O BEFORE trigger pode substituir
  a confirmação por espera, preenchendo a posição no mesmo comando.
- Há índices para todas as FKs (por PK/UNIQUE ou índice adicional), programação
  de espaço, histórico da sessão e inscrições por sessão/status.

## Contrato para Marcela

1. Conflito: `sessao(id_espaco, data, hora_inicio, hora_fim, status)`. Identificar
   sessões pela PK, desconsiderar o próprio registro em UPDATE e definir o tratamento
   de canceladas. Para concorrência, serializar pela linha do espaço com bloqueio,
   incluindo espaços antigo/novo em ordem estável quando houver troca.
2. Vagas: `sessao.vagas_limite`, `espaco.capacidade`, `inscricao_sessao.status`.
   Para sessão com limite próprio, limite efetivo = `LEAST(vagas_limite, capacidade)`.
   Um limite próprio maior que a sala é válido: a capacidade física prevalece.
   NULL indica ausência de limite próprio no modelo; não foi criado um booleano.
   Se o grupo quiser distinguir sessão livre de sessão limitada apenas pela sala,
   o modelo atual precisará de um discriminador; não o adicionar silenciosamente.
3. Q5: NÃO exigir inscrição na edição para admitir inscrição em sessão. Essa
   independência foi confirmada; a proposta antiga do Drive não prevalece sobre ela.
4. Controle de vagas e promoção da espera devem bloquear a mesma sessão e excluir
   o registro OLD ao contar ocupação no UPDATE. Não usar MAX(posicao)+1 sem bloqueio.
   Alterar status e posição conjuntamente, pois o CHECK é imediato.
5. Alterações de capacidade, limite ou espaço também podem tornar a ocupação
   existente incompatível: o controle deverá tratar esses UPDATEs e não apenas INSERTs.
6. Histórico: inserir `OLD.id_sessao`, `OLD.id_espaco::varchar`, `OLD.data`,
   `OLD.hora_inicio` e `OLD.hora_fim` nos campos anteriores correspondentes.
   `espaco_anterior` continua varchar sem FK, preservando o identificador como snapshot
   textual; assim o histórico não acompanha alterações futuras do cadastro do espaço.
   Registrar somente mudanças reais de data/horário/espaço; `motivo` é opcional.
7. Datas de sessões dentro da edição e recursos exigidos versus disponíveis dependem
   de consultar outras tabelas. Se implementadas, verificar também alterações no pai,
   e não apenas novas sessões. Nenhuma função de negócio foi criada neste DDL.

## Cardinalidades e diagramas

Não houve mudança de entidades, atributos, PKs, FKs ou cardinalidades. Não há ajuste
conceitual obrigatório nos diagramas por esta implementação. Murilo e João podem
anotar tipos/defaults/CHECKs, geração de duração e UNIQUE da posição de espera.
O arquivo fonte Mermaid e ER.pdf continuam pendentes.

As FKs NOT NULL impõem que toda edição tenha evento, atividade tenha edição e sessão
tenha atividade e espaço. As associações representam N:N. A PK de cada associação
permite um papel por par, conforme o PDF; a mesma pessoa pode acumular os três
papéis de Q2 em associações distintas.

As participações mínimas do lado pai do E/R (`EVENTO` com pelo menos uma `EDICAO`
e `EDICAO` com pelo menos um promotor) não são garantidas por uma FK comum. Pai e
filhos devem ser cadastrados na mesma operação transacional. Para garantia integral
no banco ao COMMIT, serão necessários constraint triggers adiáveis adicionais,
fora desta etapa. Isso está pendente e não foi apresentado como validado pelo DDL.

## Responsabilidades e fonte das consultas

Waldrighi/Lucas escreve e testa as cinco consultas e seus objetivos em
`sql/04_consultas.sql`. João Marcelo integra essas consultas ao menu Python e
apresenta resultados; não precisa escrever outro conjunto de cinco. Victor integra
a versão final no Projeto.txt. O PDF exige extração do DDL de Projeto.txt, mas não
obriga que as consultas do menu sejam lidas dele. Definir o carregamento na etapa
do protótipo, mantendo a mesma versão do SQL.

## Validação executada e limites

Motor utilizado: `PostgreSQL 18.6 (PGlite 0.5.14) on wasm32-unknown-emscripten, compiled by emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) 6.0.5 (1db513782be24469589d7cb8a1f1834e9a33f271), 32-bit`.

**125 verificações aprovadas**, executadas sobre a versão deste DDL:

- DDL completo em base vazia; exatamente 16 tabelas, 16 PKs e 19 FKs validadas.
- Cada FK: UPDATE órfão rejeitado, DELETE do pai rejeitado e conteúdo da FK
  atualizado em cascata após UPDATE do pai.
- Duplicações rejeitadas em cada uma das 16 tabelas; UNIQUEs e principais NOT NULLs.
- Datas/horários inválidos, capacidade/vagas/quantidades, status e papéis inválidos.
- Duração gerada no INSERT e recalculada no UPDATE; tentativa de escrita rejeitada.
- Defaults, acúmulo de papéis, independência das inscrições, fila e cancelamento,
  reordenação com UNIQUE adiada e identidade automática.
- Fixtures revertidas; nenhuma implementação de trigger de negócio presente.

PostgreSQL nativo 18.6 foi encontrado e o serviço local respondeu na porta 5432,
mas a conexão exige senha, que não foi solicitada no chat. Duas tentativas de
inicializar uma instância nativa isolada excederam o tempo no ambiente restrito
(a segunda parou ao selecionar shared_buffers). Portanto, **não foi aprovado nem
executado com sucesso o teste em servidor PostgreSQL nativo**. O resultado acima
é real, mas corresponde ao motor PostgreSQL compilado em WASM pelo PGlite.
Não cobre concorrência de múltiplas conexões, serviço do Windows, autenticação,
psycopg/Ollama ou triggers ainda não implementados. Repetir o mesmo SQL de testes
em base nativa vazia antes da integração final.

Referência técnica: [restrições do PostgreSQL](https://www.postgresql.org/docs/18/ddl-constraints.html)
explica o limite de CHECKs sobre outras linhas/tabelas;
[PGlite](https://pglite.dev/docs/about) descreve o motor WASM utilizado nos testes.
