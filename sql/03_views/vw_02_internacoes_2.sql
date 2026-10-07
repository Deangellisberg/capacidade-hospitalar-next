CREATE VIEW vw_02_internacoes_2 AS
WITH periodo AS (
    SELECT DATE '2024-06-01' AS data_ini,
           DATE '2026-05-31' AS data_fim
),

-- Meses gerados pelas datas do período (início e fim de cada mês).
-- "chave_cnes" só liga ao cadastro do CNES (fato_leitos.competencia). A coluna competencia exibida vem da própria tabela e não gera datas.
calendario AS (
    SELECT
        d::DATE                                                                   AS inicio_mes,
        (DATE_TRUNC('month', d) + INTERVAL '1 month - 1 day')::DATE               AS fim_mes,
        TO_CHAR(d, 'MM/YYYY')                                                     AS mes,
        TO_CHAR(d, 'YYYYMM')                                                      AS chave_cnes,
        EXTRACT(DAY FROM (DATE_TRUNC('month', d) + INTERVAL '1 month - 1 day'))::INTEGER AS dias_no_mes
    FROM periodo p
    CROSS JOIN GENERATE_SERIES(DATE_TRUNC('month', p.data_ini)::DATE, p.data_fim, '1 month'::INTERVAL) d
),

-- Um registro por CNES (nome mais recente): evita duplicar leitos e trocar o nome da unidade
unidades AS (
    SELECT DISTINCT ON (cnes)
        cnes,
        nome_estabelecimento
    FROM dim_estabelecimento
    WHERE nome_estabelecimento IS NOT NULL
    ORDER BY cnes, competencia DESC
),

tipos AS (
    SELECT DISTINCT ON (tp_leito)
        tp_leito,
        categoria
    FROM dom_tipo_leito
    ORDER BY tp_leito, categoria
),

leitos AS (
    SELECT
        c.inicio_mes,
        c.fim_mes,
        c.mes,
        c.dias_no_mes,
        fl.competencia,
        fl.cnes,
        fl.tp_leito,
        SUM(fl.qt_exist)::INTEGER AS leitos_existentes,
        SUM(fl.qt_sus)::INTEGER   AS leitos_sus
    FROM fato_leitos fl
    INNER JOIN calendario c ON fl.competencia = c.chave_cnes
    WHERE fl.tp_leito IN ('1', '2')   -- 1 = Cirúrgico, 2 = Clínico
      AND fl.gestao_munic = 1
    GROUP BY c.inicio_mes, c.fim_mes, c.mes, c.dias_no_mes, fl.competencia, fl.cnes, fl.tp_leito
),

-- Uma linha por AIH (remove duplicidade); regra única de dias nas consultas.
-- Datas reais: dt_inter (entrada) e dt_saida (saída). fi.competencia não é usada.
internacoes_base AS (
    SELECT DISTINCT ON (fi.n_aih, fi.cnes, fi.dt_inter)
        fi.n_aih,
        fi.cnes,
        dp.tp_leito,
        fi.dt_inter,
        fi.dt_saida,
        GREATEST(COALESCE(fi.dt_saida - fi.dt_inter, fi.qt_diarias, fi.dias_perm, 1), 1)::INTEGER AS dias_ocupados
    FROM fato_internacoes fi
    INNER JOIN de_para_especialidade_leito dp ON fi.espec = dp.espec
    CROSS JOIN periodo p
    WHERE fi.ident = '1'
      AND dp.tp_leito IN ('1', '2')
      AND fi.dt_inter <= p.data_fim
    ORDER BY fi.n_aih, fi.cnes, fi.dt_inter, fi.dt_saida DESC NULLS LAST
),

-- Internações = AIH com entrada (dt_inter) dentro do mês
admissoes AS (
    SELECT
        DATE_TRUNC('month', b.dt_inter)::DATE AS inicio_mes,
        b.cnes,
        b.tp_leito,
        COUNT(*)::INTEGER                     AS total_internacoes
    FROM internacoes_base b
    CROSS JOIN periodo p
    WHERE b.dt_inter BETWEEN p.data_ini AND p.data_fim
    GROUP BY DATE_TRUNC('month', b.dt_inter)::DATE, b.cnes, b.tp_leito
),

-- Dias ocupados do início ao fim de cada mês: a internação é rateada entre os meses em que o paciente esteve internado.
-- As datas de entrada/saída são das internações que ocuparam leito no mês.
dias_mes AS (
    SELECT
        c.inicio_mes,
        b.cnes,
        b.tp_leito,
        SUM(
            LEAST(b.dt_inter + b.dias_ocupados, c.fim_mes + 1)
          - GREATEST(b.dt_inter, c.inicio_mes)
        )::INTEGER          AS dias_ocupados,
        MIN(b.dt_inter)     AS primeira_entrada,
        MAX(b.dt_inter)     AS ultima_entrada,
        MIN(b.dt_saida)     AS primeira_saida,
        MAX(b.dt_saida)     AS ultima_saida
    FROM internacoes_base b
    INNER JOIN calendario c
        ON b.dt_inter <= c.fim_mes
       AND b.dt_inter + b.dias_ocupados > c.inicio_mes
    GROUP BY c.inicio_mes, b.cnes, b.tp_leito
)

SELECT
    l.competencia,
    l.mes,
    l.inicio_mes,
    l.fim_mes,
    m.primeira_entrada,
    m.ultima_entrada,
    m.primeira_saida,
    m.ultima_saida,
    l.cnes,
    COALESCE(u.nome_estabelecimento, 'CNES: ' || l.cnes) AS unidade,
    l.tp_leito,
    COALESCE(t.categoria, 'Não especificado')            AS tipo_leito,
    l.leitos_sus,
    l.leitos_sus * l.dias_no_mes                         AS leitos_dia_disponiveis,
    COALESCE(a.total_internacoes, 0)                     AS total_internacoes,
    COALESCE(m.dias_ocupados, 0)                         AS dias_ocupados,
    ROUND(1.0 * COALESCE(a.total_internacoes, 0) / NULLIF(l.leitos_sus, 0), 2)               AS internacoes_por_leito,
    ROUND(100.0 * COALESCE(m.dias_ocupados, 0) / NULLIF(l.leitos_sus * l.dias_no_mes, 0), 2) AS taxa_ocupacao_pct
FROM leitos l
LEFT JOIN admissoes a
    ON l.cnes = a.cnes AND l.inicio_mes = a.inicio_mes AND l.tp_leito = a.tp_leito
LEFT JOIN dias_mes m
    ON l.cnes = m.cnes AND l.inicio_mes = m.inicio_mes AND l.tp_leito = m.tp_leito
LEFT JOIN unidades u ON l.cnes = u.cnes
LEFT JOIN tipos t    ON l.tp_leito = t.tp_leito
ORDER BY l.inicio_mes, unidade, l.tp_leito;