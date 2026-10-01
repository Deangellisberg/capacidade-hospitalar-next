WITH internacoes AS (
    SELECT
        competencia,
        cnes,
        SUM(dias_perm) AS dias_permanencia
    FROM fato_internacoes
    WHERE ident = '1'
    GROUP BY
        competencia,
        cnes
),

leitos AS (
    SELECT
        competencia,
        cnes,
        SUM(qt_sus) AS leitos_sus
    FROM fato_leitos
    WHERE tp_leito IN ('1', '2')
    GROUP BY
        competencia,
        cnes
)

SELECT
    i.competencia,
    i.cnes,
    de.nome_estabelecimento,
    de.municipio,

    l.leitos_sus,

    -- número de dias da competência
    EXTRACT(
        DAY FROM (
            DATE_TRUNC(
                'month',
                TO_DATE(i.competencia, 'YYYYMM')
            ) + INTERVAL '1 month - 1 day'
        )
    ) AS dias_mes,

    -- capacidade estimada em leito-dias
    l.leitos_sus *
    EXTRACT(
        DAY FROM (
            DATE_TRUNC(
                'month',
                TO_DATE(i.competencia, 'YYYYMM')
            ) + INTERVAL '1 month - 1 day'
        )
    ) AS capacidade_leito_dias,

    i.dias_permanencia,

    -- taxa de ocupação
    ROUND(
        100.0 * i.dias_permanencia /
        NULLIF(
            l.leitos_sus *
            EXTRACT(
                DAY FROM (
                    DATE_TRUNC(
                        'month',
                        TO_DATE(i.competencia, 'YYYYMM')
                    ) + INTERVAL '1 month - 1 day'
                )
            ),
            0
        ),
        2
    ) AS taxa_ocupacao

FROM internacoes i

LEFT JOIN leitos l
    ON i.cnes = l.cnes
   AND i.competencia = l.competencia

LEFT JOIN dim_estabelecimento de
    ON i.cnes = de.cnes
   AND i.competencia = de.competencia

WHERE l.leitos_sus > 0

ORDER BY
    i.competencia,
    taxa_ocupacao DESC;