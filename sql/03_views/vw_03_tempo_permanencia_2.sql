CREATE VIEW vw_03_tempo_permanencia_2 AS
WITH periodo AS (
    SELECT DATE '2024-06-01' AS data_ini,
           DATE '2026-05-31' AS data_fim
),

parametros AS (
    SELECT 1.5 AS limite_z    -- acima/abaixo desse z = fora do padrão
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

-- Só internações de unidades/meses com cadastro municipal
base_municipal AS (
    SELECT
        DATE_TRUNC('month', b.dt_inter)::DATE AS inicio_mes,
        b.cnes,
        b.tp_leito,
        b.dt_inter,
        b.dt_saida,
        b.dias_ocupados
    FROM internacoes_base b
    CROSS JOIN periodo p
    INNER JOIN leitos l
        ON l.cnes = b.cnes
       AND l.tp_leito = b.tp_leito
       AND l.inicio_mes = DATE_TRUNC('month', b.dt_inter)::DATE
    WHERE b.dt_inter BETWEEN p.data_ini AND p.data_fim
),

estatisticas_rede AS (
    SELECT
        inicio_mes,
        tp_leito,
        COUNT(*)::INTEGER                         AS total_internacoes_rede,
        SUM(dias_ocupados)::INTEGER               AS dias_permanencia_rede,
        AVG(dias_ocupados)                        AS media_rede,
        COALESCE(STDDEV_POP(dias_ocupados), 0)    AS desvio_rede
    FROM base_municipal
    GROUP BY inicio_mes, tp_leito
),

hospital_producao AS (
    SELECT
        inicio_mes,
        cnes,
        tp_leito,
        COUNT(*)::INTEGER              AS total_internacoes,
        SUM(dias_ocupados)::INTEGER    AS dias_permanencia_total,
        AVG(dias_ocupados)             AS media_hospital,
        MIN(dt_inter)                  AS primeira_entrada,
        MAX(dt_inter)                  AS ultima_entrada,
        MIN(dt_saida)                  AS primeira_saida,
        MAX(dt_saida)                  AS ultima_saida
    FROM base_municipal
    GROUP BY inicio_mes, cnes, tp_leito
),

comparativo AS (
    SELECT
        l.competencia,
        l.mes,
        l.inicio_mes,
        l.fim_mes,
        l.cnes,
        l.tp_leito,
        l.leitos_sus,
        hp.total_internacoes,
        hp.dias_permanencia_total,
        hp.media_hospital,
        r.total_internacoes_rede,
        r.dias_permanencia_rede,
        r.media_rede,
        r.desvio_rede,
        (hp.media_hospital - r.media_rede)
            / NULLIF(r.desvio_rede / SQRT(hp.total_internacoes::NUMERIC), 0) AS z_permanencia,
        hp.primeira_entrada,
        hp.ultima_entrada,
        hp.primeira_saida,
        hp.ultima_saida
    FROM leitos l
    LEFT JOIN hospital_producao hp
        ON l.cnes = hp.cnes AND l.inicio_mes = hp.inicio_mes AND l.tp_leito = hp.tp_leito
    LEFT JOIN estatisticas_rede r
        ON l.inicio_mes = r.inicio_mes AND l.tp_leito = r.tp_leito
)

SELECT
    cp.competencia,
    cp.mes,
    cp.inicio_mes,
    cp.fim_mes,
    cp.primeira_entrada,
    cp.ultima_entrada,
    cp.primeira_saida,
    cp.ultima_saida,
    cp.cnes,
    COALESCE(u.nome_estabelecimento, 'CNES: ' || cp.cnes) AS unidade,
    cp.tp_leito,
    COALESCE(t.categoria, 'Não especificado')             AS tipo_leito,
    cp.leitos_sus,
    COALESCE(cp.total_internacoes, 0)                     AS total_internacoes,
    COALESCE(cp.dias_permanencia_total, 0)                AS dias_permanencia_total,
    ROUND(cp.media_hospital, 2)                           AS tempo_medio_hospital,
    COALESCE(cp.total_internacoes_rede, 0)                AS total_internacoes_rede,
    COALESCE(cp.dias_permanencia_rede, 0)                 AS dias_permanencia_rede,
    ROUND(cp.media_rede, 2)                               AS tempo_medio_rede,
    ROUND(cp.desvio_rede, 2)                              AS desvio_padrao_rede,
    ROUND(cp.z_permanencia, 2)                            AS z_permanencia,
    CASE
        WHEN cp.total_internacoes IS NULL            THEN 'Sem internações no mês'
        WHEN cp.z_permanencia >  p.limite_z          THEN 'Muito acima do padrão'
        WHEN cp.z_permanencia < -p.limite_z          THEN 'Muito abaixo do padrão'
        ELSE 'Dentro do padrão'
    END AS status_fora_do_padrao
FROM comparativo cp
CROSS JOIN parametros p
LEFT JOIN unidades u ON cp.cnes = u.cnes
LEFT JOIN tipos t    ON cp.tp_leito = t.tp_leito
ORDER BY cp.inicio_mes, unidade, cp.tp_leito;