CREATE VIEW vw_05_diagnostico AS
WITH periodo AS (
    SELECT DATE '2024-06-01' AS data_ini,
           DATE '2026-05-31' AS data_fim
),

parametros AS (
    SELECT
        75.0 AS limite_alta_pct,   -- ocupação >= limite = alta; abaixo = baixa
        20.0 AS limite_gap_pct,    -- gap existentes x SUS acima disso gera alerta
        12   AS min_meses          -- série mínima para diagnosticar
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
),

mensal AS (
    SELECT
        l.inicio_mes,
        l.cnes,
        l.tp_leito,
        l.leitos_existentes,
        l.leitos_sus,
        l.leitos_existentes * l.dias_no_mes AS leitos_dia_cadastrados,
        l.leitos_sus * l.dias_no_mes        AS leitos_dia_disponiveis,
        COALESCE(a.total_internacoes, 0)    AS total_internacoes,
        COALESCE(m.dias_ocupados, 0)        AS dias_ocupados,
        m.primeira_entrada,
        m.ultima_entrada,
        m.primeira_saida,
        m.ultima_saida
    FROM leitos l
    LEFT JOIN admissoes a
        ON l.cnes = a.cnes AND l.inicio_mes = a.inicio_mes AND l.tp_leito = a.tp_leito
    LEFT JOIN dias_mes m
        ON l.cnes = m.cnes AND l.inicio_mes = m.inicio_mes AND l.tp_leito = m.tp_leito
),

resumo AS (
    SELECT
        cnes,
        tp_leito,
        COUNT(*)                                                    AS meses_com_cadastro,
        ROUND(AVG(leitos_existentes), 1)                            AS leitos_existentes_medios,
        ROUND(AVG(leitos_sus), 1)                                   AS leitos_sus_medios,
        COUNT(*) FILTER (WHERE leitos_sus > leitos_existentes)      AS meses_sus_maior_que_existente,
        SUM(total_internacoes)::INTEGER                             AS total_internacoes,
        SUM(dias_ocupados)::INTEGER                                 AS dias_ocupados,
        SUM(leitos_dia_cadastrados)::INTEGER                        AS leitos_dia_cadastrados,
        SUM(leitos_dia_disponiveis)::INTEGER                        AS leitos_dia_disponiveis,
        MIN(primeira_entrada)                                       AS primeira_entrada,
        MAX(ultima_entrada)                                         AS ultima_entrada,
        MIN(primeira_saida)                                         AS primeira_saida,
        MAX(ultima_saida)                                           AS ultima_saida
    FROM mensal
    GROUP BY cnes, tp_leito
),

indicadores AS (
    SELECT
        r.*,
        ROUND(100.0 * r.dias_ocupados / NULLIF(r.leitos_dia_cadastrados, 0), 2) AS taxa_ocupacao_cadastrada_pct,
        ROUND(100.0 * r.dias_ocupados / NULLIF(r.leitos_dia_disponiveis, 0), 2) AS taxa_ocupacao_pct,
        ROUND(100.0 * (r.leitos_dia_cadastrados - r.leitos_dia_disponiveis)
              / NULLIF(r.leitos_dia_cadastrados, 0), 2)                          AS gap_existentes_sus_pct
    FROM resumo r
),

-- Permanência: mesma população da consulta 03 (internações de unidades/meses com cadastro municipal)
base_municipal AS (
    SELECT
        b.cnes,
        b.tp_leito,
        b.dias_ocupados
    FROM internacoes_base b
    CROSS JOIN periodo p
    INNER JOIN leitos l
        ON l.cnes = b.cnes
       AND l.tp_leito = b.tp_leito
       AND l.inicio_mes = DATE_TRUNC('month', b.dt_inter)::DATE
    WHERE b.dt_inter BETWEEN p.data_ini AND p.data_fim
),

permanencia_unidade AS (
    SELECT cnes, tp_leito, ROUND(AVG(dias_ocupados), 2) AS tempo_medio_dias
    FROM base_municipal
    GROUP BY cnes, tp_leito
),

permanencia_rede AS (
    SELECT tp_leito, ROUND(AVG(dias_ocupados), 2) AS tempo_medio_rede_dias
    FROM base_municipal
    GROUP BY tp_leito
)

SELECT
    pe.data_ini                                          AS inicio_periodo,
    pe.data_fim                                          AS fim_periodo,
    i.primeira_entrada,
    i.ultima_entrada,
    i.primeira_saida,
    i.ultima_saida,
    i.cnes,
    COALESCE(u.nome_estabelecimento, 'CNES: ' || i.cnes) AS unidade,
    i.tp_leito,
    COALESCE(t.categoria, 'Não especificado')            AS tipo_leito,
    i.meses_com_cadastro,
    i.leitos_existentes_medios,
    i.leitos_sus_medios,
    ROUND(i.leitos_existentes_medios - i.leitos_sus_medios, 1) AS leitos_existentes_sem_sus_medios,
    i.meses_sus_maior_que_existente,
    i.total_internacoes,
    i.dias_ocupados,
    i.leitos_dia_cadastrados,
    i.leitos_dia_disponiveis,
    i.taxa_ocupacao_cadastrada_pct,
    i.taxa_ocupacao_pct,
    i.gap_existentes_sus_pct,
    pu.tempo_medio_dias,
    pr.tempo_medio_rede_dias,
    CASE
        WHEN i.meses_com_cadastro < p.min_meses
            THEN 'Série curta - avaliar com cautela'
        WHEN i.total_internacoes = 0
            THEN 'Sem produção registrada'
        WHEN i.taxa_ocupacao_cadastrada_pct IS NULL
            THEN 'Inconsistência cadastral'
        WHEN i.taxa_ocupacao_pct IS NULL
            THEN 'Sem leito SUS no período'
        WHEN i.taxa_ocupacao_cadastrada_pct >= p.limite_alta_pct
         AND i.taxa_ocupacao_pct >= p.limite_alta_pct
            THEN 'Alta ocupação (cadastrada e SUS)'
        WHEN i.taxa_ocupacao_cadastrada_pct < p.limite_alta_pct
         AND i.taxa_ocupacao_pct >= p.limite_alta_pct
            THEN 'Alta ocupação só sobre leitos SUS'
        WHEN i.taxa_ocupacao_cadastrada_pct < p.limite_alta_pct
         AND i.taxa_ocupacao_pct < p.limite_alta_pct
            THEN 'Baixa ocupação (cadastrada e SUS)'
        ELSE 'Inconsistência cadastral'
    END AS padrao_ocupacao,
    CASE
        WHEN i.gap_existentes_sus_pct > p.limite_gap_pct
            THEN 'Gap entre leitos existentes e SUS acima de ' || p.limite_gap_pct::INTEGER || '%'
    END AS alerta_gap
FROM indicadores i
CROSS JOIN parametros p
CROSS JOIN periodo pe
LEFT JOIN unidades u             ON i.cnes = u.cnes
LEFT JOIN tipos t                ON i.tp_leito = t.tp_leito
LEFT JOIN permanencia_unidade pu ON i.cnes = pu.cnes AND i.tp_leito = pu.tp_leito
LEFT JOIN permanencia_rede pr    ON i.tp_leito = pr.tp_leito
ORDER BY (i.gap_existentes_sus_pct > p.limite_gap_pct) DESC NULLS LAST,
         i.gap_existentes_sus_pct DESC NULLS LAST,
         unidade, i.tp_leito;