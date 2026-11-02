-- Executar APOS sql/01_tabelas.sql em uma base exclusiva de testes e sem dados.
-- psql -X -v ON_ERROR_STOP=1 -d <base_teste> -f tests/ddl_integridade.sql
-- Fixtures sinteticas e funcoes temporarias; nada disso e DML de entrega.
BEGIN;

CREATE TEMP TABLE resultados_ddl (teste text NOT NULL) ON COMMIT DROP;

CREATE FUNCTION pg_temp.verificar(condicao boolean, teste text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF condicao IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'FALHA: %', teste;
    END IF;
    INSERT INTO resultados_ddl VALUES (teste);
END;
$$;

CREATE FUNCTION pg_temp.esperar_erro(comando text, codigo text, teste text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    recebido text;
BEGIN
    BEGIN
        EXECUTE comando;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS recebido = RETURNED_SQLSTATE;
        IF NOT (recebido = ANY(string_to_array(codigo, ','))) THEN
            RAISE EXCEPTION 'FALHA: %, esperado %, recebido %: %', teste, codigo, recebido, SQLERRM;
        END IF;
    END;
    IF recebido IS NULL THEN
        RAISE EXCEPTION 'FALHA: % nao rejeitou o comando', teste;
    END IF;
    INSERT INTO resultados_ddl VALUES (teste);
END;
$$;

SELECT pg_temp.verificar(
    (SELECT array_agg(tablename::text ORDER BY tablename) FROM pg_tables WHERE schemaname = 'public')
    = ARRAY['atividade','atividade_pessoa','atividade_recurso','edicao','edicao_promotor',
            'equipe_edicao','espaco','espaco_recurso','evento','historico_sessao',
            'inscricao_edicao','inscricao_sessao','pessoa','promotor','recurso','sessao'],
    'existem exatamente as 16 tabelas oficiais'
);
SELECT pg_temp.verificar(
    (SELECT count(*) FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND contype = 'p') = 16,
    '16 chaves primarias'
);
SELECT pg_temp.verificar(
    (SELECT count(*) FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND contype = 'f') = 19,
    '19 chaves estrangeiras'
);
SELECT pg_temp.verificar(
    NOT EXISTS (SELECT FROM pg_constraint WHERE connamespace = 'public'::regnamespace
                AND contype = 'f' AND (confdeltype <> 'r' OR confupdtype <> 'c' OR NOT convalidated)),
    'todas as FKs validadas com DELETE RESTRICT e UPDATE CASCADE'
);
SELECT pg_temp.verificar(
    NOT EXISTS (SELECT FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
                WHERE c.relnamespace = 'public'::regnamespace AND NOT t.tgisinternal),
    'nenhum trigger de negocio implementado nesta etapa'
);

INSERT INTO evento (id_evento, nome) VALUES (100, 'Evento de teste');
INSERT INTO promotor (id_promotor, nome, tipo, documento)
VALUES (100, 'Promotor de teste', 'ORGANIZACAO', 'DOC-TESTE-100');
INSERT INTO pessoa (id_pessoa, nome, email)
VALUES (100, 'Pessoa de teste', 'pessoa100@example.invalid'),
       (101, 'Pessoa de teste 2', 'pessoa101@example.invalid'),
       (102, 'Pessoa de teste 3', 'pessoa102@example.invalid');
INSERT INTO espaco (id_espaco, nome, tipo, capacidade) VALUES (100, 'Sala teste', 'sala', 30);
INSERT INTO recurso (id_recurso, nome) VALUES (100, 'Recurso teste');
INSERT INTO edicao (id_edicao, id_evento, ano, data_inicio, data_fim)
VALUES (100, 100, 2026, '2026-11-01', '2026-11-03');
INSERT INTO atividade (id_atividade, id_edicao, titulo, tipo)
VALUES (100, 100, 'Atividade teste', 'workshop');
INSERT INTO sessao (id_sessao, id_atividade, id_espaco, data, hora_inicio, hora_fim, vagas_limite)
VALUES (100, 100, 100, '2026-11-02', '09:00', '10:30', 20);
INSERT INTO historico_sessao (id_historico, id_sessao, espaco_anterior, data_anterior,
                            hora_inicio_anterior, hora_fim_anterior)
VALUES (100, 100, '100', '2026-11-01', '08:00', '09:00');
INSERT INTO edicao_promotor VALUES (100, 100, 'principal');
INSERT INTO inscricao_edicao (id_pessoa, id_edicao) VALUES (100, 100);
INSERT INTO equipe_edicao VALUES (100, 100, 'organizador');
INSERT INTO espaco_recurso VALUES (100, 100, 2);
INSERT INTO atividade_pessoa VALUES (100, 100, 'instrutor');
INSERT INTO atividade_recurso VALUES (100, 100, 1);
INSERT INTO inscricao_sessao (id_sessao, id_pessoa) VALUES (100, 100);

-- Exercita CADA FK com UPDATE orfao, DELETE e UPDATE do pai.
-- Nenhuma outra coluna da fixture e alterada para produzir um falso positivo.
DO $$
DECLARE
    fk record;
    referencia_atualizada boolean;
BEGIN
    FOR fk IN
        SELECT c.conname, c.conrelid::regclass AS filha, c.confrelid::regclass AS pai,
               a.attname AS coluna, ap.attname AS coluna_pai
        FROM pg_constraint c
        JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
        JOIN pg_attribute ap ON ap.attrelid = c.confrelid AND ap.attnum = c.confkey[1]
        WHERE c.connamespace = 'public'::regnamespace AND c.contype = 'f'
        ORDER BY c.conname
    LOOP
        -- UPDATE da FK tambem deve rejeitar orfaos.
        PERFORM pg_temp.esperar_erro(
            format('UPDATE %s SET %I = -999 WHERE %I = 100', fk.filha, fk.coluna, fk.coluna),
            '23503', fk.conname || ': UPDATE orfao rejeitado'
        );
        PERFORM pg_temp.esperar_erro(
            format('DELETE FROM %s WHERE %I = 100', fk.pai, fk.coluna_pai),
            '23503,23001', fk.conname || ': DELETE do pai referenciado rejeitado'
        );
        EXECUTE format('UPDATE %s SET %I = 200 WHERE %I = 100', fk.pai, fk.coluna_pai, fk.coluna_pai);
        EXECUTE format('SELECT EXISTS (SELECT FROM %s WHERE %I = 200) AND NOT EXISTS (SELECT FROM %s WHERE %I = 100)',
                       fk.filha, fk.coluna, fk.filha, fk.coluna)
            INTO STRICT referencia_atualizada;
        PERFORM pg_temp.verificar(referencia_atualizada, fk.conname || ': UPDATE CASCADE preserva a referencia');
        EXECUTE format('UPDATE %s SET %I = 100 WHERE %I = 200', fk.pai, fk.coluna_pai, fk.coluna_pai);
    END LOOP;
END;
$$;

-- Cada uma das 16 PKs deve rejeitar a duplicacao de uma fixture completa.
DO $$
DECLARE
    tabela record;
    colunas text;
BEGIN
    FOR tabela IN SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename LOOP
        SELECT string_agg(format('%I',attname), ', ' ORDER BY attnum) INTO colunas
        FROM pg_attribute WHERE attrelid=format('public.%I',tabela.tablename)::regclass
            AND attnum>0 AND NOT attisdropped AND attgenerated='';
        PERFORM pg_temp.esperar_erro(
            format('INSERT INTO public.%I (%s) SELECT %s FROM public.%I LIMIT 1',
                   tabela.tablename,colunas,colunas,tabela.tablename),
            '23505', tabela.tablename || ': PK rejeita linha duplicada'
        );
    END LOOP;
END;
$$;

SELECT pg_temp.esperar_erro('UPDATE evento SET nome = NULL WHERE id_evento = 100', '23502', 'NOT NULL obrigatorio');
SELECT pg_temp.esperar_erro('UPDATE evento SET nome = ''  '' WHERE id_evento = 100', '23514', 'nome vazio rejeitado');
SELECT pg_temp.esperar_erro('UPDATE promotor SET tipo = ''EMPRESA'' WHERE id_promotor = 100', '23514', 'tipo de promotor invalido');
SELECT pg_temp.esperar_erro('UPDATE espaco SET capacidade = 0 WHERE id_espaco = 100', '23514', 'capacidade zero');
SELECT pg_temp.esperar_erro('UPDATE espaco SET capacidade = -1 WHERE id_espaco = 100', '23514', 'capacidade negativa');
SELECT pg_temp.esperar_erro('UPDATE edicao SET ano = 0 WHERE id_edicao = 100', '23514', 'ano invalido');
SELECT pg_temp.esperar_erro('UPDATE edicao SET data_fim = ''2026-10-01'' WHERE id_edicao = 100', '23514', 'periodo invertido');
SELECT pg_temp.esperar_erro('UPDATE edicao SET data_fim = ''infinity'' WHERE id_edicao = 100', '23514', 'data infinita');
SELECT pg_temp.esperar_erro('UPDATE edicao SET data_inicio = ''2026-02-30'' WHERE id_edicao = 100', '22008', 'data inexistente');
SELECT pg_temp.esperar_erro('UPDATE atividade SET carga_horaria = 0 WHERE id_atividade = 100', '23514', 'carga horaria zero');
SELECT pg_temp.esperar_erro('UPDATE sessao SET hora_fim = hora_inicio WHERE id_sessao = 100', '23514', 'horario sem duracao');
SELECT pg_temp.esperar_erro('UPDATE sessao SET hora_fim = ''08:00'' WHERE id_sessao = 100', '23514', 'horario invertido');
SELECT pg_temp.esperar_erro('UPDATE sessao SET vagas_limite = 0 WHERE id_sessao = 100', '23514', 'vagas zero');
SELECT pg_temp.esperar_erro('UPDATE sessao SET vagas_limite = -1 WHERE id_sessao = 100', '23514', 'vagas negativas');
SELECT pg_temp.esperar_erro('UPDATE espaco_recurso SET quantidade = 0', '23514', 'quantidade de recurso zero');
SELECT pg_temp.esperar_erro('UPDATE atividade_recurso SET quantidade_minima = -1', '23514', 'quantidade minima negativa');
SELECT pg_temp.esperar_erro('UPDATE historico_sessao SET hora_fim_anterior = hora_inicio_anterior', '23514', 'historico com horario invalido');
SELECT pg_temp.esperar_erro('UPDATE edicao_promotor SET papel = ''outro''', '23514', 'papel promotor');
SELECT pg_temp.esperar_erro('UPDATE equipe_edicao SET papel = ''outro''', '23514', 'papel equipe');
SELECT pg_temp.esperar_erro('UPDATE atividade_pessoa SET papel = ''outro''', '23514', 'papel ministrante');
SELECT pg_temp.esperar_erro('UPDATE sessao SET status = ''OUTRO''', '23514', 'status sessao');
SELECT pg_temp.esperar_erro('UPDATE edicao SET status = ''OUTRO''', '23514', 'status edicao');
SELECT pg_temp.esperar_erro('UPDATE inscricao_edicao SET status = ''LISTA_ESPERA''', '23514', 'status inscricao edicao');
SELECT pg_temp.esperar_erro('UPDATE inscricao_sessao SET status = ''OUTRO''', '23514', 'status inscricao sessao');
SELECT pg_temp.esperar_erro('UPDATE inscricao_sessao SET status = ''LISTA_ESPERA'', posicao_espera = NULL', '23514', 'espera exige posicao');
SELECT pg_temp.esperar_erro('UPDATE inscricao_sessao SET status = ''LISTA_ESPERA'', posicao_espera = 0', '23514', 'espera exige posicao positiva');
SELECT pg_temp.esperar_erro('UPDATE inscricao_sessao SET posicao_espera = 1', '23514', 'confirmada nao pode ter posicao');
SELECT pg_temp.esperar_erro('UPDATE inscricao_sessao SET status = ''CANCELADA'', posicao_espera = 1', '23514', 'cancelada nao pode ter posicao');
SELECT pg_temp.esperar_erro('INSERT INTO edicao (id_evento, ano, data_inicio, data_fim) VALUES (100,2026,''2026-11-01'',''2026-11-03'')', '23505', 'UNIQUE evento ano');
SELECT pg_temp.esperar_erro('INSERT INTO pessoa (nome,email) VALUES (''Outra'',''pessoa100@example.invalid'')', '23505', 'UNIQUE email');
SELECT pg_temp.esperar_erro('INSERT INTO promotor (nome,tipo,documento) VALUES (''Outro'',''PESSOA'',''DOC-TESTE-100'')', '23505', 'UNIQUE documento');
SELECT pg_temp.esperar_erro('INSERT INTO recurso (nome) VALUES (''Recurso teste'')', '23505', 'UNIQUE recurso');
SELECT pg_temp.esperar_erro('INSERT INTO atividade_pessoa VALUES (100,100,''palestrante'')', '23505', 'PK associativa impede duplicacao');
SELECT pg_temp.esperar_erro('UPDATE sessao SET duracao_min = 1 WHERE id_sessao = 100', '428C9', 'duracao nao e editavel');
SELECT pg_temp.verificar((SELECT duracao_min = 90 FROM sessao WHERE id_sessao=100), 'duracao gerada no INSERT');
UPDATE sessao SET hora_fim = '11:00:30' WHERE id_sessao = 100;
SELECT pg_temp.verificar((SELECT duracao_min = 120 FROM sessao WHERE id_sessao=100), 'duracao recalculada em minutos completos no UPDATE');
UPDATE sessao SET vagas_limite = NULL WHERE id_sessao = 100;
SELECT pg_temp.verificar((SELECT vagas_limite IS NULL FROM sessao WHERE id_sessao=100), 'limite proprio opcional');
UPDATE sessao SET vagas_limite = 50 WHERE id_sessao = 100;
SELECT pg_temp.verificar((SELECT LEAST(s.vagas_limite,e.capacidade) = 30 FROM sessao s JOIN espaco e USING(id_espaco)), 'vagas efetivas usam menor limite');
SELECT pg_temp.verificar((SELECT status = 'PLANEJADA' FROM edicao WHERE id_edicao=100), 'default edicao');
SELECT pg_temp.verificar((SELECT status = 'AGENDADA' FROM sessao WHERE id_sessao=100), 'default sessao');
SELECT pg_temp.verificar((SELECT status = 'CONFIRMADA' AND data_inscricao IS NOT NULL FROM inscricao_edicao WHERE id_pessoa=100), 'default inscricao');
SELECT pg_temp.verificar((SELECT count(*)=1 FROM equipe_edicao e JOIN atividade_pessoa a USING(id_pessoa) JOIN inscricao_edicao i USING(id_pessoa)), 'Q2 acumula participante organizador e instrutor');

INSERT INTO inscricao_sessao (id_sessao,id_pessoa,status,posicao_espera)
VALUES (100,101,'LISTA_ESPERA',1),(100,102,'LISTA_ESPERA',2);
SELECT pg_temp.verificar(NOT EXISTS(SELECT FROM inscricao_edicao WHERE id_pessoa=101), 'Q5 inscricao em sessao independente da edicao');
SELECT pg_temp.esperar_erro('UPDATE inscricao_sessao SET posicao_espera=1 WHERE id_pessoa=102', '23505', 'posicao unica por sessao');
SET CONSTRAINTS uq_inscricao_sessao_posicao DEFERRED;
UPDATE inscricao_sessao SET posicao_espera=3-posicao_espera WHERE status='LISTA_ESPERA';
SET CONSTRAINTS uq_inscricao_sessao_posicao IMMEDIATE;
SELECT pg_temp.verificar((SELECT posicao_espera=2 FROM inscricao_sessao WHERE id_pessoa=101), 'fila pode ser reordenada com UNIQUE adiada');
UPDATE inscricao_sessao SET status='CANCELADA',posicao_espera=NULL WHERE id_pessoa=101;
SELECT pg_temp.verificar((SELECT status='CANCELADA' AND posicao_espera IS NULL FROM inscricao_sessao WHERE id_pessoa=101), 'cancelamento atomico limpa posicao');

INSERT INTO evento (nome) VALUES ('Evento com identity');
SELECT pg_temp.verificar(EXISTS(SELECT FROM evento WHERE nome='Evento com identity' AND id_evento <> 100), 'identity permite omitir ID');

SELECT count(*) AS testes_aprovados FROM resultados_ddl;
SELECT teste FROM resultados_ddl ORDER BY teste;
ROLLBACK;
