-- SCC0640 - Cinco consultas finais (autocontidas, sem parametros).
-- Base: 01_tabelas + 02_triggers + 03_dml.
-- Recursos usados (todos vistos em aula): JOIN, LEFT JOIN, WHERE, GROUP BY, HAVING, ORDER BY,
-- COUNT/COUNT DISTINCT/COUNT FILTER, ROUND, UNION, EXISTS/NOT EXISTS correlacionado, IS NULL,
-- CTE (WITH) e funcao de janela RANK() OVER (PARTITION BY ... ORDER BY ...).

-- CONSULTA 1
-- OBJETIVO: Listar a programacao de cada edicao (atividade, tipo, espaco, data, horario e status da sessao) com a quantidade de mudancas de programacao registradas no historico.
-- TECNICAS: JOIN, LEFT JOIN, COUNT apos LEFT JOIN, GROUP BY, ORDER BY.
-- RESULTADO ESPERADO: 19 linhas (6 de 2025, 9 de 2026 da Semana, 4 do Simposio). Sessao 13 com 2 alteracoes, sessao 11 com 1, demais 0; sessao 6 CANCELADA.
--   COUNT(h.id_sessao) conta so valores nao nulos: sessoes sem historico aparecem com 0 (COUNT(*) daria 1).
SELECT ev.nome AS evento,
       ed.ano,
       s.data,
       s.hora_inicio,
       s.hora_fim,
       a.titulo AS atividade,
       a.tipo,
       e.nome AS espaco,
       s.status AS status_sessao,
       COUNT(h.id_sessao) AS alteracoes
  FROM sessao s
  JOIN atividade a ON a.id_atividade = s.id_atividade
  JOIN edicao ed ON ed.id_edicao = a.id_edicao
  JOIN evento ev ON ev.id_evento = ed.id_evento
  JOIN espaco e ON e.id_espaco = s.id_espaco
  LEFT JOIN historico_sessao h ON h.id_sessao = s.id_sessao
 GROUP BY ev.nome, ed.ano, ed.data_inicio, s.id_sessao, s.data, s.hora_inicio, s.hora_fim,
          a.titulo, a.tipo, e.nome, s.status
 ORDER BY ed.data_inicio, ev.nome, s.data, s.hora_inicio, s.id_sessao;

-- CONSULTA 2
-- OBJETIVO: Calcular, por sessao, as vagas efetivas, os inscritos confirmados, a fila de espera e a taxa de ocupacao.
-- TECNICAS: CTE, UNION, JOIN, LEFT JOIN, COUNT com FILTER, ROUND, GROUP BY.
-- RESULTADO ESPERADO: 19 linhas. Vaga efetiva = vagas_limite se ele for menor que a capacidade do espaco; senao, a capacidade. So CONFIRMADA e contada como ocupada.
--   LOTADAS (confirmados = vagas): sessoes 8 (6/6, 2 na espera), 9 (4/4, 1 na espera), 18 (3/3, 1 na espera).
--   PARCIAIS: sessoes 2, 3, 4 (3 de 20 = 15.0); 10 (4 de 40 = 10.0, a cancelada nao conta); 11 (2 de 30 = 6.7); 15 (3 de 25 = 12.0, limite 30 > capacidade 25); 17 (2 de 15 = 13.3).
--   SEM INSCRITOS (0.0): sessoes 1, 5, 7, 12, 13, 14, 16, 19; a sessao 6 (CANCELADA) tambem tem 0.
WITH vagas AS (
    SELECT s.id_sessao, e.capacidade AS vagas_efetivas
      FROM sessao s
      JOIN espaco e ON e.id_espaco = s.id_espaco
     WHERE s.vagas_limite IS NULL OR s.vagas_limite >= e.capacidade
    UNION
    SELECT s.id_sessao, s.vagas_limite AS vagas_efetivas
      FROM sessao s
      JOIN espaco e ON e.id_espaco = s.id_espaco
     WHERE s.vagas_limite < e.capacidade
)
SELECT ev.nome AS evento,
       ed.ano,
       a.titulo AS atividade,
       s.id_sessao,
       s.data,
       e.nome AS espaco,
       e.capacidade,
       v.vagas_efetivas,
       COUNT(i.id_pessoa) FILTER (WHERE i.status = 'CONFIRMADA') AS confirmados,
       COUNT(i.id_pessoa) FILTER (WHERE i.status = 'LISTA_ESPERA') AS em_espera,
       ROUND(100.0 * COUNT(i.id_pessoa) FILTER (WHERE i.status = 'CONFIRMADA') / v.vagas_efetivas, 1) AS ocupacao_pct,
       s.status AS status_sessao
  FROM sessao s
  JOIN vagas v ON v.id_sessao = s.id_sessao
  JOIN espaco e ON e.id_espaco = s.id_espaco
  JOIN atividade a ON a.id_atividade = s.id_atividade
  JOIN edicao ed ON ed.id_edicao = a.id_edicao
  JOIN evento ev ON ev.id_evento = ed.id_evento
  LEFT JOIN inscricao_sessao i ON i.id_sessao = s.id_sessao
 GROUP BY ev.nome, ed.ano, ed.data_inicio, a.titulo, s.id_sessao, s.data, s.hora_inicio,
          e.nome, e.capacidade, v.vagas_efetivas, s.status
 ORDER BY ed.data_inicio, ev.nome, s.data, s.hora_inicio, s.id_sessao;

-- CONSULTA 3
-- OBJETIVO: Identificar, em cada edicao, os espacos que nao foram usados por nenhuma sessao nao cancelada.
-- TECNICAS: produto cartesiano (edicao x espaco) com juncao no WHERE, NOT EXISTS correlacionado.
-- RESULTADO ESPERADO: 11 linhas. Semana 2025: Sala B (sua unica sessao foi cancelada), Sala de Reunioes, Area de Exposicao, Sala C.
--   Semana 2026: Sala de Reunioes e Sala C. Simposio 2026: Sala A, Sala B, Sala de Reunioes, Area de Exposicao, Sala C.
SELECT ev.nome AS evento,
       ed.ano,
       e.nome AS espaco_sem_uso,
       e.tipo,
       e.capacidade,
       e.predio
  FROM edicao ed, evento ev, espaco e
 WHERE ev.id_evento = ed.id_evento
   AND NOT EXISTS (
       SELECT NULL
         FROM sessao s
         JOIN atividade a ON a.id_atividade = s.id_atividade
        WHERE a.id_edicao = ed.id_edicao
          AND s.id_espaco = e.id_espaco
          AND s.status <> 'CANCELADA'
   )
 ORDER BY ed.data_inicio, ev.nome, e.id_espaco;

-- CONSULTA 4
-- OBJETIVO: Listar as pessoas com inscricao geral confirmada que tambem ministram atividades na mesma edicao, com o numero de atividades e o papel na equipe (NULL se nao fizer parte da equipe).
-- TECNICAS: JOIN, LEFT JOIN, EXISTS correlacionado, COUNT DISTINCT, GROUP BY.
-- RESULTADO ESPERADO: 12 linhas. Semana 2025: Bruno Carvalho Dias, Fabio Henrique Teles, Isadora Campos Vieira, Leandro Pires Cardoso (1 atividade cada, sem papel na equipe).
--   Semana 2026: Bruno (2 atividades), Camila Ferreira Rocha (1 atividade, organizador), Elisa Nogueira Prado (2 atividades), Gabriela Mendes Lopes, Isadora, Leandro (1 cada).
--   Simposio 2026: Bruno e Otavio Ribeiro Gama (2 atividades). Heitor (inscricao cancelada em 2026) e Jorge (sem inscricao) nao aparecem.
SELECT ev.nome AS evento,
       ed.ano,
       p.nome AS pessoa,
       COUNT(DISTINCT a.id_atividade) AS atividades,
       ee.papel AS papel_na_equipe
  FROM edicao ed
  JOIN evento ev ON ev.id_evento = ed.id_evento
  JOIN atividade a ON a.id_edicao = ed.id_edicao
  JOIN atividade_pessoa ap ON ap.id_atividade = a.id_atividade
  JOIN pessoa p ON p.id_pessoa = ap.id_pessoa
  LEFT JOIN equipe_edicao ee ON ee.id_pessoa = p.id_pessoa AND ee.id_edicao = ed.id_edicao
 WHERE EXISTS (
       SELECT NULL
         FROM inscricao_edicao ie
        WHERE ie.id_pessoa = p.id_pessoa
          AND ie.id_edicao = ed.id_edicao
          AND ie.status = 'CONFIRMADA'
   )
 GROUP BY ev.nome, ed.id_edicao, ed.ano, ed.data_inicio, p.id_pessoa, p.nome, ee.papel
 ORDER BY ed.data_inicio, ev.nome, p.nome;

-- CONSULTA 5
-- OBJETIVO: Ranquear, por edicao, os ministrantes com mais sessoes nao canceladas, mostrando as duas primeiras posicoes e preservando empates.
-- TECNICAS: CTE (duas etapas), JOIN, COUNT DISTINCT, GROUP BY, funcao de janela RANK() OVER (PARTITION BY ... ORDER BY ...).
-- RESULTADO ESPERADO: 10 linhas. Semana 2025: posicao 1 Elisa Nogueira Prado e Jorge Luiz Amaral (2 sessoes cada; a sessao cancelada nao conta).
--   Semana 2026: posicao 1 Bruno Carvalho Dias (3); posicao 2 Camila Ferreira Rocha e Elisa Nogueira Prado (2 cada).
--   Simposio 2026: posicao 1 Otavio Ribeiro Gama (2); posicao 2 Bruno, Camila, Fabio Henrique Teles e Leandro Pires Cardoso (1 cada).
WITH sessoes_por_ministrante AS (
    SELECT a.id_edicao,
           ap.id_pessoa,
           COUNT(DISTINCT s.id_sessao) AS qtd_sessoes
      FROM atividade_pessoa ap
      JOIN atividade a ON a.id_atividade = ap.id_atividade
      JOIN sessao s ON s.id_atividade = a.id_atividade
     WHERE s.status <> 'CANCELADA'
     GROUP BY a.id_edicao, ap.id_pessoa
), ranqueados AS (
    SELECT m.id_edicao,
           m.id_pessoa,
           m.qtd_sessoes,
           RANK() OVER (
               PARTITION BY m.id_edicao
               ORDER BY m.qtd_sessoes DESC
           ) AS posicao
      FROM sessoes_por_ministrante m
)
SELECT ev.nome AS evento,
       ed.ano,
       r.posicao,
       p.nome AS ministrante,
       r.qtd_sessoes
  FROM ranqueados r
  JOIN edicao ed ON ed.id_edicao = r.id_edicao
  JOIN evento ev ON ev.id_evento = ed.id_evento
  JOIN pessoa p ON p.id_pessoa = r.id_pessoa
 WHERE r.posicao <= 2
 ORDER BY ed.data_inicio, ev.nome, r.posicao, p.nome;
