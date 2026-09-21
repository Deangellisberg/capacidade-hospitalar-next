-- Modelo relacional — Projeto P5 (Capacidade Hospitalar)

-- ORDEM DE CRIAÇÃO: tabelas de domínio e dimensão primeiro, tabelas de fato depois

-- Validação com dado real: fato_internacoes (SIH-RD) identifica o hospital por CNPJ (cgc_hosp). 
-- Confirmamos que esse valor bate diretamente com o campo CPF_CNPJ, já presente no CNES-LT

-- Todos os campos-chave (cnes, cgc_hosp) são VARCHAR, não INTEGER — porque CNES-LT e SIH-RD entregam tudo como texto
-- Hospitais/MS, onde CNES chega como número, padronizamos para texto aqui, para não
-- perder zeros à esquerda e manter os três lados da junção compatíveis.

-- LISTA DE HOSPITAIS DE GESTÃO PRÓPRIA (derivada, com origem rastreável)
-- Decisão da mentoria (17/09): nunca escrever o filtro de hospitais direto numa consulta. 
-- A lista vira tabela, com uma coluna dizendo de onde cada linha veio — "derivada do CNES" (cruzando tipo de gestão + natureza jurídica + esfera com
-- a fonte que separa hospitais da Prefeitura do Recife), depois "oficial SERMAC"
-- quando a lista do cliente chegar. Troca de fonte vira carga nova, não reescrita.

CREATE TABLE lista_hospitais_gestao_propria (
    cnes        VARCHAR(10)  NOT NULL,
    origem      VARCHAR(30)  NOT NULL,   -- 'derivada_cnes' | 'oficial_sermac'
    data_carga  DATE         NOT NULL,
    PRIMARY KEY (cnes, origem)
);

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

-- 2. DOMÍNIO: TIPO DE LEITO 
CREATE TABLE dom_tipo_leito (
    tp_leito     CHAR(2)      PRIMARY KEY,
    categoria    VARCHAR(50)  NOT NULL
);

-- 3. DOMÍNIO: CÓDIGO DE LEITO (especialidade específica)
CREATE TABLE dom_codigo_leito (
    codleito        CHAR(2)      PRIMARY KEY,
    especialidade   VARCHAR(100) NOT NULL
);

-- 4. LEITOS (CNES-LT)
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

-- 5. PONTE: TRADUÇÃO CNPJ (SIH-RD) <-> CNES (demais fontes)
CREATE TABLE de_para_cnpj_cnes (
    cpf_cnpj    VARCHAR(14)  PRIMARY KEY,
    cnes        VARCHAR(10)  NOT NULL
);

-- 6. DOMÍNIO: ESPECIALIDADE (SIH)
CREATE TABLE dom_especialidade_sih (
    espec           CHAR(2)      PRIMARY KEY,
    especialidade   VARCHAR(100) NOT NULL
);

-- 7. DOMÍNIO: TIPO DE AIH
CREATE TABLE dom_tipo_aih (
    ident         CHAR(1)      PRIMARY KEY,
    significado   VARCHAR(200) NOT NULL
);

-- 8. INTERNAÇÕES (SIH-RD)
CREATE TABLE fato_internacoes (
    n_aih          VARCHAR(20)  NOT NULL,
    ano_cmpt       CHAR(4)      NOT NULL,
    mes_cmpt       CHAR(2)      NOT NULL,
    cgc_hosp       VARCHAR(14),           -- NULLABLE — para cnpjs vazios
    espec          CHAR(2),
    ident          CHAR(1),               -- 1=Normal, 5=Longa permanência
    dt_saida       DATE,                  -- convertido de texto (AAAAMMDD) no 02_transformacao.py
    dias_perm      INTEGER,
    proc_rea       VARCHAR(10),           -- grupo 04 = procedimentos cirúrgicos
    munic_res      VARCHAR(7),
    idade          INTEGER,
    sexo           CHAR(1),
    morte          CHAR(1),
    PRIMARY KEY (n_aih, ano_cmpt, mes_cmpt),
    FOREIGN KEY (cgc_hosp) REFERENCES de_para_cnpj_cnes (cpf_cnpj),
    FOREIGN KEY (espec) REFERENCES dom_especialidade_sih (espec),
    FOREIGN KEY (ident) REFERENCES dom_tipo_aih (ident)
);

-- 9. DE-PARA: ESPECIALIDADE (SIH) -> TIPO DE LEITO (CNES)
CREATE TABLE de_para_especialidade_leito (
    espec      CHAR(2)  PRIMARY KEY REFERENCES dom_especialidade_sih (espec),
    tp_leito   CHAR(2)  NOT NULL REFERENCES dom_tipo_leito (tp_leito)
);

INSERT INTO de_para_especialidade_leito (espec, tp_leito) VALUES
    ('01', '1'),  -- Cirurgia geral -> Cirúrgico
    ('03', '2');  -- Clínica médica -> Clínico
