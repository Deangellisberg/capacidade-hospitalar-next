-- sql/01_schema.sql
--
-- Modelo relacional — Projeto P5 (Capacidade Hospitalar)
-- STATUS: EM DESENVOLVIMENTO — primeira versão, baseada no de-para já validado
-- (de_para_p5_capacidade_hospitalar.xlsx, aba "Tabelas do Banco").
--
-- ORDEM DE CRIAÇÃO: tabelas de domínio e dimensão primeiro, tabelas de fato depois —
-- Postgres exige que a tabela referenciada por uma FK já exista no momento do CREATE.
--
-- DECISÃO RESOLVIDA EM 18/09 (validada com dado real):
-- fato_internacoes (SIH-RD) identifica o hospital por CNPJ (cgc_hosp). Confirmamos
-- que esse valor bate diretamente com o campo CPF_CNPJ, já presente no CNES-LT —
-- não precisa de fonte externa nem de tabela pendente. de_para_cnpj_cnes é populada
-- a partir do próprio CNES-LT no 02_transformacao.py.
--
-- Todos os campos-chave (cnes, cgc_hosp) são VARCHAR, não INTEGER — porque CNES-LT e
-- SIH-RD entregam tudo como texto (confirmado nos testes do pipeline); e mesmo no
-- MSHL (Hospitais e Leitos/MS), onde CNES chega como número, padronizamos para texto
-- aqui, para não perder zeros à esquerda e manter os três lados da junção compatíveis.

-- ============================================================
-- 0. LISTA DE HOSPITAIS DE GESTÃO PRÓPRIA (derivada, com origem rastreável)
-- ============================================================
-- Decisão da mentoria (17/09): nunca escrever o filtro de hospitais direto numa
-- consulta. A lista vira tabela, com uma coluna dizendo de onde cada linha veio —
-- hoje "derivada do CNES" (cruzando tipo de gestão + natureza jurídica + esfera com
-- a fonte que separa hospitais da Prefeitura do Recife), depois "oficial SERMAC"
-- quando a lista do cliente chegar. Troca de fonte vira carga nova, não reescrita.
CREATE TABLE lista_hospitais_gestao_propria (
    cnes        VARCHAR(10)  NOT NULL,
    origem      VARCHAR(30)  NOT NULL,   -- 'derivada_cnes' | 'oficial_sermac'
    data_carga  DATE         NOT NULL,
    PRIMARY KEY (cnes, origem)
);

COMMENT ON TABLE lista_hospitais_gestao_propria IS
    'Lista de hospitais de gestão própria do Recife. EM ABERTO: lógica de derivação (TP_GESTAO + NATUREZA_JURIDICA + fonte Thaís) ainda não implementada — tabela criada, carga pendente.';
-- ============================================================
-- 1. DIMENSÃO: ESTABELECIMENTO (MSHL — Hospitais e Leitos / Ministério da Saúde)
-- ============================================================
-- Sigla "MSHL" adotada pelo time (20/09) como nome curto padrão desta fonte,
-- no mesmo padrão de LT/RD — usar essa sigla em código e comentários daqui em diante.
CREATE TABLE dim_estabelecimento (
    cnes                     VARCHAR(10)  NOT NULL,
    competencia              CHAR(6)      NOT NULL,  -- formato AAAAMM
    nome_estabelecimento     VARCHAR(200),
    razao_social             VARCHAR(200),
    tp_gestao                CHAR(1),                -- M/E/D/S — NÃO é "gestão própria" da SERMAC
    co_ibge                  VARCHAR(7),
    municipio                VARCHAR(100),
    co_tipo_unidade          INTEGER,
    ds_tipo_unidade          VARCHAR(100),
    natureza_juridica        INTEGER,
    desc_natureza_juridica   VARCHAR(100),
    leitos_existentes        INTEGER,
    leitos_sus               INTEGER,
    PRIMARY KEY (cnes, competencia)
);

COMMENT ON TABLE dim_estabelecimento IS
    'Identificação do hospital (nome, gestão) — fonte MSHL, confirmada no Canvas (P1, P5). Grão: 1 hospital + 1 competência.';

-- ============================================================
-- 2. DOMÍNIO: TIPO DE LEITO (categoria ampla)
-- ============================================================
CREATE TABLE dom_tipo_leito (
    tp_leito     CHAR(2)      PRIMARY KEY,
    categoria    VARCHAR(50)  NOT NULL
);

COMMENT ON TABLE dom_tipo_leito IS
    'Domínio oficial (SCNES_DOMINIOS.XLS). Para filtrar clínico/cirúrgico (P1): tp_leito IN (1, 2). Valores confirmados sem zero à esquerda (dado real, LT_recife.parquet, 20/09).';

INSERT INTO dom_tipo_leito (tp_leito, categoria) VALUES
    ('1', 'Cirúrgico'),
    ('2', 'Clínico'),
    ('3', 'Complementar'),
    ('4', 'Obstétricos'),
    ('5', 'Pediátricos'),
    ('6', 'Outras Especialidades'),
    ('7', 'Hospital Dia');

-- ============================================================
-- 3. DOMÍNIO: CÓDIGO DE LEITO (especialidade específica)
-- ============================================================
CREATE TABLE dom_codigo_leito (
    codleito        CHAR(2)      PRIMARY KEY,
    especialidade   VARCHAR(100) NOT NULL
);

COMMENT ON TABLE dom_codigo_leito IS
    'Domínio oficial (SCNES_DOMINIOS.XLS), 66 códigos.';

INSERT INTO dom_codigo_leito (codleito, especialidade) VALUES
    ('01', 'Buco Maxilo Facial'),
    ('02', 'Cardiologia'),
    ('03', 'Cirurgia Geral'),
    ('04', 'Endocrinologia'),
    ('05', 'Gastroenterologia'),
    ('06', 'Ginecologia'),
    ('07', 'Cirúrgico/Diagnóstico/Terapêutico'),
    ('08', 'Nefrologia/Urologia'),
    ('09', 'Neurocirurgia'),
    ('10', 'Obstetricia Cirurgica'),
    ('11', 'Oftalmologia'),
    ('12', 'Oncologia'),
    ('13', 'Ortopedia/Traumatologia'),
    ('14', 'Otorrinolaringologia'),
    ('15', 'Plastica'),
    ('16', 'Toracica'),
    ('31', 'Aids'),
    ('32', 'Cardiologia'),
    ('33', 'Clinica Geral'),
    ('34', 'Cronicos'),
    ('35', 'Dermatologia'),
    ('36', 'Geriatria'),
    ('37', 'Hansenologia'),
    ('38', 'Hematologia'),
    ('40', 'Nefrourologia'),
    ('41', 'Neonatologia'),
    ('42', 'Neurologia'),
    ('43', 'Obstetricia Clinica'),
    ('44', 'Oncologia'),
    ('45', 'Pediatria Clinica'),
    ('46', 'Pneumologia'),
    ('47', 'Psiquiatria'),
    ('48', 'Reabilitacao'),
    ('49', 'Pneumologia Sanitaria'),
    ('64', 'Unidade Intermediaria'),
    ('65', 'Unidade Intermediaria Neonatal'),
    ('66', 'Unidade Isolamento'),
    ('67', 'Transplante'),
    ('68', 'Pediatria Cirurgica'),
    ('69', 'Aids'),
    ('70', 'Fibrose Cistica'),
    ('71', 'Intercorrencia Pos-Transplante'),
    ('72', 'Geriatria'),
    ('73', 'Saude Mental'),
    ('74', 'Uti Adulto - Tipo I'),
    ('75', 'Uti Adulto - Tipo Ii'),
    ('76', 'Uti Adulto - Tipo Iii'),
    ('77', 'Uti Pediatrica - Tipo I'),
    ('78', 'Uti Pediatrica - Tipo Ii'),
    ('79', 'Uti Pediatrica - Tipo Iii'),
    ('80', 'Uti Neonatal - Tipo I'),
    ('81', 'Uti Neonatal - Tipo Ii'),
    ('82', 'Uti Neonatal - Tipo Iii'),
    ('83', 'Uti De Queimados'),
    ('84', 'Acolhimento Noturno'),
    ('85', 'Uti Coronariana Tipo Ii - Uco Tipo Ii'),
    ('86', 'Uti Coronariana Tipo Iii - Uco Tipo Iii'),
    ('87', 'Saude Mental'),
    ('88', 'Queimado Adulto'),
    ('89', 'Queimado Pediatrico'),
    ('90', 'Queimado Adulto'),
    ('91', 'Queimado Pediatrico'),
    ('92', 'Unidade De Cuidados Intermediarios Neonatal Convencional'),
    ('93', 'Unidade De Cuidados Intermediarios Neonatal Canguru'),
    ('94', 'Unidade De Cuidados Intermediarios Pediatrico'),
    ('95', 'Unidade De Cuidados Intermediarios Adulto');

-- ============================================================
-- 4. FATO: LEITOS (CNES-LT)
-- ============================================================
CREATE TABLE fato_leitos (
    cnes           VARCHAR(10)  NOT NULL,
    codleito       CHAR(2)      NOT NULL,
    tp_leito       CHAR(2),                 -- 1=Cirúrgico, 2=Clínico
    competencia    CHAR(6)      NOT NULL,   -- formato AAAAMM
    qt_exist       INTEGER,
    qt_sus         INTEGER,
    PRIMARY KEY (cnes, codleito, competencia),
    FOREIGN KEY (cnes, competencia) REFERENCES dim_estabelecimento (cnes, competencia),
    FOREIGN KEY (tp_leito) REFERENCES dom_tipo_leito (tp_leito),
    FOREIGN KEY (codleito) REFERENCES dom_codigo_leito (codleito)
);

COMMENT ON TABLE fato_leitos IS
    'Quantidade de leitos por hospital, tipo de leito e competência. Base da Pergunta 1.';

-- ============================================================
-- 5. PONTE: TRADUÇÃO CNPJ (SIH-RD) <-> CNES (demais fontes)
-- ============================================================
-- RESOLVIDO em 18/09 (validado com dado real, competência 2026-06): o próprio
-- CNES-LT já traz CPF_CNPJ na mesma linha do CNES — não precisa de fonte externa.
-- 39.986 de 54.297 registros do SIH-RD bateram com algum CPF_CNPJ do CNES-LT;
-- os 14.311 restantes são exatamente os registros com CGC_HOSP vazio (defasagem
-- do SIH, já documentada — não é falha da chave).
--
-- Esta tabela é POPULADA a partir do próprio CNES-LT (CNES, CPF_CNPJ distintos),
-- no 02_transformacao.py — não depende de nenhuma fonte adicional.
--
-- FILTRAR ANTES DE CARREGAR: '00000000000000' aparece como CPF_CNPJ em pelo menos
-- um registro do CNES-LT — é placeholder de "vazio", não CNPJ real. Excluir.
CREATE TABLE de_para_cnpj_cnes (
    cpf_cnpj    VARCHAR(14)  PRIMARY KEY,
    cnes        VARCHAR(10)  NOT NULL
);

COMMENT ON TABLE de_para_cnpj_cnes IS
    'Ponte CNPJ<->CNES, extraída do próprio CNES-LT (campo CPF_CNPJ). Valida 39.986/54.297 registros do SIH-RD (18/09) — a diferença é defasagem conhecida, não falha de chave.';

-- ============================================================
-- 6. DOMÍNIO: ESPECIALIDADE (SIH)
-- ============================================================
CREATE TABLE dom_especialidade_sih (
    espec           CHAR(2)      PRIMARY KEY,
    especialidade   VARCHAR(100) NOT NULL
);

COMMENT ON TABLE dom_especialidade_sih IS
    'Reconstruído de fontes DATASUS (siab.datasus.gov.br) — não é dicionário oficial em PDF. "Ortopedia" (citada na P3) não tem código próprio; validar com dado real.';

INSERT INTO dom_especialidade_sih (espec, especialidade) VALUES
    ('01', 'Cirurgia geral'),
    ('02', 'Obstetrícia'),
    ('03', 'Clínica médica'),
    ('04', 'Crônico e FPT'),
    ('05', 'Psiquiatria'),
    ('06', 'Tisiologia'),
    ('07', 'Pediatria'),
    ('08', 'Reabilitação'),
    ('09', 'Psiquiatria - hospital/dia');

-- ============================================================
-- 7. DOMÍNIO: TIPO DE AIH
-- ============================================================
CREATE TABLE dom_tipo_aih (
    ident         CHAR(1)      PRIMARY KEY,
    significado   VARCHAR(200) NOT NULL
);

COMMENT ON TABLE dom_tipo_aih IS
    'Reconstruído do Dicionário CEM/USP. ident=5 marca longa permanência — regra de exclusão da média (P3) ainda pendente de validação formal com a SERMAC (ver docs/regra_dias_internacao_mes.md).';

INSERT INTO dom_tipo_aih (ident, significado) VALUES
    ('1', 'AIH Normal'),
    ('5', 'AIH de Longa Permanencia e FTP');

-- ============================================================
-- 8. FATO: INTERNAÇÕES (SIH-RD)
-- ============================================================
-- cgc_hosp permite NULL (achado 20/09, validado com dado real): 17.695 registros de
-- Recife (jul-dez/2024) têm CGC_HOSP vazio no arquivo original. Converter '' para NULL
-- no 02_transformacao.py, nunca descartar a internação — Postgres não exige que uma FK
-- bata quando o valor é NULL, então isso não quebra a integridade referencial. O join
-- com dim_estabelecimento deve ser LEFT JOIN (nunca INNER), preservando a internação
-- mesmo sem hospital identificado — no painel, aparece como "Hospital não identificado",
-- nunca desaparece da contagem.
CREATE TABLE fato_internacoes (
    n_aih          VARCHAR(20)  NOT NULL,
    ano_cmpt       CHAR(4)      NOT NULL,
    mes_cmpt       CHAR(2)      NOT NULL,
    cgc_hosp       VARCHAR(14),           -- NULLABLE — ver comentário acima
    espec          CHAR(2),
    ident          CHAR(1),               -- 1=Normal, 5=Longa permanência
    dt_saida       DATE,                  -- convertido de texto (AAAAMMDD) no 02_transformacao.py
    dias_perm      INTEGER,
    proc_rea       VARCHAR(10),           -- grupo 04 = procedimentos cirúrgicos (P5)
    munic_res      VARCHAR(7),
    idade          INTEGER,
    sexo           CHAR(1),
    morte          CHAR(1),
    PRIMARY KEY (n_aih, ano_cmpt, mes_cmpt),
    FOREIGN KEY (cgc_hosp) REFERENCES de_para_cnpj_cnes (cpf_cnpj),
    FOREIGN KEY (espec) REFERENCES dom_especialidade_sih (espec),
    FOREIGN KEY (ident) REFERENCES dom_tipo_aih (ident)
);

COMMENT ON TABLE fato_internacoes IS
    'Internações (AIH reduzida). Base das Perguntas 2, 3, 4, 5, 6. cgc_hosp pode ser NULL (17.695 casos confirmados, jul-dez/2024) — sempre LEFT JOIN com dim_estabelecimento, nunca INNER.';

-- ============================================================
-- 9. DE-PARA: ESPECIALIDADE (SIH) -> TIPO DE LEITO (CNES)
-- ============================================================
-- Mapeamento da fatia mínima (leitos clínicos e cirúrgicos), confirmado em código
-- pela Thaís e validado contra a explicação do mentor (17/09): "se ficarem no nível
-- clínico e cirúrgico, o de-para é quase um para um".
--
-- COBERTURA: só 2 dos 9 códigos de ESPEC (dom_especialidade_sih) têm de-para aqui —
-- 01 (Cirurgia geral) e 03 (Clínica médica). Os outros 7 (Obstetrícia, Psiquiatria,
-- Pediatria, etc.) ficam FORA do recorte "clínico e cirúrgico" do projeto — internações
-- nessas especialidades não devem ser cruzadas com fato_leitos usando esta tabela.
CREATE TABLE de_para_especialidade_leito (
    espec      CHAR(2)  PRIMARY KEY REFERENCES dom_especialidade_sih (espec),
    tp_leito   CHAR(2)  NOT NULL REFERENCES dom_tipo_leito (tp_leito)
);

COMMENT ON TABLE de_para_especialidade_leito IS
    'Liga a especialidade da internação (SIH) ao tipo de leito (CNES) — só para o recorte clínico/cirúrgico. Base para as Perguntas 2, 3, 4, 6.';

INSERT INTO de_para_especialidade_leito (espec, tp_leito) VALUES
    ('01', '1'),  -- Cirurgia geral -> Cirúrgico
    ('03', '2');  -- Clínica médica -> Clínico
