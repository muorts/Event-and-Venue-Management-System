# Documentação das Triggers — SCC0640

## Sistema de Gestão de Eventos e Espaços

Este documento descreve as seis funções de trigger implementadas em PostgreSQL para garantir regras de integridade relacionadas ao agendamento de sessões, às inscrições, à lista de espera e à capacidade dos espaços.

**Arquivo de implementação:** `sql/02_triggers.sql`  
**Arquivo de testes:** `tests/test_triggers.sql`

## 1. Controle de vagas e lista de espera

**Função:** `fn_controlar_vagas_sessao()`  
**Trigger:** `trg_controlar_vagas_sessao`  
**Tabela:** `inscricao_sessao`  
**Momento:** BEFORE INSERT OR UPDATE OF status  
**Dados utilizados:** NEW e OLD (em atualizações).

### Regras implementadas

- A capacidade efetiva é o menor valor entre o limite da sessão e a capacidade física do espaço.
- Quando `vagas_limite` é NULL, utiliza-se a capacidade física do espaço.
- Apenas inscrições com status `CONFIRMADA` ocupam vagas.
- Se houver disponibilidade e ninguém aguardando, a inscrição é confirmada.
- Caso contrário, a pessoa entra na lista de espera.
- As posições da lista de espera são atribuídas sequencialmente.
- Inscrições que permanecem na lista preservam sua posição.
- O cancelamento remove a posição de espera.
- Alterações de pessoa ou sessão são rejeitadas quando a função é acionada.

### Concorrência

A função utiliza `SELECT ... FOR UPDATE` na linha da sessão para serializar operações de inscrição concorrentes.

Essa estratégia foi verificada em um cenário com duas conexões PostgreSQL, no qual a segunda operação aguardou o encerramento da transação que mantinha o bloqueio.

**Limitação:** a trigger é acionada em INSERT ou UPDATE de `status`. Alterações somente nas colunas de identificação não acionam essa verificação.

## 2. Promoção automática da lista de espera

**Função:** `fn_promover_lista_espera()`  
**Trigger:** `trg_promover_lista_espera`  
**Tabela:** `inscricao_sessao`  
**Momento:** AFTER UPDATE OF status  
**Dados utilizados:** OLD e NEW.

### Regras implementadas

- A promoção ocorre quando uma inscrição passa de `CONFIRMADA` para `CANCELADA`.
- A primeira pessoa da lista de espera é selecionada pela posição, com critérios adicionais de desempate.
- A inscrição selecionada é atualizada para `CONFIRMADA`.
- Sua posição de espera é removida.
- A função de controle de vagas também é acionada durante essa atualização.
- Cancelamentos repetidos não provocam uma nova promoção.

### Observações

A promoção é realizada por uma atualização na própria tabela de inscrições. A condição da trigger evita uma nova promoção quando a inscrição atualizada não passou de confirmada para cancelada.

O cancelamento de uma inscrição em lista de espera não aciona essa promoção.

## 3. Histórico de alterações das sessões

**Função:** `fn_registrar_historico_sessao()`  
**Trigger:** `trg_registrar_historico_sessao`  
**Tabela:** `sessao`  
**Momento:** AFTER UPDATE OF id_espaco, data, hora_inicio, hora_fim  
**Dados utilizados:** OLD e NEW.

### Regras implementadas

- Registra alterações reais de espaço, data ou horário.
- Armazena os valores anteriores da sessão.
- Utiliza `IS DISTINCT FROM` para comparar os valores.
- Atualizações sem mudança efetiva não geram histórico.
- Alterações apenas no status não geram histórico.
- Atualizações rejeitadas não produzem histórico persistente.

### Observações

O campo `espaco_anterior` recebe o identificador anterior do espaço convertido para texto, conforme a estrutura da tabela `historico_sessao`.

O campo `motivo` é preenchido com NULL porque a implementação atual não recebe uma justificativa para a alteração.

## 4. Verificação de conflitos de horários

**Função:** `fn_verificar_conflito_sessao()`  
**Trigger:** `trg_verificar_conflito_sessao`  
**Tabela:** `sessao`  
**Momento:** BEFORE INSERT OR UPDATE OF id_espaco, data, hora_inicio, hora_fim, status  
**Dados utilizados:** NEW e identificação da própria sessão.

### Regras implementadas

- Impede sessões simultâneas no mesmo espaço e na mesma data.
- Detecta sobreposições parciais e totais.
- Permite horários consecutivos, quando uma sessão termina exatamente no início da outra.
- Permite sessões simultâneas em espaços diferentes.
- Permite o mesmo horário em datas diferentes.
- Desconsidera sessões com status `CANCELADA`.
- Exclui a própria sessão da comparação em atualizações.
- Também verifica conflitos quando o status é alterado.

### Concorrência

A função bloqueia a linha do espaço com `FOR UPDATE`, buscando impedir que transações concorrentes confirmem agendamentos conflitantes sem sincronização.

O teste simultâneo de criação de sessões conflitantes ainda deve ser documentado separadamente.

## 5. Proteção contra redução indevida de vagas

**Função:** `fn_impedir_reducao_vagas()`  
**Trigger:** `trg_impedir_reducao_vagas`  
**Tabela:** `sessao`  
**Momento:** BEFORE UPDATE OF vagas_limite, id_espaco  
**Dados utilizados:** OLD e NEW, principalmente os novos limites.

### Regras implementadas

- Calcula a capacidade efetiva da sessão após a alteração.
- Considera tanto `vagas_limite` quanto a capacidade física do espaço.
- Conta as inscrições confirmadas existentes.
- Rejeita a atualização quando a quantidade de confirmados ultrapassa a nova capacidade.
- Permite alterações que mantenham capacidade suficiente para os participantes confirmados.

### Observações

Essa função protege atualizações de sessões existentes. A implementação atual não realiza essa mesma contagem em operações de INSERT.

## 6. Validação da capacidade física do espaço

**Função:** `fn_validar_capacidade_espaco()`  
**Trigger:** `trg_validar_capacidade_espaco`  
**Tabela:** `espaco`  
**Momento:** BEFORE UPDATE OF capacidade  
**Dados utilizados:** OLD e NEW.

### Regras implementadas

- Permite aumentos de capacidade.
- Quando a capacidade diminui, verifica as sessões vinculadas ao espaço.
- Conta as inscrições confirmadas de cada sessão.
- Rejeita a redução se alguma sessão possuir mais confirmados do que a nova capacidade.
- Permite a redução quando todas as sessões respeitam o novo limite físico.

## 7. Testes funcionais

Os testes estão organizados no arquivo `tests/test_triggers.sql`.

Na execução realizada no pgAdmin, os testes funcionais numerados de 02 a 16 apresentaram mensagens de aprovação, abrangendo:

- Criação de sessões sem conflito.
- Rejeição de sobreposições parciais e totais.
- Permissão de horários consecutivos.
- Agendamentos em salas e datas diferentes.
- Atualizações conflitantes e atualizações sem mudança.
- Registro correto do histórico.
- Ausência de histórico indevido.
- Confirmação de inscrições com vagas disponíveis.
- Entrada e ordenação da lista de espera.
- Promoção automática após cancelamento.
- Ausência de promoção duplicada.

Os testes utilizam transações com `ROLLBACK` para desfazer as alterações realizadas durante a verificação.

As duas triggers adicionais de proteção de capacidade foram implementadas e precisam ter seus resultados específicos registrados na documentação de testes.

## 8. Testes de concorrência

Foi utilizado o PostgreSQL 17 por meio do pgAdmin, com duas conexões independentes identificadas por `pg_backend_pid()`.

No cenário de inscrição concorrente, a primeira conexão manteve uma transação aberta após ocupar a última vaga de uma sessão. A segunda tentativa de inscrição encontrou o bloqueio da sessão e atingiu o tempo limite de espera configurado.

Após a conclusão da primeira transação, a operação foi repetida e pôde prosseguir.

**Interpretação:** o teste demonstrou a existência do bloqueio entre transações. Ele não comprova, isoladamente, todos os comportamentos de concorrência exigidos pelo projeto.

Ainda devem ser verificados e registrados:

- Duas inscrições simultâneas disputando a última vaga, com resultado final conferido.
- Dois agendamentos simultâneos conflitantes.
- Possíveis situações de deadlock.
- Redução de capacidade com inscrições existentes.

## 9. Decisões e limitações

- A capacidade física do espaço é sempre considerada no cálculo das vagas.
- O limite da sessão pode ser NULL, indicando ausência de limite próprio, mas não capacidade física ilimitada.
- A lista de espera utiliza posições positivas e únicas por sessão.
- A transferência de uma inscrição para outra pessoa ou sessão não é uma operação suportada pela regra implementada; porém, a proteção atual não cobre atualizações que alterem somente as chaves.
- A promoção automática ocorre em cancelamentos por UPDATE. Exclusões físicas por DELETE não acionam essa regra.
- A reativação de sessões canceladas é submetida à verificação de conflitos de horário.
- A redução de capacidade é protegida pelas duas triggers adicionais.
- Os mecanismos de bloqueio precisam ser considerados em operações concorrentes para evitar esperas excessivas e possíveis deadlocks.

## 10. Conclusão

As seis funções de trigger implementam controles de integridade para o gerenciamento de sessões, inscrições, lista de espera, histórico e capacidade.

Os testes funcionais realizados demonstraram o comportamento esperado nos cenários aprovados. A validação final depende da execução e documentação dos casos adicionais de concorrência e das regras especiais ainda pendentes.

**Arquivos relacionados:**

- `sql/01_tabelas.sql` — estrutura das tabelas.
- `sql/02_triggers.sql` — implementação das funções e triggers.
- `tests/test_triggers.sql` — testes funcionais.
