WITH sap AS (
    SELECT
        PERIODO,
        PSTYV,
        TIPO_VENTA,
        SKU,
        CANAL,
        CENTRO,
        SUM(LITROS)                       AS litros_sap,
        SUM(UNIDADES)                     AS unidades_sap,
        SUM(MONTO_NETO_DOCUMETO)     AS monto_sap
    FROM STAGING_CORP.SHAREPOINT.VENTAS_DO_SAP_2
    GROUP BY
        PERIODO, PSTYV, TIPO_VENTA, SKU, CANAL, CENTRO
),
VENTAS_DO_STAGING_SNOW as (
        SELECT
        TO_CHAR(TO_DATE(VBRK.FKDAT, 'YYYY-MM-DD'), 'YYYYMM') AS PERIODO,
        VBRP.PSTYV                                          AS PSTYV,
        CASE
            WHEN VBRP.PSTYV IN ('TAN', 'ZTAD', 'TAQ', 'KEN', 'ZBTA')
                THEN 'VENTA BRUTA'
            WHEN VBRP.PSTYV IN ('ZG2N', 'ZG3N')
                THEN 'RECHAZO'
            WHEN VBRP.PSTYV IN ('TANN','ZTND')
                THEN 'BONIFICACIONES'
            ELSE 'OTROS'
        END                                                      AS TIPO_VENTA,
        VBRP.MATNR                                               AS SKU,
        VBRK.VTWEG                                               AS CANAL,
        VBRK.VKORG                                               AS CENTRO,
        CASE 
            WHEN VBRP.VOLEH = 'ML' THEN SUM(VBRP.VOLUM/1000)
            WHEN VBRP.VOLEH = 'L' THEN SUM(VBRP.VOLUM)
            ELSE 0
        END AS LITROS,
        SUM(VBRP.FKLMG) AS UNIDADES, 
        SUM(VBRP.NETWR) AS MONTO_NETO_DOCUMENTO
        FROM  STAGING_RD_HT_GT.SAP.VBRP AS VBRP
        INNER JOIN  STAGING_RD_HT_GT.SAP.VBRK AS VBRK
        ON VBRK.VBELN = VBRP.VBELN
        WHERE VBRK.BUKRS IN ('1000')
        AND VBRK.FKDAT BETWEEN '2025-01-01' AND '2025-12-31'
        GROUP BY
            TO_CHAR(TO_DATE(VBRK.FKDAT, 'YYYY-MM-DD'), 'YYYYMM'),
            VBRP.PSTYV,
            VBRP.MATNR,
            VBRK.VTWEG,
            VBRK.VKORG,
            VBRP.VOLEH
),
snow AS (
    SELECT
        PERIODO,
        PSTYV,
        TIPO_VENTA,
        SKU,
        CANAL,
        CENTRO,
        SUM(LITROS)                       AS litros_snow,
        SUM(UNIDADES)                     AS unidades_snow,
        SUM(MONTO_NETO_DOCUMENTO)     AS monto_snow
    FROM VENTAS_DO_STAGING_SNOW
    GROUP BY
        PERIODO, PSTYV, TIPO_VENTA, SKU, CANAL, CENTRO
),
comparacion AS (
    SELECT
        -- Llave
        COALESCE(sap.PERIODO,   snow.PERIODO)    AS PERIODO,
        COALESCE(sap.PSTYV,     snow.PSTYV)      AS PSTYV,
        COALESCE(sap.TIPO_VENTA,snow.TIPO_VENTA) AS TIPO_VENTA,
        COALESCE(sap.SKU,       snow.SKU)        AS SKU,
        COALESCE(sap.CANAL,     snow.CANAL)      AS CANAL,
        COALESCE(sap.CENTRO,    snow.CENTRO)     AS CENTRO,
        -- Métricas de SAP
        sap.litros_sap,
        sap.unidades_sap,
        sap.monto_sap,
        -- Métricas de STAGING_SNOW
        snow.litros_snow,
        snow.unidades_snow,
        snow.monto_snow,
        -- Diferencias
        COALESCE(snow.litros_snow,   0) - COALESCE(sap.litros_sap, 0) AS diff_litros,
        COALESCE(snow.unidades_snow, 0) - COALESCE(sap.unidades_sap, 0) AS diff_unidades,
        COALESCE(snow.monto_snow,    0) - COALESCE(sap.monto_sap,  0) AS diff_monto
    FROM sap
    FULL OUTER JOIN snow
        ON  sap.PERIODO    = snow.PERIODO
        AND sap.PSTYV      = snow.PSTYV
        AND sap.TIPO_VENTA = snow.TIPO_VENTA
        AND sap.SKU        = snow.SKU
        AND sap.CANAL      = snow.CANAL
        AND sap.CENTRO     = snow.CENTRO
)

SELECT
    *
FROM comparacion
WHERE
    PERIODO BETWEEN '202501' AND '202512'
    -- Diferencia en algún valor numérico
    AND diff_litros   <> 0
    OR diff_unidades <> 0
    OR diff_monto    <> 0
    -- O bien registros que existen solo en una tabla
    OR litros_sap   IS NULL AND litros_snow   IS NOT NULL
    OR litros_sap   IS NOT NULL AND litros_snow   IS NULL
ORDER BY
    PERIODO,
    CENTRO,
    CANAL,
    SKU;
