select * from dev_silver_m.comercial.silver_ventas_sap
WHERE ID_PAIS = 'HT' 
limit 10; 

/* 
ZTSD_NETO - Ventas Netas  
ZP(-) VENTAS Y BONIFICACIONES 
ZD(-) RECHAZOS (VENTAS Y BONIFICACIOES )
ZG(-) GRATUITOS 

ZTSD_RLIQ - REPORTE DE LIQUIDACIONES EN CAJA 
 */


// OK /////////////////// VALIDACION DE FACTURA ESPECIFICA ////////////////////////////////// 
SELECT * FROM dev_silver_m.comercial.silver_ventas_sap 
WHERE ID_FACTURA = '7122160658'
-- AND TIPO_POSICION = 'TAN'
;

///////////////////////// TABLA EXCEL DEL NEGOCIO ////////////////////////////////// 
SELECT * FROM STAGING_CORP.SHAREPOINT.VENTAS_HT_OCTUBRE_NEGOCIO LIMIT 10; 

SELECT * FROM STAGING_CORP.SHAREPOINT.VENTAS_HT_OCTUBRE_NEGOCIO 
where factura = '7122160658'; 

SELECT DISTINCT "CANT.DEV", "DEVOLUCIÓN" FROM STAGING_CORP.SHAREPOINT.VENTAS_HT_OCTUBRE_NEGOCIO; 
-- UM 
-- CANT.DEV : Si tenemos datos 
-- "DEVOLUCIÓN" : si se tiene a traves de Numero y PQT 
-- "BONIF." : Vacio 
-- TEXTO  : Vacio 
SELECT
"ORG." AS ID_CENTRO_ORIGEN, 
FACTURA AS ID_FACTURA, 
TIPO AS CLASE_FACTURA, 
"C.PAGO" AS CONDICION_PAGO, 
CANAL AS ID_CANAL,
"COD.MAT" AS ID_SKU,
CLIENTE AS ID_CLIETE,
CANTIDAD AS PQT, -- TAMBIEN VIENE RECHAZOS EN NEGATIVO 
--"CANT.DEV" AS PQT_RECHAZADOS,
"IMP.FACTURA" AS MONTO_FACTURA
FROM STAGING_CORP.SHAREPOINT.VENTAS_HT_OCTUBRE_NEGOCIO 
;

SELECT 
ID_CENTRO_ORIGEN, 
ID_FACTURA, 
CLASE_FACTURA, 
ID_CONDICION_DE_PAGO, 
ID_CANAL, 
LTRIM(ID_SKU_ORIGEN,0), 
ID_CLIENTE_ORIGEN, 
PQT_MATCAT, -- PQT SAP 
PQT_CALCULADOS_SNOW, -- PAQUETE CALCULADO 
MONTO_NETO_MONEDA_LOCAL, 
TIPO_POSICION, 
ID_TIPO_MATERIAL, 
TIPO_DOCUMENTO_COMERCIAL
FROM dev_silver_m.comercial.silver_ventas_sap 
WHERE ID_PAIS = 'HT'
AND ID_SOCIEDAD_ORIGEN = '7000'
AND PERIODO = '202510'
; 

//////////// ANALISIS DE FACTURA //////////////////// 

/////////// AMBOS ////////////////////// 
/*
FILTROS 
CLASE_FACTURA IN ('ZP71', 'ZP73', 'ZP74')

 */

SELECT 
ID_CENTRO_ORIGEN,
ID_FACTURA,
CLASE_FACTURA,
ID_CONDICION_DE_PAGO AS ID_CONDICION_PAGO,
ID_CANAL,
LTRIM(ID_SKU_ORIGEN, '0') AS ID_SKU,
ID_CLIENTE_ORIGEN AS ID_CLIENTE,qq
PQT_MATCAT AS PQT,
PQT_CALCULADOS_SNOW as PQT_CALCULADOS_SNOW, 
MONTO_NETO_MONEDA_LOCAL AS MONTO,
TIPO_POSICION,
ID_TIPO_MATERIAL,
TIPO_DOCUMENTO_COMERCIAL
FROM dev_silver_m.comercial.silver_ventas_sap 
WHERE ID_FACTURA = '7115332140'
--AND TIPO_POSICION = 'TANN'
AND ID_SKU_ORIGEN LIKE '%10154'
AND ID_CLIENTE_ORIGEN LIKE '%208118'
;

SELECT
"ORG." AS ID_CENTRO_ORIGEN, 
FACTURA AS ID_FACTURA, 
TIPO AS CLASE_FACTURA, 
"C.PAGO" AS CONDICION_PAGO, 
CANAL AS ID_CANAL,
"COD.MAT" AS ID_SKU,
CLIENTE AS CLIENTE,
CANTIDAD AS PQT, -- TAMBIEN VIENE RECHAZOS EN NEGATIVO 
UM AS UNIDAD, 
"CANT.DEV" AS PQT_RECHAZADOS,
"BONIF." AS BONIFICACIONES,
"IMP.FACTURA" AS MONTO_FACTURA,
MONEDA AS MONEDA
FROM STAGING_CORP.SHAREPOINT.VENTAS_HT_OCTUBRE_NEGOCIO  
WHERE FACTURA = '7115332140'
AND TIPO = 'ZP71'
AND CLIENTE = '208118'
AND "COD.MAT" = '10154'
; 


///////////////////// HACIENDO QUERY SOLO A NIVEL DE FACTURA PARA VER DIFERENCIAS /////////////////////// 

WITH excel AS (
    SELECT
        FACTURA       AS ID_FACTURA,
        TIPO          AS CLASE_FACTURA,
        "COD.MAT"     AS ID_SKU,
        CANTIDAD      AS PQT,
        "IMP.FACTURA" AS MONTO
    FROM STAGING_CORP.SHAREPOINT.VENTAS_HT_OCTUBRE_NEGOCIO
),
sap AS (
    select 
    id_factura as id_factura,
    clase_factura , 
    id_sku_origen as id_sku,  
    case 
        when clase_factura in ('ZP71','ZP73','ZP74') then pqt_matcat
        when clase_factura = 'ZD71' then -1 * pqt_matcat
        else 0
    end as pqt,
    MONTO_NETO_MONEDA_LOCAL AS MONTO
    from dev_silver_m.comercial.silver_ventas_sap
    where id_pais = 'HT' 
    and id_sociedad_origen = '7000' 
    and periodo = '202510'
    and clase_factura in ('ZP71','ZP73','ZP74', 'ZD71')
    AND tipo_posicion IN ('TAN', 'ZG2N')
)
SELECT
    COALESCE(e.ID_FACTURA, s.ID_FACTURA) AS ID_FACTURA,
    COALESCE(e.CLASE_FACTURA, s.CLASE_FACTURA) AS CLASE_FACTURA,
    COALESCE(e.ID_SKU,       s.ID_SKU)       AS ID_SKU,
    COALESCE(e.PQT,         0) AS PQT_EXCEL,
    COALESCE(s.PQT,         0) AS PQT_SAP,
    COALESCE(e.MONTO,       0) AS MONTO_EXCEL, 
    COALESCE(s.MONTO,       0) AS MONTO_SAP,
    -- CASE DE VALIDACIO 
    CASE 
        WHEN e.ID_FACTURA IS NOT NULL 
        AND S.ID_FACTURA IS NOT NULL  
        THEN 'MATCH_EN_AMBOS'

        WHEN e.ID_FACTURA IS NOT NULL
        AND  s.ID_FACTURA IS NULL
        THEN 'SOLO_EN_EXCEL'

        WHEN s.ID_FACTURA IS NOT NULL
        AND e.ID_FACTURA IS NULL
        THEN 'SOLO_EN_SAP'

        ELSE 'SIN_CLASIFICAR'
    END AS COMPARACION
FROM excel e
FULL OUTER JOIN sap s
on s.ID_FACTURA = e.ID_FACTURA
and s.ID_SKU = e.ID_SKU
; 
/////////////// solo facturas /// 
WITH EXCEL AS (    
    SELECT DISTINCT
        FACTURA   AS ID_FACTURA_EXCEL
    FROM STAGING_CORP.SHAREPOINT.VENTAS_HT_OCTUBRE_NEGOCIO
), 
SAP AS (
    select DISTINCT
    id_factura as id_factura_snow
    from dev_silver_m.comercial.silver_ventas_sap
    where id_pais = 'HT' 
    and id_sociedad_origen = '7000' 
    and periodo = '202510'
    and clase_factura in ('ZP71','ZP73','ZP74', 'ZD71')
    AND tipo_posicion IN ('TAN', 'ZG2N')
    and estado_liquidacion not in ('NA')
)
SELECT * 
FROM EXCEL E 
LEFT JOIN SAP S 
ON S.id_factura_snow = E.ID_FACTURA_EXCEL 
WHERE S.id_factura_snow IS NULL
-- FROM SAP S 
-- LEFT JOIN  EXCEL E 
-- ON  E.ID_FACTURA_EXCEL = S.id_factura_snow 
-- WHERE E.ID_FACTURA_EXCEL IS NULL

/////// vamoas a evaluar esto /// 
; 

SELECT 
FACTURA, 
CANAL, 
TIPO, 
"COD.MAT" AS ID_SKU,
CANTIDAD AS PQT
FROM STAGING_CORP.SHAREPOINT.VENTAS_HT_OCTUBRE_NEGOCIO 
where factura = '7115336108'
ORDER BY ID_SKU, PQT ASC; 

SELECT
ID_FACTURA, 
ID_CANAL,
CLASE_FACTURA, 
ID_SKU_ORIGEN AS ID_SKU,
PQT_MATCAT AS PQT, 
*
FROM dev_silver_m.comercial.silver_ventas_sap 
WHERE ID_FACTURA = '7115336108'
-- AND tipo_posicion IN ('TAN', 'ZG2N')
ORDER BY LTRIM(ID_SKU,0), PQT ASC;
-- AND ID_FACTURA_REFERENCIA = '7122159596'
;
SELECT *  FROM dev_silver_m.comercial.silver_ventas_sap 
WHERE ID_FACTURA = '7115336108';

SELECT 
VBRK.XBLNR AS vbrk_xblnr, 
VBRP.VBELN AS vbrp_vbeln,
VBRK.FKART, 
VBRK.VBTYP, 
VBRK.VTWEG, 
VBRP.POSNR, 
VBRP.PSTYV, 
VBRP.FKIMG AS CANTIDAD_facturada, 
VBRP.VRKME AS UNIDAD_FACTURADA, 
VBRK.FKSTO
FROM STAGING_RD_HT_GT.SAP.VBRK VBRK
INNER JOIN STAGING_RD_HT_GT.SAP.VBRP VBRP
ON VBRK.VBELN  = VBRP.VBELN
WHERE XBLNR = '7115336108'
;
    select 
    id_factura as id_factura,
    clase_factura , 
    id_sku_origen as id_sku,  
    case 
        when clase_factura in ('ZP71','ZP73','ZP74') then pqt_matcat
        when clase_factura = 'ZD71' then -1 * pqt_matcat
        else 0
    end as pqt,
    MONTO_NETO_MONEDA_LOCAL AS MONTO
    from dev_silver_m.comercial.silver_ventas_sap
    where id_pais = 'HT' 
    and id_sociedad_origen = '7000' 
    and periodo = '202510'
    and clase_factura in ('ZP71','ZP73','ZP74', 'ZD71')
    AND tipo_posicion IN ('TAN', 'ZG2N')
    and id_factura = '7115335256'

    ; 


    select * FROM dev_silver_m.comercial.silver_ventas_sap  limit 100; 
