WITH leitos AS (

    SELECT
        competencia,
        cnes,
        SUM(qt_sus) AS leitos_sus

    FROM fato_leitos

    WHERE tp_leito IN ('1', '2')

    GROUP BY
        competencia,
        cnes
),

internacoes AS (

    SELECT
        competencia,
        cnes,

        COUNT(*) AS qtd_internacoes,

        SUM(dias_perm) AS dias_permanencia

    FROM fato_internacoes

    WHERE ident = '1'
      AND dias_perm IS NOT NULL
      AND dias_perm >= 0

    GROUP BY
        competencia,
        cnes
),

base AS (

    SELECT
        l.competencia,
        l.cnes,

        l.leitos_sus,

        COALESCE(i.qtd_internacoes, 0)
            AS qtd_internacoes,

        COALESCE(i.dias_permanencia, 0)
            AS dias_permanencia,

        EXTRACT(
            DAY FROM (
                DATE_TRUNC(
                    'month',
                    TO_DATE(l.competencia, 'YYYYMM')
                ) + INTERVAL '1 month - 1 day'
            )
        ) AS dias_mes

    FROM leitos l

    LEFT JOIN internacoes i
        ON l.cnes = i.cnes
       AND l.competencia = i.competencia
),

indicadores AS (

    SELECT
        b.*,

        b.leitos_sus * b.dias_mes
            AS capacidade_leito_dias,

        ROUND(
            100.0 * b.dias_permanencia /
            NULLIF(
                b.leitos_sus * b.dias_mes,
                0
            ),
            2
        ) AS taxa_ocupacao

    FROM base b
)

SELECT
    i.competencia,
    i.cnes,

    de.nome_estabelecimento,
    de.municipio,

    i.leitos_sus,
    i.dias_mes,

    i.capacidade_leito_dias,

    i.qtd_internacoes,
    i.dias_permanencia,

    i.capacidade_leito_dias
        - i.dias_permanencia
        AS leito_dias_nao_utilizados,

    i.taxa_ocupacao,

    CASE
        WHEN i.taxa_ocupacao < 70
            THEN 'Abaixo de 70%'

        WHEN i.taxa_ocupacao <= 85
            THEN 'Saudável'

        ELSE 'Sobrecarga'
    END AS faixa_leitura

FROM indicadores i

LEFT JOIN dim_estabelecimento de
    ON i.cnes = de.cnes
   AND i.competencia = de.competencia

ORDER BY
    i.competencia,
    i.taxa_ocupacao ASC;