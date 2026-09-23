-- Modelo relacional — Projeto P5 (Capacidade Hospitalar)

-- STATUS: EM DESENVOLVIMENTO — primeira versão, baseada no de-para já validado (de_para_p5_capacidade_hospitalar.xlsx, aba "Tabelas do Banco").
-- ORDEM DE CRIAÇÃO: tabelas de domínio e dimensão primeiro, tabelas de fato depois —
-- Postgres exige que a tabela referenciada por uma FK já exista no momento do CREATE.
-- Todos os campos-chave (cnes) são VARCHAR, não INTEGER — porque CNES-LT e SIH-RD entregam tudo como texto.
-- MSHL (Hospitais e Leitos/MS), onde CNES chega como número, padronizamos para texto para não perder zeros à esquerda e manter os três lados da junção compatíveis.


-- 0. LISTA DE HOSPITAIS DE GESTÃO PRÓPRIA (derivada, com origem rastreável)

CREATE TABLE lista_hospitais_gestao_propria (
    cnes        VARCHAR(10)  NOT NULL,
    origem      VARCHAR(30)  NOT NULL,   -- 'derivada_cnes' | 'oficial_sermac'
    data_carga  DATE         NOT NULL,
    PRIMARY KEY (cnes, origem)
);

COMMENT ON TABLE lista_hospitais_gestao_propria IS
    'Hospitais de gestão própria, com origem rastreável. Troca de fonte é carga nova, nunca reescrita.';


-- 1. DIMENSÃO: ESTABELECIMENTO (MSHL — Hospitais e Leitos / Ministério da Saúde)

CREATE TABLE dim_estabelecimento (
    cnes                     VARCHAR(7)  NOT NULL,
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
    'Identificação do hospital, fonte MSHL. CNES chega como número — converter com Int64->string->zfill(7) para não corromper o valor se houver nulo na coluna.';


-- 2. DOMÍNIO: TIPO DE LEITO (categoria ampla)

CREATE TABLE dom_tipo_leito (
    tp_leito     CHAR(2)      PRIMARY KEY,
    categoria    VARCHAR(50)  NOT NULL
);

COMMENT ON TABLE dom_tipo_leito IS
    'Categoria ampla de leito. Recorte clínico/cirúrgico: tp_leito IN (''1'',''2''). Sem zero à esquerda no dado real.';

INSERT INTO dom_tipo_leito (tp_leito, categoria) VALUES
    ('1', 'Cirúrgico'),
    ('2', 'Clínico'),
    ('3', 'Complementar'),
    ('4', 'Obstétricos'),
    ('5', 'Pediátricos'),
    ('6', 'Outras Especialidades'),
    ('7', 'Hospital Dia');


-- 3. DOMÍNIO: CÓDIGO DE LEITO (especialidade específica)

CREATE TABLE dom_codigo_leito (
    codleito        CHAR(2)      PRIMARY KEY,
    especialidade   VARCHAR(100) NOT NULL
);

COMMENT ON TABLE dom_codigo_leito IS
    'Especialidade específica do leito, 66 códigos. Códigos fora do recorte clínico/cirúrgico (tp_leito=3) são filtrados na transformação, não cadastrados aqui.';

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


-- 4. FATO: LEITOS (CNES-LT)

CREATE TABLE fato_leitos (
    cnes           VARCHAR(7)  NOT NULL,
    codleito       CHAR(2)      NOT NULL,
    tp_leito       CHAR(2),                 -- 1=Cirúrgico, 2=Clínico
    competencia    CHAR(6)      NOT NULL,   -- formato AAAAMM
    qt_exist       INTEGER,
    qt_sus         INTEGER,
    PRIMARY KEY (cnes, codleito, competencia),
    FOREIGN KEY (tp_leito) REFERENCES dom_tipo_leito (tp_leito),
    FOREIGN KEY (codleito) REFERENCES dom_codigo_leito (codleito)
);

COMMENT ON TABLE fato_leitos IS
    'Leitos por hospital, tipo e competência. Liga com dim_estabelecimento por cnes, sem FK real — nem toda competência do CNES-LT tem linha correspondente no MSHL. Sempre LEFT JOIN, nunca INNER.';


-- 5. DOMÍNIO: ESPECIALIDADE (SIH)

CREATE TABLE dom_especialidade_sih (
    espec           CHAR(2)      PRIMARY KEY,
    especialidade   VARCHAR(100) NOT NULL
);

COMMENT ON TABLE dom_especialidade_sih IS
    'Especialidade da internação (SIH). De-para com tipo de leito cobre só 01 e 03 (recorte clínico/cirúrgico). Códigos 10, 12, 87 existem no dado real sem significado oficial documentado — cadastrados como placeholder.';

INSERT INTO dom_especialidade_sih (espec, especialidade) VALUES
    ('01', 'Cirurgia geral'),
    ('02', 'Obstetrícia'),
    ('03', 'Clínica médica'),
    ('04', 'Crônico e FPT'),
    ('05', 'Psiquiatria'),
    ('06', 'Tisiologia'),
    ('07', 'Pediatria'),
    ('08', 'Reabilitação'),
    ('09', 'Psiquiatria - hospital/dia'),
    ('10','Fora do domínio original 01-09 - revisar'),
    ('12','Fora do domínio original 01-09 - revisar'),
    ('87','Fora do domínio original 01-09 - revisar');


-- 6. DOMÍNIO: TIPO DE AIH

CREATE TABLE dom_tipo_aih (
    ident         CHAR(1)      PRIMARY KEY,
    significado   VARCHAR(200) NOT NULL
);

COMMENT ON TABLE dom_tipo_aih IS
    'Tipo de AIH. ident=5 marca longa permanência — mesma internação, nova linha a cada competência, dt_inter repete. Ao contar internações, filtrar ident=''1''.';

INSERT INTO dom_tipo_aih (ident, significado) VALUES
    ('1', 'AIH Normal'),
    ('5', 'AIH de Longa Permanencia e FTP');


-- 7. FATO: INTERNAÇÕES (SIH-RD)

CREATE TABLE fato_internacoes (
    n_aih          VARCHAR(20)  NOT NULL,
    competencia    CHAR(6)      NOT NULL,   -- formato AAAAMM
    cnes           VARCHAR(7),            -- chave de junção, sem FK real (ver nota no topo)
    cgc_hosp       VARCHAR(14),           -- so auditoria, nao usado no join
    espec          CHAR(2),
    ident          CHAR(1),               -- 1=Normal, 5=Longa permanência
    sequencia      VARCHAR(5),               
    dt_inter       DATE,
    dt_saida       DATE,
    dias_perm      INTEGER,
    qt_diarias     INTEGER,
    proc_rea       VARCHAR(10),
    munic_res      VARCHAR(7),
    munic_mov      VARCHAR(7),
    uf_zi          VARCHAR(7),
    idade          INTEGER,
    sexo           CHAR(1),
    morte          CHAR(1),
    PRIMARY KEY (n_aih, competencia, ident),
    FOREIGN KEY (espec) REFERENCES dom_especialidade_sih (espec),
    FOREIGN KEY (ident) REFERENCES dom_tipo_aih (ident)
);

COMMENT ON TABLE fato_internacoes IS
    'Internações (AIH reduzida). Liga com dim_estabelecimento/fato_leitos por cnes, sem FK real — cgc_hosp fica só como auditoria. Sempre LEFT JOIN. PK inclui ident: longa permanência gera 2 linhas na mesma competência (ident=1 e ident=5), mesmo n_aih. sequencia é só auditoria/desempate.';

CREATE TABLE de_para_especialidade_leito (
    espec      CHAR(2)  PRIMARY KEY REFERENCES dom_especialidade_sih (espec),
    tp_leito   CHAR(2)  NOT NULL REFERENCES dom_tipo_leito (tp_leito)
);

COMMENT ON TABLE de_para_especialidade_leito IS
    'Liga especialidade (SIH) a tipo de leito (CNES). Cobre só o recorte mínimo: 01->Cirúrgico, 03->Clínico.';

INSERT INTO de_para_especialidade_leito (espec, tp_leito) VALUES
    ('01', '1'),  -- Cirurgia geral -> Cirúrgico
    ('03', '2');  -- Clínica médica -> Clínico