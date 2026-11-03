> Nota da integração final: este documento preserva o relato original de Marcela.
> A versão final acrescenta sincronização entre tabelas, validação adiada das
> participações mínimas e correção de status inválido/NULL. Veja
> [integração final](integracao-final.md) e [evidências](validacao_entrega.json).

# Documentação das Triggers — SCC0640

## Sistema de Gestão de Eventos e Espaços

Este documento descreve as seis funções de trigger implementadas em PostgreSQL para garantir regras de integridade relacionadas ao agendamento de sessões, às inscrições, à lista de espera e à capacidade dos espaços.

**Arquivo de implementação:** `sql/02_triggers.sql`  
**Arquivo de testes:** `tests/test_triggers.sql`

---

## 1. Controle de vagas e lista de espera

**Função:** `fn_controlar_vagas_sessao()`  
**Trigger:** `trg_controlar_vagas_sessao`  
**Tabela:** `inscricao_sessao`  
**Momento:** BEFORE INSERT OR UPDATE OF status, id_sessao, id_pessoa  
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
- Alterações de pessoa ou sessão por UPDATE são rejeitadas pela função e pela trigger atualizada.

### Concorrência

A função utiliza `SELECT ... FOR UPDATE` na linha da sessão para serializar operações de inscrição concorrentes.

Essa estratégia foi verificada em um cenário com duas conexões PostgreSQL, no qual a segunda operação encontrou o bloqueio mantido pela primeira transação e atingiu o tempo limite configurado.

**Correção aplicada:** a trigger agora é acionada também em UPDATE de `id_sessao` ou `id_pessoa`. Transferências por UPDATE são rejeitadas, inclusive quando somente uma dessas colunas é modificada. A mudança foi confirmada em teste manual no pgAdmin para alteração de sessão.

---

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

---

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

---

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

O teste de concorrência entre agendamentos conflitantes foi realizado com duas conexões PostgreSQL. O bloqueio e a rejeição do conflito foram confirmados, conforme descrito na seção 8.

---

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

---

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

---

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

As duas triggers adicionais de proteção de capacidade foram verificadas pelos testes automatizados 17 e 18, ambos aprovados no pgAdmin.

O teste 01 realiza a consulta de identificação das triggers. Os testes 02 a 18 verificam comportamentos funcionais.

### Teste 19 — Bloqueio de transferência de inscrições

Foi identificado um problema na definição inicial da trigger `trg_controlar_vagas_sessao`: atualizações que modificavam exclusivamente `id_sessao` ou `id_pessoa` não acionavam a função de validação.

Em um teste manual, uma inscrição confirmada foi transferida por UPDATE para uma sessão lotada, ultrapassando o limite de vagas.

A definição da trigger foi corrigida para:

`BEFORE INSERT OR UPDATE OF status, id_sessao, id_pessoa`

Após a correção, o teste manual de alteração de `id_sessao` foi repetido e apresentou o resultado:

**TESTE APROVADO: transferencia de sessao bloqueada**

O teste 19 foi acrescentado ao arquivo `tests/test_triggers.sql` para verificar:

- Rejeição de alteração de `id_sessao`.
- Rejeição de alteração de `id_pessoa`.
- Preservação da inscrição original após as tentativas rejeitadas.
- Descarte dos dados temporários por `ROLLBACK`.

**Situação:** a alteração de sessão já foi validada manualmente. A execução integral do teste 19, incluindo a alteração de pessoa, ainda precisa ser confirmada.

---

## 8. Testes de concorrência

Foi utilizado o PostgreSQL 17 por meio do pgAdmin, com duas conexões independentes identificadas por `pg_backend_pid()`.

Foram realizados três cenários de concorrência:

1. Disputa pela última vaga de uma sessão.
2. Tentativa de criação de agendamentos conflitantes.
3. Inscrição simultânea à tentativa de redução do limite de vagas.

Em todos os cenários, a primeira conexão manteve uma transação aberta enquanto a segunda tentava realizar uma operação relacionada aos mesmos dados.

As operações da segunda conexão encontraram bloqueios e atingiram o tempo limite configurado de 5 segundos (`SQLSTATE 55P03`).

Após o encerramento das primeiras transações, as operações foram repetidas para verificar o comportamento das regras de integridade.

**Interpretação:** os testes demonstraram a existência de bloqueios entre transações e os resultados esperados após sua liberação. Entretanto, as operações que atingiram o timeout foram repetidas posteriormente, não permanecendo em espera contínua até o `COMMIT`.

### Testes adicionais de capacidade

**Teste 17 — Redução da capacidade física do espaço**

- Trigger testada: `trg_validar_capacidade_espaco`.
- Cenário: espaço com capacidade 30 e sessão com 2 inscrições confirmadas.
- Operação: tentativa de reduzir a capacidade física para 1.
- Resultado esperado: a alteração deve ser bloqueada.
- Resultado obtido: TESTE 17 APROVADO.
- Os dados temporários são desfeitos com `ROLLBACK`.

**Teste 18 — Redução do limite de vagas da sessão**

- Trigger testada: `trg_impedir_reducao_vagas`.
- Cenário: sessão com limite de 2 vagas e 2 inscrições confirmadas.
- Operação: tentativa de reduzir `vagas_limite` para 1.
- Resultado esperado: a alteração deve ser bloqueada.
- Resultado obtido: TESTE 18 APROVADO.
- O teste também verifica se `vagas_limite` permanece igual a 2.
- Os dados temporários são desfeitos com `ROLLBACK`.

### Teste de concorrência — disputa pela última vaga

**Banco utilizado:** `scc0640_teste_marcela`  
**Sessão de teste:** 22  
**Limite de vagas:** 1

**Procedimento:**

1. Na conexão 1, foi iniciada uma transação e realizada a inscrição da pessoa 14.
2. A inscrição recebeu status `CONFIRMADA`.
3. A transação permaneceu aberta, mantendo o bloqueio da sessão.
4. Na conexão 2, a pessoa 15 tentou se inscrever.
5. A operação aguardou o bloqueio e atingiu o timeout de 5 segundos (`SQLSTATE 55P03`).
6. Foi executado `COMMIT` na conexão 1.
7. Na conexão 2, foi executado `ROLLBACK` para encerrar a transação abortada.
8. A inscrição da pessoa 15 foi repetida com sucesso.

**Resultado final:**

- Pessoa 14: `CONFIRMADA`.
- Pessoa 15: `LISTA_ESPERA`, posição 1.
- Total de confirmados: 1.
- Capacidade da sessão respeitada.

**Resultado:** APROVADO.

**Conclusão:** o teste confirmou o bloqueio entre conexões e o comportamento correto das inscrições após a liberação da transação. A segunda tentativa foi repetida após o timeout; portanto, não foi uma espera contínua até o `COMMIT`.

**Limpeza:** as inscrições de teste e a sessão 22 foram removidas após a verificação.

### Teste de concorrência — agendamentos conflitantes

**Banco utilizado:** `scc0640_teste_marcela`  
**Espaço utilizado:** 2 — Sala Conflito  
**Sessão de teste:** 23  
**Data:** 15/12/2026

**Procedimento:**

1. Na conexão 1, foi iniciada uma transação e criada a sessão 23, das 14:00 às 15:00.
2. A primeira transação permaneceu aberta, mantendo o bloqueio do espaço 2.
3. Na conexão 2, foi realizada uma tentativa de criar outra sessão no mesmo espaço, das 14:30 às 15:30.
4. A segunda operação aguardou o bloqueio e atingiu o timeout de 5 segundos (`SQLSTATE 55P03`).
5. Foi executado `COMMIT` na conexão 1.
6. Na conexão 2, foi executado `ROLLBACK` para encerrar a transação abortada.
7. A tentativa de criar a sessão conflitante foi repetida.
8. O PostgreSQL rejeitou a operação com a mensagem: `Conflito de horário: já existe uma sessão nesse espaço.` (`SQLSTATE P0001`).

**Resultado:** APROVADO.

**Conclusão:** o teste confirmou o bloqueio entre conexões e a rejeição do agendamento conflitante após a confirmação da primeira transação. A segunda tentativa foi repetida após o timeout, não permanecendo em espera contínua até o `COMMIT`.

**Limpeza:** a sessão temporária 23 foi excluída após o teste.

### Teste de concorrência — inscrição e redução de vagas

**Banco utilizado:** `scc0640_teste_marcela`  
**Sessão de teste:** 26  
**Limite inicial:** 2 vagas

**Procedimento:**

1. Na conexão 1, foi iniciada uma transação e realizada a inscrição da pessoa 14, com status `CONFIRMADA`.
2. A transação permaneceu aberta.
3. Na conexão 2, foi realizada uma tentativa de reduzir `vagas_limite` de 2 para 1.
4. A operação aguardou o bloqueio e atingiu o timeout de 5 segundos (`SQLSTATE 55P03`).
5. Foi executado `COMMIT` na conexão 1.
6. Na conexão 2, foi executado `ROLLBACK` para encerrar a transação abortada.
7. A redução de 2 para 1 vaga foi repetida e permitida.
8. Uma nova tentativa de reduzir o limite de 1 para 0 vagas foi rejeitada pela função `fn_impedir_reducao_vagas()` (`SQLSTATE P0001`).
9. Uma consulta confirmou que a sessão permaneceu com 1 vaga e 1 inscrição confirmada.

**Resultado:** APROVADO.

**Conclusão:** o teste demonstrou que a alteração do limite de vagas aguardou o bloqueio mantido pela transação de inscrição. Após a liberação, a trigger permitiu uma redução válida e rejeitou uma redução inferior à quantidade de participantes confirmados.

A operação que atingiu o timeout foi repetida após o `COMMIT`, não permanecendo em espera contínua.

**Limpeza:** a inscrição temporária e a sessão 26 foram removidas após a verificação.

### Testes complementares realizados

**1. Reativação conflitante de sessão cancelada**

Foi testada a tentativa de reativar uma sessão cancelada quando outra sessão ativa ocupava o mesmo espaço e horário.

**Resultado:** TESTE APROVADO — reativação conflitante bloqueada.

**2. Cancelamento de inscrição na lista de espera**

Foi cancelada uma inscrição que estava na lista de espera, verificando que nenhuma outra inscrição fosse promovida indevidamente e que a inscrição confirmada permanecesse inalterada.

**Resultado:** TESTE APROVADO — cancelamento na espera sem promoção indevida.

**3. Inscrição direta em sessão sem inscrição geral na edição**

Foi criada uma inscrição diretamente em uma sessão sem registro prévio na tabela `inscricao_edicao`.

**Resultado:** TESTE APROVADO — inscrição em sessão sem inscrição na edição.

**4. Transferência de inscrição por UPDATE**

Inicialmente, o teste identificou que a alteração de `id_sessao` poderia ultrapassar o limite de vagas.

Após a correção da trigger, a transferência foi rejeitada.

**Resultado após correção:** TESTE APROVADO — transferência de sessão bloqueada.

Todos esses testes utilizaram transações com `ROLLBACK` para evitar a permanência de dados temporários.

### Testes ainda pendentes

As verificações originais de 01 a 18 e os três cenários de concorrência executados apresentaram os resultados esperados.

O teste 19 foi acrescentado ao arquivo de testes, mas sua execução integral ainda precisa ser confirmada.

Também permanece pendente uma avaliação específica para reproduzir ou descartar possíveis deadlocks entre operações concorrentes.

---

## 9. Decisões e limitações

- A capacidade física do espaço é sempre considerada no cálculo das vagas.
- O limite da sessão pode ser NULL, indicando ausência de limite próprio, mas não capacidade física ilimitada.
- A lista de espera utiliza posições positivas e únicas por sessão.
- A transferência de uma inscrição para outra pessoa ou sessão por UPDATE não é suportada; a trigger atualizada bloqueia alterações de `id_sessao` e `id_pessoa`.
- A promoção automática ocorre em cancelamentos por UPDATE. Exclusões físicas por DELETE não acionam essa regra.
- A reativação de sessões canceladas é submetida à verificação de conflitos de horário.
- A redução de capacidade é protegida pelas duas triggers adicionais.
- Os mecanismos de bloqueio precisam ser considerados em operações concorrentes para evitar esperas excessivas e possíveis deadlocks.

### Análise de possíveis deadlocks

As funções utilizam bloqueios de linhas para coordenar operações concorrentes. O controle de inscrições bloqueia a sessão, enquanto a verificação de conflitos de horários bloqueia o espaço.

Em operações que envolvem múltiplas tabelas, diferentes ordens de aquisição de bloqueios podem gerar situações de espera circular entre transações.

Os testes realizados confirmaram a existência dos bloqueios e os comportamentos esperados após a liberação das transações. Entretanto, não foi executado um teste específico que comprovasse ou descartasse a ocorrência de deadlocks.

**Limitação conhecida:** recomenda-se padronizar a ordem de aquisição dos bloqueios nas operações que envolvem sessões, espaços e inscrições, além de prever o tratamento de erros de deadlock (`SQLSTATE 40P01`) pela aplicação.

**Conclusão:** o risco foi identificado por análise do código, mas sua ocorrência prática não foi demonstrada nos testes realizados.

### Outras limitações conhecidas

- A trigger de controle de vagas também é acionada por atualizações que modifiquem exclusivamente `id_pessoa` ou `id_sessao`, bloqueando essas transferências.
- A promoção da lista de espera ocorre somente após o cancelamento de uma inscrição confirmada por meio de UPDATE do status.
- Exclusões físicas de inscrições não acionam a promoção automática.
- A implementação atual não realiza uma promoção automática apenas pelo aumento do limite de vagas.
- Os testes de concorrência executados não substituem uma avaliação completa de todas as possíveis interações simultâneas entre as tabelas.

---

## 10. Conclusão

As seis funções de trigger implementam controles de integridade para o gerenciamento de sessões, inscrições, lista de espera, histórico e capacidade.

As verificações originais de 01 a 18 e os três cenários de concorrência apresentaram os resultados esperados, conforme os procedimentos registrados.

A revisão do código também identificou limitações conhecidas e um possível risco de deadlock relacionado à ordem dos bloqueios, documentados para consideração na integração com o restante do sistema.

Os testes manuais adicionais confirmaram a rejeição de reativação conflitante, o cancelamento na lista de espera sem promoção indevida, a inscrição direta em sessão sem inscrição prévia na edição e o bloqueio de transferência de sessão após a correção.

O teste 19 automatiza a verificação das duas chaves de inscrição e ainda deve ser executado integralmente.

**Arquivos relacionados:**

- `sql/01_tabelas.sql` — estrutura das tabelas.
- `sql/02_triggers.sql` — implementação das funções e triggers.
- `tests/test_triggers.sql` — testes funcionais.
