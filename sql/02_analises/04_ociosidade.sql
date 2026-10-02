WITH leitos_agregados AS (
    -- Agrupa os leitos SUS por hospital, competência e tipo de leito (1=Cirúrgico, 2=Clínico)
    SELECT
        l.competencia,
        l.gestao_munic,
        l.cnes,
        l.tp_leito,
        SUM(l.qt_sus)::INTEGER AS leitos_sus_cadastrados,
        -- Calcula o número de dias no mês a partir da competência (AAAAMM)
        EXTRACT(DAY FROM (
            TO_DATE(l.competencia, 'YYYYMM') + INTERVAL '1 month' - INTERVAL '1 day'
        ))::INTEGER AS dias_no_mes
    FROM fato_leitos l
    WHERE l.qt_sus > 0
      AND l.tp_leito IN ('1', '2') -- Recorte cirúrgico e clínico
    GROUP BY
        l.competencia,
        l.cnes,
        l.gestao_munic,
        l.tp_leito
),

internacoes_agregadas AS (
    -- Agrupa as internações (ident='1') pelo tipo de leito equivalente via de-para
    SELECT
        i.competencia,
        i.cnes,
        dp.tp_leito,
        COUNT(DISTINCT i.n_aih)::INTEGER AS total_internacoes_sih,
        COALESCE(SUM(i.dias_perm), 0)::INTEGER AS total_dias_ocupados
    FROM fato_internacoes i
    INNER JOIN de_para_especialidade_leito dp
        ON i.espec = dp.espec
    WHERE i.ident = '1'
      AND i.dias_perm IS NOT NULL
    GROUP BY
        i.competencia,
        i.cnes,
        dp.tp_leito
),

calculo_ocupacao AS (
    SELECT
        l.competencia,
        l.cnes,
        dim.nome_estabelecimento AS unidade,
        dim.municipio,
        dtl.categoria AS tipo_leito,
        
        l.leitos_sus_cadastrados,
        l.dias_no_mes,
        (l.leitos_sus_cadastrados * l.dias_no_mes) AS leitos_dia_disponiveis,
        
        COALESCE(i.total_internacoes_sih, 0) AS total_internacoes_sih,
        COALESCE(i.total_dias_ocupados, 0) AS total_dias_ocupados,

        -- Calculo percentual da Taxa de Ocupação Hospitalar
        ROUND(
            100.0 * COALESCE(i.total_dias_ocupados, 0) / 
            NULLIF(l.leitos_sus_cadastrados * l.dias_no_mes, 0),
            2
        ) AS taxa_ocupacao_pct

    FROM leitos_agregados l

    INNER JOIN dim_estabelecimento dim
        ON l.cnes = dim.cnes 
       AND l.competencia = dim.competencia

    LEFT JOIN dom_tipo_leito dtl
        ON l.tp_leito = dtl.tp_leito

    LEFT JOIN internacoes_agregadas i
        ON l.cnes = i.cnes 
       AND l.competencia = i.competencia
       AND l.tp_leito = i.tp_leito

    WHERE dim.nome_estabelecimento IS NOT null AND l.gestao_munic = 1
)

SELECT
    competencia,
    cnes,
    unidade,
    municipio,
    tipo_leito,
    leitos_sus_cadastrados,
    total_internacoes_sih,
    total_dias_ocupados,
    leitos_dia_disponiveis,
    taxa_ocupacao_pct,

    -- Classificação conforme as faixas de ocupação estabelecidas
    CASE 
        WHEN taxa_ocupacao_pct < 70.0 THEN 'Ociosidade Severa (Abaixo de 70%)'
        WHEN taxa_ocupacao_pct BETWEEN 70.0 AND 74.99 THEN 'Ociosidade (70% a 75%)'
        WHEN taxa_ocupacao_pct BETWEEN 75.0 AND 85.00 THEN 'Saudável (75% a 85%)'
        WHEN taxa_ocupacao_pct > 85.0 THEN 'Risco de Sobrecarga (Acima de 85%)'
        ELSE 'Sem Produção / Dado Indisponível'
    END AS faixa_ocupacao

FROM calculo_ocupacao

ORDER by
	competencia,
	cnes,
    taxa_ocupacao_pct ASC,
    leitos_sus_cadastrados DESC;
