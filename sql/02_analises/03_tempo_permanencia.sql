WITH hospital_especialidade AS (
    SELECT
        f.competencia,
        f.cnes,
        f.espec,
        COUNT(*)::INTEGER AS qtd_internacoes,
        ROUND(AVG(f.dias_perm)::NUMERIC, 2) AS tempo_medio_hospital
    FROM fato_internacoes f
    INNER JOIN de_para_especialidade_leito dp 
        ON f.espec = dp.espec
    WHERE f.ident = '1'
      AND f.dias_perm IS NOT NULL
      AND dp.espec IN ('01', '03')
    GROUP BY
        f.competencia,
        f.cnes,
        f.espec
),

estatisticas_rede AS (
    SELECT
        f.competencia,
        f.espec,
        COUNT(*)::INTEGER AS total_internacoes_rede,
        ROUND(AVG(f.dias_perm)::NUMERIC, 2) AS tempo_medio_rede,
        ROUND(COALESCE(STDDEV_POP(f.dias_perm)::NUMERIC, 0), 2) AS desvio_padrao_rede
    FROM fato_internacoes f
    INNER JOIN de_para_especialidade_leito dp 
        ON f.espec = dp.espec
    WHERE f.ident = '1'
      AND f.dias_perm IS NOT NULL
      AND dp.espec IN ('01', '03')
    GROUP BY
        f.competencia,
        f.espec
)

SELECT
    h.competencia,
    h.cnes,
    dim.nome_estabelecimento AS unidade,
    dim.municipio,
    
    h.espec,
    esp.especialidade,
    
    h.qtd_internacoes,
    h.tempo_medio_hospital,
    r.tempo_medio_rede,
    
    -- Diferença absoluta e percentual
    ROUND((h.tempo_medio_hospital - r.tempo_medio_rede), 2) AS diferenca_dias,
    
    ROUND(
        100.0 * (h.tempo_medio_hospital - r.tempo_medio_rede) 
        / NULLIF(r.tempo_medio_rede, 0), 
        2
    ) AS diferenca_percentual,
    
    -- Classificação do desvio do padrão da rede
    CASE 
        WHEN r.desvio_padrao_rede > 0 
             AND h.tempo_medio_hospital > (r.tempo_medio_rede + 1.5 * r.desvio_padrao_rede) 
        THEN 'Muito acima do padrão'
        
        WHEN r.desvio_padrao_rede > 0 
             AND h.tempo_medio_hospital < (r.tempo_medio_rede - 1.5 * r.desvio_padrao_rede) 
        THEN 'Muito abaixo do padrão'
        
        ELSE 'Dentro do padrão'
    END AS status_fora_do_padrao

FROM hospital_especialidade h

INNER JOIN estatisticas_rede r
    ON h.competencia = r.competencia
   AND h.espec = r.espec

LEFT JOIN dim_estabelecimento dim
    ON h.cnes = dim.cnes
   AND h.competencia = dim.competencia

LEFT JOIN dom_especialidade_sih esp
    ON h.espec = esp.espec
-- Adicionado o JOIN para trazer a tabela de leitos (l)
LEFT JOIN fato_leitos fl
    ON h.cnes = fl.cnes
   AND h.competencia = fl.competencia
   
-- Filtro para garantir apenas unidades com nome não nulo
WHERE dim.nome_estabelecimento IS NOT null and fl.gestao_munic = 1

ORDER BY
    h.competencia ASC,
    h.espec ASC,
    diferenca_percentual DESC;