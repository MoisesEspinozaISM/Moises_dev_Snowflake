DESC TABLE STAGING_PE_CH.SQL_FABRIC.RUTA;

SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM STAGING_PE_CH.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SQL_FABRIC'
  AND TABLE_NAME = 'CANAL'
ORDER BY ORDINAL_POSITION;


// AGREGAR NUEVA COLUMNA 
ALTER TABLE STAGING_PE_CH.SQL_FABRIC.CANAL
ADD COLUMN CANALGESTION TEXT
,NEGOCIO2 TEXT
,DSNEGOCIO TEXT
,CANALCORP TEXT
,SUBCANAL2 TEXT
;


SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM STAGING_PE_CH.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SQL_FABRIC'
  AND TABLE_NAME = 'CLIENTE'
ORDER BY ORDINAL_POSITION;

ALTER TABLE STAGING_PE_CH.SQL_FABRIC.CLIENTE
ADD COLUMN STRETIRADO_HIST TEXT;

; 

SELECT 
  ID_SKU_ORIGEN,
  UNIDADES_X_PQT
FROM DEV_SILVER_M.COMERCIAL.SILVER_MAESTRO_PRODUCTO
WHERE SISTEMA_ORIGEN = 'SAP-HANNA'
  AND ID_PAIS = 'DO'
  AND UNIDADES_X_PQT = 0
  and id_tipo_material = 'ZFER';

SELECT 
  *
FROM DEV_SILVER_M.COMERCIAL.SILVER_MAESTRO_PRODUCTO
WHERE ID_SKU_ORIGEN IN ('000000000000010214', '000000000000010212','000000000000010211' )

; 



SELECT *
FROM STAGING_MANAGEMENT.INTEGRATIONS.MONITOREO_INGESTA_STAGING
WHERE CAST(fec_actualizacion_reporte AS DATE) = '2025-12-17'
order by nombre_tabla asc; 
-- tomapedidos 
-- venta_intercompañia 
-- venta progrmada 
; 
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY nombre_tabla
               ORDER BY fec_actualizacion_reporte DESC
           ) AS rn
    FROM STAGING_MANAGEMENT.INTEGRATIONS.MONITOREO_INGESTA_STAGING
    WHERE CAST(fec_actualizacion_reporte AS DATE) = '2025-12-17'
)
WHERE rn = 1
ORDER BY nombre_tabla ASC;

; 
-- TOMAPEDIDOS : 2 066 377
-- VENTA_INTERCOPALIA : 896 057
-- VENTA_INTERCOPALIA : 94 194
; 

select distinct idfecha, count(*) from staging_pe_ch.sql_fabric.stock
group by idfecha
order by idfecha asc; 

select distinct idFePedido, count(*) from staging_pe_ch.sql_fabric.fillrate_d2
group by idFePedido
order by idFePedido asc; 

select distinct idFePedido, count(*) from staging_pe_ch.sql_fabric.otif
group by idFePedido
order by idFePedido asc; 

select distinct idFechaPedido, count(*) from staging_pe_ch.sql_fabric.venta_programada
group by idFechaPedido
order by idFechaPedido asc; 

select distinct idFePedido, count(*) from staging_pe_ch.sql_fabric.tomapedidos
group by idFePedido
order by idFePedido asc; 

SELECT COUNT(*) FROM staging_pe_ch.sql_fabric.tomapedidos; 

select distinct idFeContabilizacion, count(*) from staging_pe_ch.sql_fabric.venta_rechazada
group by idFeContabilizacion
order by idFeContabilizacion asc; 

select distinct idFeContabilizacion, count(*) from staging_pe_ch.sql_fabric.ventaintercompania
group by idFeContabilizacion
order by idFeContabilizacion asc; 

  
  SELECT S.Region,
	COUNT(Distinct IdCliente)
	FROM STAGING_PE_CH.SQL_FABRIC.CLIENTE C 
    LEFT JOIN Dim_Sede S ON C.Sede = S.Sede
	LEFT JOIN Dim_Ruta R ON C.idRuta = R.IdRuta
	LEFT JOIN Dim_Canal I ON I.idCSG=C.idCSG
	WHERE StRetirado='F' AND Bloqueado='F'
	GROUP BY S.Region

  ; 
  SELECT S.Region,
	COUNT(Distinct IdCliente)
	FROM STAGING_PE_CH.SQL_FABRIC.CLIENTE C 
  LEFT JOIN STAGING_PE_CH.SQL_FABRIC.SEDE S ON TRIM(C.Sede) = TRIM(S.Sede)
	LEFT JOIN STAGING_PE_CH.SQL_FABRIC.RUTA R ON C.idRuta = R.IdRuta
	LEFT JOIN STAGING_PE_CH.SQL_FABRIC.CANAL I ON I.idCSG=C.idCSG
	WHERE C.stRetirado ='F' AND C.Bloqueado='F'
	GROUP BY S.Region
  ORDER BY S.REGION
  -- 218 504
  -- 218 504