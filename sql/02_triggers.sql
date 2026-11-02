CREATE OR REPLACE FUNCTION public.fn_controlar_vagas_sessao()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_limite integer;
    v_confirmados integer;
    v_proxima_posicao integer;
    v_primeiro_espera integer;
BEGIN
    -- Impede a troca da pessoa ou da sessão por UPDATE.
    IF TG_OP = 'UPDATE' THEN
        IF NEW.id_sessao <> OLD.id_sessao
           OR NEW.id_pessoa <> OLD.id_pessoa THEN
            RAISE EXCEPTION
                'Não é permitido alterar a pessoa ou sessão da inscrição.';
        END IF;
    END IF;

    -- Bloqueia a sessão para serializar as inscrições.
    PERFORM 1
    FROM sessao
    WHERE id_sessao = NEW.id_sessao
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sessão % não encontrada.', NEW.id_sessao;
    END IF;

    -- Cancelamento libera a posição da fila.
    IF NEW.status = 'CANCELADA' THEN
        NEW.posicao_espera := NULL;
        RETURN NEW;
    END IF;

    -- Preserva inscrições que não mudaram de situação.
    IF TG_OP = 'UPDATE' THEN
        IF OLD.status = 'CONFIRMADA'
           AND NEW.status = 'CONFIRMADA' THEN
            NEW.posicao_espera := NULL;
            RETURN NEW;
        END IF;

        IF OLD.status = 'LISTA_ESPERA'
           AND NEW.status = 'LISTA_ESPERA' THEN
            NEW.posicao_espera := OLD.posicao_espera;
            RETURN NEW;
        END IF;
    END IF;

    -- Calcula o limite efetivo da sessão.
    SELECT LEAST(
        COALESCE(s.vagas_limite, e.capacidade),
        e.capacidade
    )
    INTO v_limite
    FROM sessao s
    JOIN espaco e ON e.id_espaco = s.id_espaco
    WHERE s.id_sessao = NEW.id_sessao;

    -- Conta as vagas confirmadas, excluindo a própria
    -- inscrição quando se trata de uma atualização.
    SELECT COUNT(*)
    INTO v_confirmados
    FROM inscricao_sessao i
    WHERE i.id_sessao = NEW.id_sessao
      AND i.status = 'CONFIRMADA'
      AND (
          TG_OP = 'INSERT'
          OR i.id_pessoa <> NEW.id_pessoa
      );

    -- Identifica a primeira pessoa que está esperando.
    SELECT i.id_pessoa
    INTO v_primeiro_espera
    FROM inscricao_sessao i
    WHERE i.id_sessao = NEW.id_sessao
      AND i.status = 'LISTA_ESPERA'
    ORDER BY i.posicao_espera, i.data_inscricao, i.id_pessoa
    LIMIT 1;

    -- A pessoa na primeira posição tem prioridade.
    IF v_confirmados < v_limite
       AND (
           v_primeiro_espera IS NULL
           OR (
               TG_OP = 'UPDATE'
               AND NEW.id_pessoa = v_primeiro_espera
           )
       ) THEN

        NEW.status := 'CONFIRMADA';
        NEW.posicao_espera := NULL;

    ELSE
        -- Quem já está na fila mantém sua posição.
        IF TG_OP = 'UPDATE'
           AND OLD.status = 'LISTA_ESPERA' THEN
            NEW.status := 'LISTA_ESPERA';
            NEW.posicao_espera := OLD.posicao_espera;
        ELSE
            -- Novos inscritos entram no final da fila.
            SELECT COALESCE(MAX(posicao_espera), 0) + 1
            INTO v_proxima_posicao
            FROM inscricao_sessao
            WHERE id_sessao = NEW.id_sessao
              AND status = 'LISTA_ESPERA';

            NEW.status := 'LISTA_ESPERA';
            NEW.posicao_espera := v_proxima_posicao;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;



CREATE OR REPLACE FUNCTION public.fn_promover_lista_espera()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_proximo integer;
BEGIN
    -- Só promove quando uma inscrição confirmada
    -- realmente muda para cancelada.
    IF OLD.status = 'CONFIRMADA'
       AND NEW.status = 'CANCELADA' THEN

        -- Busca a primeira pessoa da fila.
        SELECT id_pessoa
        INTO v_proximo
        FROM inscricao_sessao
        WHERE id_sessao = NEW.id_sessao
          AND status = 'LISTA_ESPERA'
        ORDER BY posicao_espera, data_inscricao, id_pessoa
        LIMIT 1;

        IF v_proximo IS NOT NULL THEN
            -- A função de controle de vagas será executada
            -- também durante esta atualização.
            UPDATE inscricao_sessao
            SET status = 'CONFIRMADA',
                posicao_espera = NULL
            WHERE id_sessao = NEW.id_sessao
              AND id_pessoa = v_proximo;
        END IF;
    END IF;

    RETURN NULL;
END;
$function$;



CREATE OR REPLACE FUNCTION public.fn_registrar_historico_sessao()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Só registra quando sala, data ou horário mudarem.
    IF OLD.id_espaco IS DISTINCT FROM NEW.id_espaco
       OR OLD.data IS DISTINCT FROM NEW.data
       OR OLD.hora_inicio IS DISTINCT FROM NEW.hora_inicio
       OR OLD.hora_fim IS DISTINCT FROM NEW.hora_fim THEN

        INSERT INTO historico_sessao (
            id_sessao,
            espaco_anterior,
            data_anterior,
            hora_inicio_anterior,
            hora_fim_anterior,
            alterado_em,
            motivo
        )
        VALUES (
            OLD.id_sessao,
            OLD.id_espaco::varchar,
            OLD.data,
            OLD.hora_inicio,
            OLD.hora_fim,
            CURRENT_TIMESTAMP,
            NULL
        );
    END IF;

    RETURN NEW;
END;
$function$;



CREATE OR REPLACE FUNCTION public.fn_verificar_conflito_sessao()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Bloqueia o espaço para evitar agendamentos simultâneos
    PERFORM 1
    FROM espaco
    WHERE id_espaco = NEW.id_espaco
    FOR UPDATE;

    -- Verifica se já existe uma sessão no mesmo espaço e horário
    IF NEW.status <> 'CANCELADA' AND EXISTS (
        SELECT 1
        FROM sessao s
        WHERE s.id_espaco = NEW.id_espaco
          AND s.data = NEW.data
          AND s.id_sessao IS DISTINCT FROM NEW.id_sessao
          AND s.status <> 'CANCELADA'
          AND NEW.hora_inicio < s.hora_fim
          AND NEW.hora_fim > s.hora_inicio
    ) THEN
        RAISE EXCEPTION
            'Conflito de horário: já existe uma sessão nesse espaço.';
    END IF;

    RETURN NEW;
END;
$function$;



CREATE TRIGGER trg_controlar_vagas_sessao BEFORE INSERT OR UPDATE OF status ON inscricao_sessao FOR EACH ROW EXECUTE FUNCTION fn_controlar_vagas_sessao();


CREATE TRIGGER trg_promover_lista_espera AFTER UPDATE OF status ON inscricao_sessao FOR EACH ROW WHEN (old.status::text = 'CONFIRMADA'::text AND new.status::text = 'CANCELADA'::text) EXECUTE FUNCTION fn_promover_lista_espera();


CREATE TRIGGER trg_registrar_historico_sessao AFTER UPDATE OF id_espaco, data, hora_inicio, hora_fim ON sessao FOR EACH ROW EXECUTE FUNCTION fn_registrar_historico_sessao();


CREATE TRIGGER trg_verificar_conflito_sessao BEFORE INSERT OR UPDATE OF id_espaco, data, hora_inicio, hora_fim, status ON sessao FOR EACH ROW EXECUTE FUNCTION fn_verificar_conflito_sessao();

