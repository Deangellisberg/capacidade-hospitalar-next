CREATE OR REPLACE view vw_04_ociosidade_2 AS
SELECT fi.cnes,
       u.nome_estabelecimento,
       COUNT(DISTINCT (fi.n_aih, fi.cnes, fi.dt_inter)) FILTER (WHERE dp.tp_leito IN ('1','2')) AS aih_no_recorte,
       COUNT(DISTINCT (fi.n_aih, fi.cnes, fi.dt_inter)) FILTER (WHERE dp.tp_leito IS NULL)      AS aih_fora,
       ROUND(100.0 * COUNT(DISTINCT (fi.n_aih, fi.cnes, fi.dt_inter)) FILTER (WHERE dp.tp_leito IS NULL)
             / COUNT(DISTINCT (fi.n_aih, fi.cnes, fi.dt_inter)), 1)                            AS pct_fora
FROM fato_internacoes fi
LEFT JOIN de_para_especialidade_leito dp ON fi.espec = dp.espec
LEFT JOIN (SELECT DISTINCT ON (cnes) cnes, nome_estabelecimento
           FROM dim_estabelecimento
           WHERE nome_estabelecimento IS NOT NULL
           ORDER BY cnes, competencia DESC) u ON u.cnes = fi.cnes
WHERE fi.ident = '1'
  AND fi.dt_inter BETWEEN DATE '2024-06-01' AND DATE '2026-05-31'
  AND EXISTS (
      SELECT 1
      FROM fato_leitos fl
      WHERE fl.cnes = fi.cnes
        AND fl.gestao_munic = 1
        AND fl.tp_leito IN ('1', '2')
        AND fl.competencia = TO_CHAR(fi.dt_inter, 'YYYYMM')
  )
GROUP BY fi.cnes, u.nome_estabelecimento
ORDER BY pct_fora DESC;