SELECT
    fl.competencia,
    fl.cnes,
    dim.nome_estabelecimento AS unidade,
    tl.categoria AS tipo_leito,
    SUM(fl.qt_exist) AS leitos_existentes,
    SUM(fl.qt_sus) AS capacidade_sus
FROM fato_leitos fl
LEFT JOIN dom_tipo_leito tl
    ON fl.tp_leito = tl.tp_leito
LEFT JOIN dim_estabelecimento dim 
    ON dim.cnes = fl.cnes 
    AND dim.competencia = fl.competencia -- Adicione a competência se dim_estabelecimento for mensal
WHERE dim.nome_estabelecimento IS NOT null and fl.gestao_munic = 1
GROUP BY
    fl.competencia,
    fl.cnes,
    tl.categoria,
    dim.nome_estabelecimento
ORDER BY
    fl.cnes,
    fl.competencia ASC;
