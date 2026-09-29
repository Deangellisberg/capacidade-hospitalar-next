
WITH hospital_especialidade AS (

    SELECT
        competencia,
        cnes,
        espec,

        COUNT(*) AS qtd_internacoes,

        AVG(dias_perm) AS tempo_medio

    FROM fato_internacoes

    WHERE ident = '1'
      AND dias_perm IS NOT NULL

    GROUP BY
        competencia,
        cnes,
        espec
),

rede_especialidade AS (

    SELECT
        competencia,
        espec,

        AVG(dias_perm) AS tempo_medio_rede

    FROM fato_internacoes

    WHERE ident = '1'
      AND dias_perm IS NOT NULL

    GROUP BY
        competencia,
        espec
)

SELECT
    h.competencia,
    h.cnes,
    de.nome_estabelecimento,
    de.municipio,

    h.espec,
    esp.especialidade,

    h.qtd_internacoes,

    ROUND(h.tempo_medio::NUMERIC, 2)
        AS tempo_medio_hospital,

    ROUND(r.tempo_medio_rede::NUMERIC, 2)
        AS tempo_medio_rede,

    ROUND(
        (h.tempo_medio - r.tempo_medio_rede)::NUMERIC,
        2
    ) AS diferenca_dias,

    ROUND(
        100.0 *
        (h.tempo_medio - r.tempo_medio_rede)
        / NULLIF(r.tempo_medio_rede, 0),
        2
    ) AS diferenca_percentual

FROM hospital_especialidade h

LEFT JOIN rede_especialidade r
    ON h.competencia = r.competencia
   AND h.espec = r.espec

LEFT JOIN dim_estabelecimento de
    ON h.cnes = de.cnes
   AND h.competencia = de.competencia

LEFT JOIN dom_especialidade_sih esp
    ON h.espec = esp.espec

ORDER BY
    h.competencia,
    h.espec,
    diferenca_percentual DESC;