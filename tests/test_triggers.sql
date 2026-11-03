
-- ============================================================
-- SCC0640 - TESTES DAS TRIGGERS
-- Sistema de Gestao de Eventos e Espacos
--
-- Executar em banco de testes com:
--   01_tabelas.sql
--   02_triggers.sql
--
-- Os testes de comportamento usam dados temporarios.
-- ROLLBACK desfaz as alteracoes ao final.
-- ============================================================


-- TESTE 01: verificar as triggers instaladas

SELECT
    event_object_table AS tabela,
    trigger_name AS nome_trigger,
    action_timing AS momento,
    event_manipulation AS operacao
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name IN (
      'trg_controlar_vagas_sessao',
      'trg_promover_lista_espera',
      'trg_registrar_historico_sessao',
      'trg_verificar_conflito_sessao'
  )
ORDER BY tabela, nome_trigger, operacao;


-- ============================================================
-- TESTES 02 A 16: comportamento das triggers
-- ============================================================

BEGIN;

DO $testes$
DECLARE
    v_evento INTEGER;
    v_edicao INTEGER;
    v_atividade INTEGER;
    v_espaco INTEGER;
    v_outro_espaco INTEGER;

    v_sessao INTEGER;
    v_outra_sessao INTEGER;
    v_sessao_vagas INTEGER;

    v_pessoa1 INTEGER;
    v_pessoa2 INTEGER;
    v_pessoa3 INTEGER;

    v_status VARCHAR;
    v_posicao INTEGER;
    v_total INTEGER;
    v_historico_antes INTEGER;
    v_rejeitou BOOLEAN;
    v_sufixo TEXT := txid_current()::TEXT;
BEGIN

    -- Preparacao dos dados de teste

    INSERT INTO evento (nome)
    VALUES ('Evento de teste das triggers')
    RETURNING id_evento INTO v_evento;

    INSERT INTO edicao (
        id_evento, ano, data_inicio, data_fim,
        cidade, status
    )
    VALUES (
        v_evento, 2026,
        DATE '2026-12-10',
        DATE '2026-12-12',
        'Ribeirao Preto', 'PLANEJADA'
    )
    RETURNING id_edicao INTO v_edicao;

    INSERT INTO atividade (
        id_edicao, titulo, tipo
    )
    VALUES (
        v_edicao, 'Atividade de teste', 'PALESTRA'
    )
    RETURNING id_atividade INTO v_atividade;

    INSERT INTO espaco (
        nome, tipo, capacidade
    )
    VALUES (
        'Sala teste A ' || v_sufixo, 'SALA', 30
    )
    RETURNING id_espaco INTO v_espaco;

    INSERT INTO espaco (
        nome, tipo, capacidade
    )
    VALUES (
        'Sala teste B ' || v_sufixo, 'SALA', 30
    )
    RETURNING id_espaco INTO v_outro_espaco;

    INSERT INTO pessoa (nome, email)
    VALUES (
        'Pessoa Teste 1',
        'trigger1_' || v_sufixo || '@teste.local'
    )
    RETURNING id_pessoa INTO v_pessoa1;

    INSERT INTO pessoa (nome, email)
    VALUES (
        'Pessoa Teste 2',
        'trigger2_' || v_sufixo || '@teste.local'
    )
    RETURNING id_pessoa INTO v_pessoa2;

    INSERT INTO pessoa (nome, email)
    VALUES (
        'Pessoa Teste 3',
        'trigger3_' || v_sufixo || '@teste.local'
    )
    RETURNING id_pessoa INTO v_pessoa3;


    -- TESTE 02: criar sessao sem conflito

    INSERT INTO sessao (
        id_atividade, id_espaco, data,
        hora_inicio, hora_fim, status
    )
    VALUES (
        v_atividade, v_espaco,
        DATE '2026-12-10',
        TIME '09:00', TIME '10:00',
        'AGENDADA'
    )
    RETURNING id_sessao INTO v_sessao;

    RAISE NOTICE
        'TESTE 02 APROVADO: sessao criada sem conflito';


    -- TESTE 03: impedir sobreposicao parcial

    v_rejeitou := FALSE;

    BEGIN
        INSERT INTO sessao (
            id_atividade, id_espaco, data,
            hora_inicio, hora_fim, status
        )
        VALUES (
            v_atividade, v_espaco,
            DATE '2026-12-10',
            TIME '09:30', TIME '10:30',
            'AGENDADA'
        );

    EXCEPTION WHEN raise_exception THEN
        v_rejeitou := TRUE;
    END;

    IF NOT v_rejeitou THEN
        RAISE EXCEPTION
            'TESTE 03 FALHOU: sobreposicao permitida';
    END IF;

    RAISE NOTICE
        'TESTE 03 APROVADO: sobreposicao bloqueada';


    -- TESTE 04: impedir sobreposicao total

    v_rejeitou := FALSE;

    BEGIN
        INSERT INTO sessao (
            id_atividade, id_espaco, data,
            hora_inicio, hora_fim, status
        )
        VALUES (
            v_atividade, v_espaco,
            DATE '2026-12-10',
            TIME '08:00', TIME '11:00',
            'AGENDADA'
        );

    EXCEPTION WHEN raise_exception THEN
        v_rejeitou := TRUE;
    END;

    IF NOT v_rejeitou THEN
        RAISE EXCEPTION
            'TESTE 04 FALHOU: sobreposicao total permitida';
    END IF;

    RAISE NOTICE
        'TESTE 04 APROVADO: sobreposicao total bloqueada';


    -- TESTE 05: permitir horarios consecutivos

    INSERT INTO sessao (
        id_atividade, id_espaco, data,
        hora_inicio, hora_fim, status
    )
    VALUES (
        v_atividade, v_espaco,
        DATE '2026-12-10',
        TIME '10:00', TIME '11:00',
        'AGENDADA'
    )
    RETURNING id_sessao INTO v_outra_sessao;

    RAISE NOTICE
        'TESTE 05 APROVADO: horarios consecutivos permitidos';


    -- TESTE 06: permitir mesma hora em outra sala

    INSERT INTO sessao (
        id_atividade, id_espaco, data,
        hora_inicio, hora_fim, status
    )
    VALUES (
        v_atividade, v_outro_espaco,
        DATE '2026-12-10',
        TIME '09:00', TIME '10:00',
        'AGENDADA'
    );

    RAISE NOTICE
        'TESTE 06 APROVADO: outra sala permitida';


    -- TESTE 07: permitir mesma sala em outra data

    INSERT INTO sessao (
        id_atividade, id_espaco, data,
        hora_inicio, hora_fim, status
    )
    VALUES (
        v_atividade, v_espaco,
        DATE '2026-12-11',
        TIME '09:00', TIME '10:00',
        'AGENDADA'
    );

    RAISE NOTICE
        'TESTE 07 APROVADO: outra data permitida';


    -- TESTE 08: impedir conflito em UPDATE

    v_rejeitou := FALSE;

    BEGIN
        UPDATE sessao
        SET hora_inicio = TIME '09:30'
        WHERE id_sessao = v_outra_sessao;

    EXCEPTION WHEN raise_exception THEN
        v_rejeitou := TRUE;
    END;

    IF NOT v_rejeitou THEN
        RAISE EXCEPTION
            'TESTE 08 FALHOU: UPDATE conflitante permitido';
    END IF;

    RAISE NOTICE
        'TESTE 08 APROVADO: UPDATE conflitante bloqueado';


    -- TESTE 09: UPDATE sem mudanca de horario

    UPDATE sessao
    SET hora_inicio = hora_inicio
    WHERE id_sessao = v_sessao;

    RAISE NOTICE
        'TESTE 09 APROVADO: UPDATE sem mudanca permitido';


    -- TESTE 10: registrar historico de mudanca

    SELECT COUNT(*)
    INTO v_historico_antes
    FROM historico_sessao
    WHERE id_sessao = v_sessao;

    UPDATE sessao
    SET hora_inicio = TIME '11:00',
        hora_fim = TIME '12:00'
    WHERE id_sessao = v_sessao;

    SELECT COUNT(*)
    INTO v_total
    FROM historico_sessao
    WHERE id_sessao = v_sessao
      AND data_anterior = DATE '2026-12-10'
      AND hora_inicio_anterior = TIME '09:00'
      AND hora_fim_anterior = TIME '10:00'
      AND espaco_anterior = v_espaco::VARCHAR;

    IF v_total <> 1 THEN
        RAISE EXCEPTION
            'TESTE 10 FALHOU: historico incorreto';
    END IF;

    SELECT COUNT(*)
    INTO v_total
    FROM historico_sessao
    WHERE id_sessao = v_sessao;

    IF v_total <> v_historico_antes + 1 THEN
        RAISE EXCEPTION
            'TESTE 10 FALHOU: quantidade de historicos incorreta';
    END IF;

    RAISE NOTICE
        'TESTE 10 APROVADO: historico registrado';


    -- TESTE 11: nao registrar historico em UPDATE sem mudanca

    SELECT COUNT(*)
    INTO v_historico_antes
    FROM historico_sessao
    WHERE id_sessao = v_sessao;

    UPDATE sessao
    SET hora_inicio = hora_inicio
    WHERE id_sessao = v_sessao;

    SELECT COUNT(*)
    INTO v_total
    FROM historico_sessao
    WHERE id_sessao = v_sessao;

    IF v_total <> v_historico_antes THEN
        RAISE EXCEPTION
            'TESTE 11 FALHOU: historico indevido';
    END IF;

    RAISE NOTICE
        'TESTE 11 APROVADO: sem historico indevido';


    -- Preparar sessao com apenas uma vaga

    INSERT INTO sessao (
        id_atividade, id_espaco, data,
        hora_inicio, hora_fim,
        vagas_limite, status
    )
    VALUES (
        v_atividade, v_espaco,
        DATE '2026-12-12',
        TIME '14:00', TIME '15:00',
        1, 'AGENDADA'
    )
    RETURNING id_sessao INTO v_sessao_vagas;


    -- TESTE 12: confirmar primeira inscricao

    INSERT INTO inscricao_sessao (
        id_sessao, id_pessoa, status
    )
    VALUES (
        v_sessao_vagas, v_pessoa1, 'CONFIRMADA'
    );

    SELECT status
    INTO v_status
    FROM inscricao_sessao
    WHERE id_sessao = v_sessao_vagas
      AND id_pessoa = v_pessoa1;

    IF v_status <> 'CONFIRMADA' THEN
        RAISE EXCEPTION
            'TESTE 12 FALHOU: primeira inscricao nao confirmada';
    END IF;

    RAISE NOTICE
        'TESTE 12 APROVADO: primeira vaga confirmada';


    -- TESTE 13: colocar segunda pessoa na espera

    INSERT INTO inscricao_sessao (
        id_sessao, id_pessoa, status
    )
    VALUES (
        v_sessao_vagas, v_pessoa2, 'CONFIRMADA'
    );

    SELECT status, posicao_espera
    INTO v_status, v_posicao
    FROM inscricao_sessao
    WHERE id_sessao = v_sessao_vagas
      AND id_pessoa = v_pessoa2;

    IF v_status <> 'LISTA_ESPERA'
       OR v_posicao <> 1 THEN
        RAISE EXCEPTION
            'TESTE 13 FALHOU: lista de espera incorreta';
    END IF;

    RAISE NOTICE
        'TESTE 13 APROVADO: segunda pessoa na espera';


    -- TESTE 14: respeitar ordem da lista

    INSERT INTO inscricao_sessao (
        id_sessao, id_pessoa, status
    )
    VALUES (
        v_sessao_vagas, v_pessoa3, 'CONFIRMADA'
    );

    SELECT status, posicao_espera
    INTO v_status, v_posicao
    FROM inscricao_sessao
    WHERE id_sessao = v_sessao_vagas
      AND id_pessoa = v_pessoa3;

    IF v_status <> 'LISTA_ESPERA'
       OR v_posicao <> 2 THEN
        RAISE EXCEPTION
            'TESTE 14 FALHOU: ordem da espera incorreta';
    END IF;

    RAISE NOTICE
        'TESTE 14 APROVADO: ordem da espera correta';


    -- TESTE 15: promover pessoa apos cancelamento

    UPDATE inscricao_sessao
    SET status = 'CANCELADA'
    WHERE id_sessao = v_sessao_vagas
      AND id_pessoa = v_pessoa1;

    SELECT status, posicao_espera
    INTO v_status, v_posicao
    FROM inscricao_sessao
    WHERE id_sessao = v_sessao_vagas
      AND id_pessoa = v_pessoa2;

    IF v_status <> 'CONFIRMADA'
       OR v_posicao IS NOT NULL THEN
        RAISE EXCEPTION
            'TESTE 15 FALHOU: promocao automatica incorreta';
    END IF;

    SELECT status, posicao_espera
    INTO v_status, v_posicao
    FROM inscricao_sessao
    WHERE id_sessao = v_sessao_vagas
      AND id_pessoa = v_pessoa3;

    IF v_status <> 'LISTA_ESPERA'
       OR v_posicao <> 2 THEN
        RAISE EXCEPTION
            'TESTE 15 FALHOU: ordem restante alterada';
    END IF;

    RAISE NOTICE
        'TESTE 15 APROVADO: promocao automatica correta';


    -- TESTE 16: cancelamento repetido nao promove novamente

    UPDATE inscricao_sessao
    SET status = 'CANCELADA'
    WHERE id_sessao = v_sessao_vagas
      AND id_pessoa = v_pessoa1;

    SELECT status
    INTO v_status
    FROM inscricao_sessao
    WHERE id_sessao = v_sessao_vagas
      AND id_pessoa = v_pessoa3;

    IF v_status <> 'LISTA_ESPERA' THEN
        RAISE EXCEPTION
            'TESTE 16 FALHOU: promocao duplicada';
    END IF;

    SELECT COUNT(*)
    INTO v_total
    FROM inscricao_sessao
    WHERE id_sessao = v_sessao_vagas
      AND status = 'CONFIRMADA';

    IF v_total <> 1 THEN
        RAISE EXCEPTION
            'TESTE 16 FALHOU: numero de confirmados incorreto';
    END IF;

    RAISE NOTICE
        'TESTE 16 APROVADO: sem promocao duplicada';


    RAISE NOTICE
        'TESTES 02 A 16 CONCLUIDOS COM SUCESSO';

END;
$testes$;

ROLLBACK;

-- ============================================================
-- FIM DOS TESTES
--
-- IMPORTANTE:
-- Os testes de concorrencia precisam de duas conexoes
-- PostgreSQL e devem ser executados separadamente.
--
-- Este arquivo nao comprova sozinho:
-- - concorrencia entre duas inscricoes simultaneas;
-- - concorrencia entre agendamentos simultaneos;
-- - reducao de capacidade com inscricoes existentes;
-- - reativacao de sessao cancelada;
-- - cancelamento de pessoa na lista de espera;
-- - alteracao das chaves de uma inscricao;
-- - ausencia de inscricao previa na edicao.
--
-- Esses cenarios exigem verificacao adicional.
-- ============================================================
