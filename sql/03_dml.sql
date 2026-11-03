-- SCC0640 - Carga de dados sinteticos (executar apos 01_tabelas.sql e 02_triggers.sql).
-- Dados ficticios e deterministicos; emails example.invalid.
-- Os IDs (identity) NAO sao informados: sao gerados 1,2,3... na ordem dos INSERTs, em base nova.
-- Por isso as linhas seguintes referenciam IDs fixos (ex.: id_edicao = 2). Rodar em base vazia.
-- Lista de espera e historico sao gerados pelos triggers (INSERT/UPDATE), sem contornar regras.
BEGIN;

INSERT INTO evento (nome, descricao, area) VALUES
    ('Semana da Computacao', 'Semana academica anual com palestras, minicursos e workshops.', 'Computacao'),
    ('Simposio de Bancos de Dados', 'Simposio sobre modelagem, desempenho e gestao de dados.', 'Bancos de Dados');

INSERT INTO promotor (nome, tipo, documento) VALUES
    ('Instituto de Computacao Aplicada', 'ORGANIZACAO', 'SINT-ORG-0001'),
    ('Associacao de Estudantes de Computacao', 'ORGANIZACAO', 'SINT-ORG-0002'),
    ('TechNova Solucoes em Software', 'ORGANIZACAO', 'SINT-ORG-0003'),
    ('Helena Albuquerque Ramos', 'PESSOA', 'SINT-PES-0001'),
    ('Sociedade de Dados e Analise', 'ORGANIZACAO', 'SINT-ORG-0004');

INSERT INTO pessoa (nome, email, instituicao) VALUES
    ('Ana Beatriz Souza', 'ana.souza@example.invalid', 'Universidade Federal Exemplo'),
    ('Bruno Carvalho Dias', 'bruno.dias@example.invalid', 'Instituto Tecnologico Exemplo'),
    ('Camila Ferreira Rocha', 'camila.rocha@example.invalid', 'Universidade Federal Exemplo'),
    ('Daniel Moreira Pinto', 'daniel.pinto@example.invalid', 'Universidade Estadual Exemplo'),
    ('Elisa Nogueira Prado', 'elisa.prado@example.invalid', 'Universidade Federal Exemplo'),
    ('Fabio Henrique Teles', 'fabio.teles@example.invalid', 'Instituto Tecnologico Exemplo'),
    ('Gabriela Mendes Lopes', 'gabriela.lopes@example.invalid', 'Universidade Estadual Exemplo'),
    ('Heitor Batista Nunes', 'heitor.nunes@example.invalid', 'Universidade Federal Exemplo'),
    ('Isadora Campos Vieira', 'isadora.vieira@example.invalid', 'Universidade Estadual Exemplo'),
    ('Jorge Luiz Amaral', 'jorge.amaral@example.invalid', 'Universidade Federal Exemplo'),
    ('Karina Duarte Siqueira', 'karina.siqueira@example.invalid', NULL),
    ('Leandro Pires Cardoso', 'leandro.cardoso@example.invalid', 'TechNova Solucoes em Software'),
    ('Marina Azevedo Brandao', 'marina.brandao@example.invalid', 'Universidade Federal Exemplo'),
    ('Natalia Freitas Moraes', 'natalia.moraes@example.invalid', 'Universidade Federal Exemplo'),
    ('Otavio Ribeiro Gama', 'otavio.gama@example.invalid', 'Sociedade de Dados e Analise'),
    ('Paula Cristina Borges', 'paula.borges@example.invalid', 'Instituto Tecnologico Exemplo'),
    ('Rafael Teixeira Lacerda', 'rafael.lacerda@example.invalid', 'Universidade Federal Exemplo'),
    ('Sabrina Monteiro Leal', 'sabrina.leal@example.invalid', 'Universidade Estadual Exemplo'),
    ('Thiago Barros Esteves', 'thiago.esteves@example.invalid', NULL),
    ('Ursula Medeiros Fontes', 'ursula.fontes@example.invalid', 'Instituto Tecnologico Exemplo'),
    ('Vinicius Arantes Maia', 'vinicius.maia@example.invalid', 'Universidade Estadual Exemplo'),
    ('Wellington Salles Cunha', 'wellington.cunha@example.invalid', 'Universidade Federal Exemplo'),
    ('Yasmin Cordeiro Paiva', 'yasmin.paiva@example.invalid', NULL),
    ('Zelia Andrade Ventura', 'zelia.ventura@example.invalid', 'Sociedade de Dados e Analise'),
    ('Alan Rezende Couto', 'alan.couto@example.invalid', 'Universidade Estadual Exemplo'),
    ('Bianca Lemos Tavares', 'bianca.tavares@example.invalid', 'Universidade Federal Exemplo'),
    ('Caio Sampaio Neves', 'caio.neves@example.invalid', NULL),
    ('Debora Quintana Reis', 'debora.reis@example.invalid', 'Instituto Tecnologico Exemplo'),
    ('Emanuel Falcao Ortiz', 'emanuel.ortiz@example.invalid', 'Universidade Estadual Exemplo'),
    ('Flavia Guimaraes Sena', 'flavia.sena@example.invalid', 'Universidade Federal Exemplo');

INSERT INTO espaco (nome, tipo, capacidade, predio) VALUES
    ('Auditorio Central', 'auditorio', 200, 'Bloco A'),
    ('Sala A', 'sala', 40, 'Bloco B'),
    ('Sala B', 'sala', 30, 'Bloco B'),
    ('Laboratorio 1', 'laboratorio', 25, 'Bloco C'),
    ('Laboratorio 2', 'laboratorio', 20, 'Bloco C'),
    ('Sala de Reunioes', 'sala', 12, 'Bloco A'),
    ('Area de Exposicao', 'area de exposicao', 150, 'Bloco A'),
    ('Sala C', 'sala', 35, 'Bloco B');

INSERT INTO recurso (nome) VALUES
    ('Projetor'),
    ('Computadores'),
    ('Sistema de Audio'),
    ('Acesso a Internet'),
    ('Lousa Digital');

INSERT INTO espaco_recurso (id_espaco, id_recurso, quantidade) VALUES
    (1, 1, 2), (1, 3, 4), (1, 4, 1),
    (2, 1, 1), (2, 4, 1), (2, 5, 1),
    (3, 1, 1), (3, 4, 1),
    (4, 1, 1), (4, 2, 25), (4, 4, 1),
    (5, 1, 1), (5, 2, 20), (5, 4, 1),
    (6, 5, 1),
    (7, 3, 2), (7, 4, 1),
    (8, 1, 1);

-- Mesmo evento (Semana da Computacao) em dois anos; segundo evento com uma edicao.
INSERT INTO edicao (id_evento, ano, data_inicio, data_fim, cidade, status) VALUES
    (1, 2025, '2025-05-12', '2025-05-16', 'Sao Carlos', 'ENCERRADA'),
    (1, 2026, '2026-11-16', '2026-11-20', 'Sao Carlos', 'PLANEJADA'),
    (2, 2026, '2026-12-02', '2026-12-04', 'Sao Paulo', 'PLANEJADA');

-- Edicao 2026 da Semana com promocao conjunta (tres promotores).
INSERT INTO edicao_promotor (id_edicao, id_promotor, papel) VALUES
    (1, 1, 'principal'),
    (2, 1, 'principal'), (2, 2, 'co-promotor'), (2, 3, 'co-promotor'),
    (3, 5, 'principal'), (3, 4, 'co-promotor');

INSERT INTO atividade (id_edicao, titulo, descricao, tipo, carga_horaria) VALUES
    (1, 'Workshop de PostgreSQL', 'Modelagem e consultas em PostgreSQL.', 'workshop', 3),
    (1, 'Palestra de Abertura: O Futuro da Computacao', 'Abertura da Semana 2025.', 'palestra', 1),
    (1, 'Minicurso de Python para Dados', 'Analise de dados com Python.', 'minicurso', 4),
    (1, 'Mesa-redonda: Carreira em Tecnologia', 'Trajetorias profissionais em computacao.', 'mesa-redonda', 2),
    (1, 'Painel de Seguranca da Informacao', 'Boas praticas de seguranca.', 'painel', 2),
    (2, 'Workshop de PostgreSQL', 'Modelagem e consultas em PostgreSQL.', 'workshop', 3),
    (2, 'Palestra de Abertura: IA Generativa na Pratica', 'Abertura da Semana 2026.', 'palestra', 1),
    (2, 'Minicurso de Git e GitHub', 'Controle de versao e colaboracao.', 'minicurso', 4),
    (2, 'Mesa-redonda: Mulheres na Computacao', 'Experiencias e oportunidades na area.', 'mesa-redonda', 2),
    (2, 'Painel: Seguranca e Privacidade de Dados', 'Tendencias em protecao de dados.', 'painel', 2),
    (2, 'Apresentacao de Projetos Estudantis', 'Exposicao de projetos de alunos.', 'apresentacao', 3),
    (2, 'Workshop de Docker para Desenvolvedores', 'Conteineres no desenvolvimento de software.', 'workshop', 3),
    (3, 'Palestra: Bancos de Dados Distribuidos', 'Abertura do Simposio.', 'palestra', 1),
    (3, 'Minicurso de Modelagem Relacional', 'Do modelo E/R ao esquema relacional.', 'minicurso', 4),
    (3, 'Workshop de Otimizacao de Consultas', 'Planos de execucao e indices.', 'workshop', 3),
    (3, 'Painel: Futuro dos SGBDs', 'Debate sobre o futuro dos gerenciadores de bancos.', 'painel', 2);

INSERT INTO atividade_recurso (id_atividade, id_recurso, quantidade_minima) VALUES
    (1, 2, 15), (1, 4, 1),
    (2, 1, 1),
    (3, 2, 15),
    (6, 2, 15), (6, 4, 1),
    (7, 1, 1), (7, 3, 1),
    (8, 1, 1), (8, 4, 1),
    (9, 1, 1),
    (10, 1, 1),
    (11, 3, 1),
    (12, 2, 15),
    (13, 1, 1),
    (14, 2, 15),
    (15, 2, 15);

-- Papeis na programacao: uma pessoa pode ministrar em mais de uma atividade.
INSERT INTO atividade_pessoa (id_atividade, id_pessoa, papel) VALUES
    (1, 10, 'instrutor'),
    (2, 5, 'palestrante'),
    (3, 2, 'instrutor'),
    (4, 6, 'mediador'), (4, 9, 'palestrante'), (4, 5, 'palestrante'),
    (5, 12, 'palestrante'),
    (6, 3, 'instrutor'),
    (7, 5, 'palestrante'),
    (8, 2, 'instrutor'),
    (9, 7, 'mediador'), (9, 9, 'palestrante'), (9, 5, 'palestrante'),
    (10, 12, 'palestrante'), (10, 8, 'palestrante'),
    (11, 10, 'mediador'),
    (12, 2, 'instrutor'),
    (13, 15, 'palestrante'),
    (14, 3, 'instrutor'),
    (15, 2, 'instrutor'),
    (16, 6, 'mediador'), (16, 15, 'palestrante'), (16, 12, 'palestrante');

-- Sessoes cadastradas sem duracao_min (coluna gerada). Sem conflitos de espaco/horario.
INSERT INTO sessao (id_atividade, id_espaco, data, hora_inicio, hora_fim, vagas_limite, status) VALUES
    (2, 1, '2025-05-12', '09:00', '10:00', NULL, 'REALIZADA'),
    (1, 4, '2025-05-13', '09:00', '12:00', 20, 'REALIZADA'),
    (1, 4, '2025-05-13', '14:00', '17:00', 20, 'REALIZADA'),
    (3, 5, '2025-05-14', '09:00', '13:00', 20, 'REALIZADA'),
    (4, 2, '2025-05-14', '14:00', '16:00', NULL, 'REALIZADA'),
    (5, 3, '2025-05-15', '10:00', '12:00', NULL, 'CANCELADA'),
    (7, 1, '2026-11-16', '09:00', '10:00', NULL, 'AGENDADA'),
    (6, 4, '2026-11-17', '09:00', '12:00', 6, 'AGENDADA'),
    (6, 5, '2026-11-17', '14:00', '17:00', 4, 'AGENDADA'),
    (8, 2, '2026-11-18', '09:00', '13:00', NULL, 'AGENDADA'),
    (8, 2, '2026-11-18', '14:00', '18:00', 30, 'AGENDADA'),
    (9, 3, '2026-11-18', '14:00', '16:00', NULL, 'AGENDADA'),
    (10, 1, '2026-11-19', '10:00', '12:00', NULL, 'AGENDADA'),
    (11, 7, '2026-11-19', '14:00', '17:00', NULL, 'AGENDADA'),
    (12, 4, '2026-11-20', '09:00', '12:00', 30, 'AGENDADA'),
    (13, 1, '2026-12-02', '09:00', '10:00', NULL, 'AGENDADA'),
    (14, 4, '2026-12-02', '14:00', '18:00', 15, 'AGENDADA'),
    (15, 5, '2026-12-03', '09:00', '12:00', 3, 'AGENDADA'),
    (16, 1, '2026-12-03', '14:00', '16:00', NULL, 'AGENDADA');

INSERT INTO equipe_edicao (id_pessoa, id_edicao, papel) VALUES
    (10, 1, 'organizador'), (14, 1, 'voluntario'),
    (3, 2, 'organizador'), (10, 2, 'organizador'), (14, 2, 'voluntario'), (17, 2, 'voluntario'),
    (24, 3, 'organizador'), (29, 3, 'voluntario');

-- Inscricoes gerais (independentes das inscricoes em sessoes, conforme Q5).
INSERT INTO inscricao_edicao (id_pessoa, id_edicao, data_inscricao, status) VALUES
    (1, 1, '2025-04-02 10:00:00', 'CONFIRMADA'),
    (2, 1, '2025-04-02 11:30:00', 'CONFIRMADA'),
    (3, 1, '2025-04-03 09:15:00', 'CONFIRMADA'),
    (4, 1, '2025-04-03 14:40:00', 'CONFIRMADA'),
    (6, 1, '2025-04-04 08:20:00', 'CONFIRMADA'),
    (7, 1, '2025-04-04 16:05:00', 'CONFIRMADA'),
    (8, 1, '2025-04-05 10:10:00', 'CONFIRMADA'),
    (9, 1, '2025-04-06 13:25:00', 'CONFIRMADA'),
    (11, 1, '2025-04-07 09:00:00', 'CONFIRMADA'),
    (12, 1, '2025-04-07 17:45:00', 'CONFIRMADA'),
    (13, 1, '2025-04-08 12:00:00', 'CANCELADA'),
    (1, 2, '2026-09-01 09:00:00', 'CONFIRMADA'),
    (2, 2, '2026-09-01 10:20:00', 'CONFIRMADA'),
    (3, 2, '2026-09-02 08:45:00', 'CONFIRMADA'),
    (4, 2, '2026-09-02 15:10:00', 'CONFIRMADA'),
    (5, 2, '2026-09-03 11:00:00', 'CONFIRMADA'),
    (7, 2, '2026-09-03 16:30:00', 'CONFIRMADA'),
    (8, 2, '2026-09-04 09:40:00', 'CANCELADA'),
    (9, 2, '2026-09-04 13:15:00', 'CONFIRMADA'),
    (11, 2, '2026-09-05 10:05:00', 'CONFIRMADA'),
    (12, 2, '2026-09-05 14:50:00', 'CONFIRMADA'),
    (13, 2, '2026-09-06 08:30:00', 'CONFIRMADA'),
    (14, 2, '2026-09-06 12:10:00', 'CONFIRMADA'),
    (15, 2, '2026-09-07 09:25:00', 'CONFIRMADA'),
    (16, 2, '2026-09-07 17:00:00', 'CONFIRMADA'),
    (17, 2, '2026-09-08 10:35:00', 'CONFIRMADA'),
    (18, 2, '2026-09-08 15:55:00', 'CONFIRMADA'),
    (2, 3, '2026-10-01 09:00:00', 'CONFIRMADA'),
    (15, 3, '2026-10-01 11:20:00', 'CONFIRMADA'),
    (21, 3, '2026-10-02 10:00:00', 'CONFIRMADA'),
    (22, 3, '2026-10-02 14:30:00', 'CONFIRMADA'),
    (24, 3, '2026-10-03 09:10:00', 'CONFIRMADA'),
    (25, 3, '2026-10-03 16:45:00', 'CONFIRMADA'),
    (26, 3, '2026-10-04 08:50:00', 'CONFIRMADA');

-- Inscricoes em sessoes: status e posicao de espera sao decididos pelo trigger de vagas.
-- Edicao 2025 (sessoes realizadas).
INSERT INTO inscricao_sessao (id_sessao, id_pessoa, data_inscricao) VALUES
    (2, 1, '2025-04-20 09:00:00'), (2, 2, '2025-04-20 09:30:00'), (2, 4, '2025-04-20 10:00:00'),
    (3, 3, '2025-04-20 10:30:00'), (3, 6, '2025-04-20 11:00:00'), (3, 7, '2025-04-20 11:30:00'),
    (4, 8, '2025-04-21 09:00:00'), (4, 9, '2025-04-21 09:30:00'), (4, 1, '2025-04-21 10:00:00');

-- Sessao 8: lotada (6 vagas) com duas pessoas na espera (11 e 12).
INSERT INTO inscricao_sessao (id_sessao, id_pessoa, data_inscricao) VALUES
    (8, 1, '2026-10-05 09:00:00'), (8, 4, '2026-10-05 09:10:00'), (8, 5, '2026-10-05 09:20:00'),
    (8, 7, '2026-10-05 09:30:00'), (8, 9, '2026-10-05 09:40:00'), (8, 13, '2026-10-05 09:50:00'),
    (8, 11, '2026-10-05 10:00:00'), (8, 12, '2026-10-05 10:10:00');

-- Sessao 9: lotada (4 vagas) com espera (18 e 19); 19 nao possui inscricao na edicao (Q5).
INSERT INTO inscricao_sessao (id_sessao, id_pessoa, data_inscricao) VALUES
    (9, 14, '2026-10-06 09:00:00'), (9, 15, '2026-10-06 09:10:00'), (9, 16, '2026-10-06 09:20:00'),
    (9, 17, '2026-10-06 09:30:00'), (9, 18, '2026-10-06 09:40:00'), (9, 19, '2026-10-06 09:50:00');

-- Sessoes parcialmente ocupadas.
INSERT INTO inscricao_sessao (id_sessao, id_pessoa, data_inscricao) VALUES
    (10, 1, '2026-10-07 09:00:00'), (10, 4, '2026-10-07 09:10:00'), (10, 7, '2026-10-07 09:20:00'),
    (10, 9, '2026-10-07 09:30:00'), (10, 11, '2026-10-07 09:40:00'),
    (11, 13, '2026-10-07 10:00:00'), (11, 14, '2026-10-07 10:10:00'),
    (15, 16, '2026-10-08 09:00:00'), (15, 17, '2026-10-08 09:10:00'), (15, 18, '2026-10-08 09:20:00');

-- Simposio: sessao 18 lotada (3 vagas) com espera (23); 20 e 23 sem inscricao na edicao (Q5).
INSERT INTO inscricao_sessao (id_sessao, id_pessoa, data_inscricao) VALUES
    (17, 21, '2026-10-10 09:00:00'), (17, 22, '2026-10-10 09:10:00'),
    (18, 20, '2026-10-10 10:00:00'), (18, 21, '2026-10-10 10:10:00'),
    (18, 22, '2026-10-10 10:20:00'), (18, 23, '2026-10-10 10:30:00');

-- Cancelamento que libera vaga: o trigger promove 18 (primeira da espera na sessao 9); 19 permanece na espera.
UPDATE inscricao_sessao SET status = 'CANCELADA' WHERE id_sessao = 9 AND id_pessoa = 15;

-- Cancelamento sem fila: apenas libera a vaga.
UPDATE inscricao_sessao SET status = 'CANCELADA' WHERE id_sessao = 10 AND id_pessoa = 11;

-- Mudancas de programacao validas: o trigger grava o historico (sessao 13 duas vezes, sessao 11 uma vez).
UPDATE sessao SET hora_inicio = '14:00', hora_fim = '16:00' WHERE id_sessao = 13;
UPDATE sessao SET id_espaco = 3, data = '2026-11-20' WHERE id_sessao = 13;
UPDATE sessao SET hora_inicio = '15:00', hora_fim = '19:00' WHERE id_sessao = 11;

COMMIT;
