WITH base_supply AS (
    SELECT
        ID_PAIS,
COALESCE(
  TRY_TO_DATE(ENTREGADO_FECHA),                                  -- si ya es DATE/TIMESTAMP, entra aquí
  TRY_TO_DATE(TO_VARCHAR(ENTREGADO_FECHA)),                      -- autodetección sobre string
  TRY_TO_DATE(TO_VARCHAR(ENTREGADO_FECHA), 'YYYY-MM-DD'),
  TRY_TO_DATE(TO_VARCHAR(ENTREGADO_FECHA), 'YYYY/MM/DD'),
  TRY_TO_DATE(TO_VARCHAR(ENTREGADO_FECHA), 'DD/MM/YYYY'),
  TRY_TO_DATE(TO_VARCHAR(ENTREGADO_FECHA), 'YYYYMMDD')
) AS ENTREGADO_FECHA_DT,
 
        ENTREGADO_LITROS_VENDIDOS_NETOS
    FROM dev_gold_w.SUPPLY.GOLD_DISTRIBUCION_SECUNDARIA
),
agg_supply AS (
    SELECT
        ID_PAIS,
        TO_CHAR(DATE_TRUNC('MONTH', ENTREGADO_FECHA_DT), 'YYYYMM') AS PERIODO,
        SUM(ENTREGADO_LITROS_VENDIDOS_NETOS) AS ENTREGADO_LITROS_VENDIDOS_NETOS
    FROM base_supply
    WHERE ENTREGADO_FECHA_DT IS NOT NULL
    GROUP BY ID_PAIS, TO_CHAR(DATE_TRUNC('MONTH', ENTREGADO_FECHA_DT), 'YYYYMM')
),
 
/* ===================== SEED: tus valores imputados ===================== */
Valor_SEED AS (
    SELECT * FROM VALUES
    ('DO'     , '202501'   , '48290875'),
    ('DO'     , '202502'   , '43900970'),
    ('DO'     , '202503'   , '49611893'),
    ('DO'     , '202504'   , '48111835'),
    ('DO'     , '202505'   , '50701001'),
    ('DO'     , '202506'   , '48770912'),
    ('DO'     , '202507'   , '54486596'),
    ('DO'     , '202508'   , '56148616'),
    ('HT'     , '202501'   , '6209563'),
    ('HT'     , '202502'   , '7384618'),
    ('HT'     , '202503'   , '7437323'),
    ('HT'     , '202504'  , '8681086'),
    ('HT'     , '202505'   , '7831288'),
    ('HT'     , '202506'   , '7247496'),

    ('GT'     , '202501'   , '1575974'),
    ('GT'     , '202502'   , '1448498'),
    ('GT'     , '202503'   , '1725991'),
    ('GT'     , '202504'   , '1597668'),
    ('GT'     , '202505'   , '2031597'),
    ('GT'     , '202506'   , '1682445'),
    ('GT'     , '202507'   , '2431129')
    AS SEED(ID_PAIS, PERIODO, VALOR)
),
seed AS (
    SELECT
        ID_PAIS,
        LPAD(TO_VARCHAR(PERIODO), 6, '0') AS PERIODO,
        /* Limpia cualquier separador no numérico y convierte; '' -> NULL */
        TO_NUMBER(NULLIF(REGEXP_REPLACE(VALOR, '[^0-9]', ''), '')) AS LITROS_SEED
    FROM Valor_SEED
),
 
/* ===================== Comercial ===================== */
agg_comercial AS (
    SELECT
        ID_PAIS,
        LPAD(TO_VARCHAR(PERIODO), 6, '0') AS PERIODO,
        SUM(LITROS_VENDIDOS_NETOS) AS LITROS_VENDIDOS_NETOS
    FROM TEST_SILVER.SUPPLY.SILVER_VENTA_NETA_CORP_SUPPLY,
    GROUP BY ID_PAIS, LPAD(TO_VARCHAR(PERIODO), 6, '0')
),
 
/* ===================== Universo de periodos por país ===================== */
periodos AS (
    SELECT DISTINCT ID_PAIS, PERIODO FROM agg_supply
    UNION
    SELECT DISTINCT ID_PAIS, PERIODO FROM agg_comercial
    UNION
    SELECT DISTINCT ID_PAIS, PERIODO FROM seed
)
 
/* ===================== Tabla comparativa final ===================== */
SELECT
    p.ID_PAIS,
    p.PERIODO,
 
    /* Series base */
    s.ENTREGADO_LITROS_VENDIDOS_NETOS                AS D2_LTS,
    c.LITROS_VENDIDOS_NETOS                          AS COMERCIAL_LTS,
    se.LITROS_SEED                                   AS SEED_LTS,
 
    /* Comparativas: Supply vs Comercial */
    --(s.ENTREGADO_LITROS_VENDIDOS_NETOS - c.LITROS_VENDIDOS_NETOS) AS DIF_SUPPLY_VS_COMERCIAL,
    CASE
        WHEN c.LITROS_VENDIDOS_NETOS IS NOT NULL AND c.LITROS_VENDIDOS_NETOS <> 0
        THEN ROUND( (s.ENTREGADO_LITROS_VENDIDOS_NETOS - c.LITROS_VENDIDOS_NETOS) / c.LITROS_VENDIDOS_NETOS * 100, 2 )
        ELSE NULL
    END AS DIF_D2_VS_COMERCIAL_PCT,
 
    /* Comparativas: Supply vs SEED */
   -- (s.ENTREGADO_LITROS_VENDIDOS_NETOS - se.LITROS_SEED) AS DIF_SUPPLY_VS_SEED,
    CASE
        WHEN se.LITROS_SEED IS NOT NULL AND se.LITROS_SEED <> 0
        THEN ROUND( (s.ENTREGADO_LITROS_VENDIDOS_NETOS - se.LITROS_SEED) / se.LITROS_SEED * 100, 2 )
        ELSE NULL
    END AS DIF_D2_VS_SEED_PCT,
 
    /* Comparativas: Comercial vs SEED */
   -- (c.LITROS_VENDIDOS_NETOS - se.LITROS_SEED) AS DIF_COMERCIAL_VS_SEED,
    CASE
        WHEN se.LITROS_SEED IS NOT NULL AND se.LITROS_SEED <> 0
        THEN ROUND( (c.LITROS_VENDIDOS_NETOS - se.LITROS_SEED) / se.LITROS_SEED * 100, 2 )
        ELSE NULL
    END AS DIF_COMERCIAL_VS_SEED_PCT
 
FROM periodos p
LEFT JOIN agg_supply   s  ON p.ID_PAIS = s.ID_PAIS  AND p.PERIODO = s.PERIODO
LEFT JOIN agg_comercial c  ON p.ID_PAIS = c.ID_PAIS  AND p.PERIODO = c.PERIODO
LEFT JOIN seed         se ON p.ID_PAIS = se.ID_PAIS AND p.PERIODO = se.PERIODO
ORDER BY p.ID_PAIS, p.PERIODO;
;


///////////// PROD ///////////////////// 

SELECT 
ID_PAIS, 
PERIODO,
FECHA,
SUM(LITROS_VENDIDOS_NETOS) AS LITROS_TOTALES
FROM PROD_SILVER.COMERCIAL.SILVER_VENTA_NETA_CORP
WHERE PERIODO = '202510' --AND '202505'
GROUP BY ID_PAIS, PERIODO , FECHA
ORDER BY ID_PAIS, PERIODO, FECHA ASC; 


