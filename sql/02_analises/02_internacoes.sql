WITH leitos AS (
    SELECT
        fl.competencia,
        fl.cnes,
        fl.gestao_munic,
        fl.tp_leito,
        SUM(fl.qt_sus) AS leitos_sus
    FROM fato_leitos fl
    WHERE fl.tp_leito IN ('1', '2') -- 1 Cirúrgico, 2 Clínico
    GROUP by
    	fl.gestao_munic,
        fl.competencia,
        fl.cnes,
        fl.tp_leito
),

internacoes AS (
    SELECT
        fi.competencia,
        fi.cnes,
        COALESCE(dp.tp_leito, '6') AS tp_leito,
        COUNT(fi.n_aih) AS total_internacoes,
        SUM(fi.dias_perm) AS dias_permanencia
    FROM fato_internacoes fi
    LEFT JOIN de_para_especialidade_leito dp
        ON fi.espec = dp.espec
    WHERE fi.ident = '1'
    GROUP BY
        fi.competencia,
        fi.cnes,
        COALESCE(dp.tp_leito, '6')
)

SELECT
    l.competencia,
    l.cnes,
    dim.nome_estabelecimento as unidade,
    dim.municipio,
    dtl.categoria AS tipo_leito,
    
    l.leitos_sus,
    COALESCE(i.total_internacoes, 0) AS total_internacoes,
    COALESCE(i.dias_permanencia, 0) AS dias_permanencia,

    -- Giro de Leito
    ROUND(
        1.0 * COALESCE(i.total_internacoes, 0) / NULLIF(l.leitos_sus, 0),
        2
    ) AS internacoes_por_leito_disponivel,

    -- 1. Taxa de Ocupação Real (%)
    ROUND(
        100.0 * COALESCE(i.dias_permanencia, 0) /
        NULLIF(
            l.leitos_sus * EXTRACT(
                DAY FROM (
                    DATE_TRUNC('month', TO_DATE(l.competencia, 'YYYYMM')) + INTERVAL '1 month - 1 day'
                )
            ),
            0
        ),
        2
    ) AS taxa_ocupacao_real,

    -- 2. Taxa de Ocupação Ajustada (%) - Cap de 100%
    LEAST(
        ROUND(
            100.0 * COALESCE(i.dias_permanencia, 0) /
            NULLIF(
                l.leitos_sus * EXTRACT(
                    DAY FROM (
                        DATE_TRUNC('month', TO_DATE(l.competencia, 'YYYYMM')) + INTERVAL '1 month - 1 day'
                    )
                ),
                0
            ),
            2
        ),
        100.00
    ) AS taxa_ocupacao_ajustada

FROM leitos l

LEFT JOIN internacoes i
    ON l.cnes = i.cnes
   AND l.competencia = i.competencia
   AND l.tp_leito = i.tp_leito

LEFT JOIN dom_tipo_leito dtl
    ON l.tp_leito = dtl.tp_leito

LEFT JOIN dim_estabelecimento dim
    ON l.cnes = dim.cnes
   AND l.competencia = dim.competencia
   
-- Filtro para garantir apenas unidades com nome não nulo
WHERE l.leitos_sus > 0 and dim.nome_estabelecimento IS NOT null and l.gestao_munic = 1

ORDER BY
    l.competencia,
    l.cnes,
    l.tp_leito;
