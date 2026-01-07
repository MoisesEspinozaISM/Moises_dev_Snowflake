with negocio as (
    SELECT
    llave, 
    periodo, 
    centro, 
    "COD.MAT" AS id_sku, 
    canal, 
    sum("LITROS VENTA") as litros_venta_do, 
    sum("VENTAS NETAS") as ventas_netas_do -- select distinct PERIODO
    FROM STAGING_CORP.SHAREPOINT.VENTAS_DO_NEGOCIO limit 10
    group by 
    llave, 
    periodo,
    centro,
    "COD.MAT",
    canal
),
sap as( 
    SELECT
    concat(periodo,'-',centro,'-',sku, '-',canal) as llave, 
    periodo, 
    centro, 
    sku as id_sku, 
    canal, 
    sum(litros) as litros_sap, 
    sum(MONTO_NETO_DOCUMETO) AS Venta_netas_sap, 
    pstyv, 
    tipo_venta
    FROM STAGING_CORP.SHAREPOINT.VENTAS_DO_SAP_2
    group by 
    llave, 
    periodo, 
    centro, 
    id_sku, 
    canal, 
    pstyv, 
    tipo_venta
),
fulljoin as ( 
    select 
    coalesce(n.llave, s.llave) as llave, 
    n.llave as llave_do, 
    s.llave as llave_sap, 
    coalesce(n.periodo, s.periodo) as periodo, 
    coalesce(n.centro, s.centro) as centro, 
    coalesce(n.id_sku, s.id_sku) as id_sku, 
    n.litros_venta_do as litros_venta_do, 
    s.litros_sap as litros_sap, 
    coalesce(s.litros_sap,0) - coalesce(n.litros_venta_do,0) as diferencia_litros_sap_do,
    n.ventas_netas_do as ventas_netas_do, 
    s.Venta_netas_sap as Ventas_netas_sap, 
    coalesce(s.Venta_netas_sap,0) - coalesce(n.ventas_netas_do,0) as diferencia_ventas_sap_do,
    CASE 
        WHEN n.llave IS NOT NULL THEN 1 ELSE 0 
    END AS flag_paul,  
    CASE 
        WHEN s.llave IS NOT NULL THEN 1 ELSE 0 
    END AS flag_sap, 
    s.tipo_venta, 
    s.pstyv 
    from negocio n  
    full outer join sap s 
    on n.llave = s.llave
)
select 
    llave, 
    llave_do,
    llave_sap,
    periodo, 
    centro,
    id_sku, 
    litros_venta_do, 
    litros_sap, 
    diferencia_litros_sap_do, 
    ventas_netas_do, 
    Ventas_netas_sap, 
    diferencia_ventas_sap_do, 
    case 
        when flag_paul = 1 and flag_sap = 1 then '01.Coincidencia'
        when flag_paul = 1 and flag_sap = 0 then '02.Solo DO'
        when flag_paul = 0 and flag_sap = 1 then '03.Solo SAP'
        ELSE '04.Error'
    end as tipo_registro,
    tipo_venta,
    pstyv
    from fulljoin 
; 

SELECT * FROM STAGING_CORP.SHAREPOINT.VENTAS_DO_NEGOCIO 
LIMIT 100; 

SELECT * FROM STAGING_CORP.SHAREPOINT.VENTAS_DO_SAP
LIMIT 1; 

SELECT * FROM STAGING_CORP.SHAREPOINT.VENTAS_DO_STAGING_SNOW
LIMIT 1; 

SELECT * FROM SAP



