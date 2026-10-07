CREATE OR REPLACE view vw_01_capacidade_instalada_2 AS
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
)

SELECT
    l.competencia,
    l.mes,
    l.inicio_mes,
    l.fim_mes,
    l.cnes,
    COALESCE(u.nome_estabelecimento, 'CNES: ' || l.cnes) AS unidade,
    l.tp_leito,
    COALESCE(t.categoria, 'Não especificado')            AS tipo_leito,
    l.leitos_existentes,
    l.leitos_sus,
    case WHEN competencia = MAX(competencia) OVER ()
    	THEN 'Sim' ELSE 'Não'
    END AS competencia_atual -- 'Sim' só nas linhas do último mês
FROM leitos l
LEFT JOIN unidades u ON l.cnes = u.cnes
LEFT JOIN tipos t    ON l.tp_leito = t.tp_leito
ORDER BY l.inicio_mes, unidade, l.tp_leito;