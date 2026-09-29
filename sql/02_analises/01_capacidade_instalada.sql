-- Apresenta a capacidade instalada por tipo de leito ao longo período

SELECT
    fl.competencia,
    tl.categoria AS tipo_leito,
    SUM(fl.qt_exist) AS leitos_existentes,
    SUM(fl.qt_sus) AS leitos_sus
FROM fato_leitos fl
LEFT JOIN dom_tipo_leito tl
    ON fl.tp_leito = tl.tp_leito
GROUP BY
    fl.competencia,
    tl.categoria
ORDER BY
    fl.competencia,
    tl.categoria;





