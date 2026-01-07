select * from dev_silver_m.comercial.silver_ventas_sap limit 10; 

select distinct clase_factura, tipo_posicion, NOM_TIPO_POSICION
from dev_silver_m.comercial.silver_ventas_sap
 where id_pais = 'HT' 
 and id_sociedad_origen ='7000' 
 and periodo ='202510'
 and clase_factura in ('ZP71','ZP73','ZP74', 'ZD71')
 AND tipo_posicion IN ('TAN', 'ZG2N')
 and estado_liquidacion not in ('NA')
 -- TANN : Bonificacion 
 -- ZRGR : Rechazo de Bonificaciones 
 ORDER BY clase_factura, tipo_posicion ASC
 ; 

/*  QUERY COMPRACION  */
select 
id_factura,
id_sku_origen, 
case 
    when clase_factura in ('ZP71','ZP73','ZP74') then pqt_matcat
    when clase_factura = 'ZD71' then -1 * pqt_matcat
    else 0
end as pqt_matcat
from dev_silver_m.comercial.silver_ventas_sap
 where id_pais = 'HT' 
 and id_sociedad_origen = '7000' 
 and periodo = '202510'
--  and id_canal = '30'
 and clase_factura in ('ZP71','ZP73','ZP74', 'ZD71')
 AND tipo_posicion IN ('TAN', 'ZG2N')
 and estado_liquidacion not in ('NA')
 AND FLAG_FACTURA_ANULADA <> 'X'
 AND MONTO_NETO_MONEDA_LOCAL <> 0
--  and id_factura_referencia not in (
--     select distinct id_factura_referencia 
--     from dev_silver_m.comercial.silver_ventas_sap
--     where estado_liquidacion ='RT'
-- )
;

////////////// QUERY CANAL ///////////////////// 
select 
ID_CANAL,
SUM(
    case 
        when clase_factura in ('ZP71','ZP73','ZP74') then pqt_matcat
        when clase_factura = 'ZD71' then -1 * pqt_matcat
        else 0
    end
 ) as pqt_matcat
from dev_silver_m.comercial.silver_ventas_sap
 where id_pais = 'HT' 
 and id_sociedad_origen = '7000' 
 and periodo = '202510'
 and clase_factura in ('ZP71','ZP73','ZP74', 'ZD71')
 AND tipo_posicion IN ('TAN', 'ZG2N')
--  AND FLAG_FACTURA_ANULADA <> 'X'
--  AND MONTO_NETO_MONEDA_LOCAL <> 0
--  and id_factura_referencia not in (
--     select distinct id_factura_referencia 
--     from dev_silver_m.comercial.silver_ventas_sap
--     where estado_liquidacion ='RT'
-- )
GROUP BY ID_CANAL
ORDER BY ID_CANAL ASC 
;

SELECT * FROM DEV_SILVER_M.COMERCIAL.SILVER_VENTAS_SAP
WHERE ID_FACTURA = '7122149538'; 

SELECT * FROM TEST_SILVER.COMERCIAL.SILVER_MAESTRO_PRODUCTO
WHERE ID_PAIS = 'HT'
AND ID_TIPO_MATERIAL = 'ZFER'
; 
WHERE ID_SKU_ORIGEN = '000000000000010571';
-- 000000000000010571

SELECT * FROM STAGING_RD_HT_GT.SAP.BSEG LIMIT 10; 