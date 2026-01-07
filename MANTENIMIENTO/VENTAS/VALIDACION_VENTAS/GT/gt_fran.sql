select * from test_silver.comercial.silver_ventas_sap 
WHERE ID_PAIS = 'GT'
limit 100; 

SELECT 
SUM(cantidad_unidad_base), 
periodo
FROM test_silver.comercial.silver_ventas_sap 
where ID_PAIS = 'GT'
AND ID_SOCIEDAD_ORIGEN = 'C100'
AND periodo BETWEEN '202501' AND '202509'
-- AND ID_TIPO_MATERIAL = 'ZFER'
--AND ESTADO_LIQUIDACION <> 'NA'
GROUP BY periodo 
ORDER BY periodo asc 
;

SELECT 
SUM(VBRP.FKLMG) AS BOTELLAS_FACTAURAS, 
TO_CHAR(TO_DATE(VBRK.FKDAT, 'YYYY-MM-DD'), 'YYYYMM') AS PERIODO
FROM STAGING_RD_HT_GT.SAP.VBRK VBRK
LEFT JOIN STAGING_RD_HT_GT.SAP.VBRP VBRP 
ON VBRK.VBELN = VBRP.VBELN 
WHERE TO_CHAR(TO_DATE(VBRK.FKDAT, 'YYYY-MM-DD'), 'YYYYMM') >= '202501'
AND VBRK.BUKRS IN ('C100')
GROUP BY TO_CHAR(TO_DATE(VBRK.FKDAT, 'YYYY-MM-DD'), 'YYYYMM')
ORDER BY TO_CHAR(TO_DATE(VBRK.FKDAT, 'YYYY-MM-DD'), 'YYYYMM') ASC
;


//////////////////// AMBIENTE DEV MOISES V1 //////////////////// 
select * from dev_silver_m.comercial.silver_ventas_sap 
WHERE ID_PAIS = 'GT'
limit 1000; 

SELECT DISTINCT 
UNIDAD_FACTURADA,
ID_PAIS
FROM dev_silver_m.comercial.silver_ventas_sap
WHERE ID_PAIS = 'GT'
ORDER BY ID_PAIS

;
select distinct unidad_volumen from dev_silver_m.comercial.silver_ventas_sap; 

SELECT 
SUM(cantidad_unidad_base) as botellas_facturadas, 
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -PQT_CALCULADOS_SNOW
        ELSE PQT_CALCULADOS_SNOW
    END
) AS pqt_snowflake,
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -monto_neto_documento
        ELSE monto_neto_documento
    END
) AS monto_snowflake,
SUM(
CASE 
    WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -LITROS_CALCULADOS_SNOW
    ELSE LITROS_CALCULADOS_SNOW
END
) AS litros_snowflake, 
periodo
FROM dev_silver_m.comercial.silver_ventas_sap 
where ID_PAIS = 'GT'
AND ID_SOCIEDAD_ORIGEN = 'C100'
AND periodo BETWEEN '202501' AND '202509'
-- AND ID_TIPO_MATERIAL = 'ZFER'
GROUP BY periodo
ORDER BY periodo asc 
;

//////////////////// AMBIENTE DEV MOISES V222222 //////////////////// 

SELECT 
SUM(cantidad_unidad_base) as botellas_facturadas, 
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -pqt_matcat
        ELSE pqt_matcat
    END
) AS pqt_matcat,
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -monto_neto_documento
        ELSE monto_neto_documento
    END
) AS monto_snowflake,
SUM(
CASE 
    WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -LITROS_CALCULADOS_SNOW
    ELSE LITROS_CALCULADOS_SNOW
END
) AS litros_snowflake, 
periodo
FROM dev_silver_m.comercial.silver_ventas_sap 
where ID_PAIS = 'GT'
AND ID_SOCIEDAD_ORIGEN = 'C100'
AND periodo BETWEEN '202501' AND '202510'
GROUP BY periodo
ORDER BY periodo asc 
;

////////////////////////////// VAMOS REALIZANDO POR PERIDO - SKU ///////////////////// 

SELECT 
SUM(cantidad_unidad_base) as botellas_facturadas, 
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -pqt_matcat
        ELSE pqt_matcat
    END
) AS pqt_matcat,
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -PQT_CALCULADOS_SNOW
        ELSE PQT_CALCULADOS_SNOW
    END
) AS pqt_snowflake,
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -monto_neto_documento
        ELSE monto_neto_documento
    END
) AS monto_snowflake,
SUM(
CASE 
    WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -LITROS_CALCULADOS_SNOW
    ELSE LITROS_CALCULADOS_SNOW
END
) AS litros_snowflake, 
ID_SKU_ORIGEN,
NOM_SKU,
periodo
FROM dev_silver_m.comercial.silver_ventas_sap 
where ID_PAIS = 'GT'
AND ID_SOCIEDAD_ORIGEN = 'C100'
AND periodo = '202510' 
GROUP BY periodo, ID_SKU_ORIGEN,NOM_SKU
ORDER BY periodo, ID_SKU_ORIGEN asc 
;

////////////////////// VERSION EXTENDIDA /////// 
WITH VENTAS_GT_10 AS(
SELECT
ID_SOCIEDAD_ORIGEN, 
ID_CENTRO_ORIGEN, 
ID_CANAL, 
ID_SKU_ORIGEN,
NOM_SKU,
FECHA_FACTURA, 
SUM(
CASE 
    WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -pqt_matcat
    ELSE pqt_matcat
END
) AS pqt_matcat,
SUM(CANTIDAD_UNIDAD_BASE) AS BOTELLAS_FACTAURAS, 
SUM(
CASE 
    WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -monto_neto_documento
    ELSE monto_neto_documento
END
) AS monto_snowflake
FROM dev_silver_m.comercial.silver_ventas_sap 
where ID_PAIS = 'GT'
AND ID_SOCIEDAD_ORIGEN = 'C100'
-- and ID_SKU_ORIGEN = '000000000000010290'
-- and FECHA_FACTURA = '2025-10-28'
--and ID_CENTRO_ORIGEN = 'C102'
AND periodo = '202510' 
GROUP BY 1,2,3,4,5,6
ORDER BY ID_SOCIEDAD_ORIGEN, ID_CENTRO_ORIGEN, ID_CANAL, ID_SKU_ORIGEN, FECHA_FACTURA, NOM_SKU ASC
)
SELECT 
SUM(pqt_matcat),
SUM(monto_snowflake)
FROM VENTAS_GT_10
;

////////// 

SELECT 
SUM(cantidad_unidad_base) as botellas_facturadas, 
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -pqt_matcat
        ELSE pqt_matcat
    END
) AS pqt_matcat,
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -PQT_CALCULADOS_SNOW
        ELSE PQT_CALCULADOS_SNOW
    END
) AS pqt_snowflake,
SUM(
    CASE 
        WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -monto_neto_documento
        ELSE monto_neto_documento
    END
) AS monto_snowflake,
SUM(
CASE 
    WHEN TIPO_DOCUMENTO_COMERCIAL IN ('O','N') THEN -LITROS_CALCULADOS_SNOW
    ELSE LITROS_CALCULADOS_SNOW
END
) AS litros_snowflake, 
ID_SKU_ORIGEN,
NOM_SKU,
periodo
FROM dev_silver_m.comercial.silver_ventas_sap 
where ID_PAIS = 'GT'
AND ID_SOCIEDAD_ORIGEN = 'C100'
AND periodo = '202510' 
GROUP BY periodo, ID_SKU_ORIGEN,NOM_SKU
ORDER BY periodo, ID_SKU_ORIGEN asc 
;