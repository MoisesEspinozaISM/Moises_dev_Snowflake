WITH Ventas AS (
    SELECT 
        EXTRACT(
            MONTH FROM TO_DATE(TO_VARCHAR(V.idFeContabilizacion), 'YYYYMMDD')
        ) AS Mes,
        S.Region,
        SUM(V.Volumen_Venta) AS Litros, 
        SUM(V.Cajas_Venta)  AS Cajas
    FROM STAGING_PE_CH.SQL_FABRIC.VENTA V
    LEFT JOIN STAGING_PE_CH.SQL_FABRIC.PRODUCTOS P 
        ON TRIM(V.IDMATERIAL) = TRIM(P.IDPRODUCTO)
    LEFT JOIN STAGING_PE_CH.SQL_FABRIC.CO O 
        ON TRIM(O.IDDPT) = TRIM(V.IDDPT)
    LEFT JOIN STAGING_PE_CH.SQL_FABRIC.CLIENTE C 
        ON TRIM(V.IDCLIENTE) = TRIM(C.IDCLIENTE)
    LEFT JOIN STAGING_PE_CH.SQL_FABRIC.SEDE S 
        ON TRIM(C.SEDE) = TRIM(S.SEDE)
    WHERE 
        TO_DATE(TO_VARCHAR(V.idFeContabilizacion), 'YYYYMMDD') >= DATE '2025-01-01'
        -- AND TO_DATE(TO_VARCHAR(V.idFeContabilizacion), 'YYYYMMDD') <= DATE '2025-12-31'
        -- AND Pais = 'PE'
    GROUP BY 
        EXTRACT(
            MONTH FROM TO_DATE(TO_VARCHAR(V.idFeContabilizacion), 'YYYYMMDD')
        ),
        S.Region
)
SELECT 
    Region,

    -- ENERO
    SUM(CASE WHEN Mes = 1 THEN Litros ELSE 0 END) AS Ene_Litros,
    SUM(CASE WHEN Mes = 1 THEN Cajas ELSE 0 END)  AS Ene_Cajas,

    -- FEBRERO
    SUM(CASE WHEN Mes = 2 THEN Litros ELSE 0 END) AS Feb_Litros,
    SUM(CASE WHEN Mes = 2 THEN Cajas ELSE 0 END)  AS Feb_Cajas,

    -- MARZO
    SUM(CASE WHEN Mes = 3 THEN Litros ELSE 0 END) AS Mar_Litros,
    SUM(CASE WHEN Mes = 3 THEN Cajas ELSE 0 END)  AS Mar_Cajas,

    -- ABRIL
    SUM(CASE WHEN Mes = 4 THEN Litros ELSE 0 END) AS Abr_Litros,
    SUM(CASE WHEN Mes = 4 THEN Cajas ELSE 0 END)  AS Abr_Cajas,

    -- MAYO
    SUM(CASE WHEN Mes = 5 THEN Litros ELSE 0 END) AS May_Litros,
    SUM(CASE WHEN Mes = 5 THEN Cajas ELSE 0 END)  AS May_Cajas,

    -- JUNIO
    SUM(CASE WHEN Mes = 6 THEN Litros ELSE 0 END) AS Jun_Litros,
    SUM(CASE WHEN Mes = 6 THEN Cajas ELSE 0 END)  AS Jun_Cajas,

    -- JULIO
    SUM(CASE WHEN Mes = 7 THEN Litros ELSE 0 END) AS Jul_Litros,
    SUM(CASE WHEN Mes = 7 THEN Cajas ELSE 0 END)  AS Jul_Cajas,

    -- AGOSTO
    SUM(CASE WHEN Mes = 8 THEN Litros ELSE 0 END) AS Ago_Litros,
    SUM(CASE WHEN Mes = 8 THEN Cajas ELSE 0 END)  AS Ago_Cajas,

    -- SETIEMBRE
    SUM(CASE WHEN Mes = 9 THEN Litros ELSE 0 END) AS Sep_Litros,
    SUM(CASE WHEN Mes = 9 THEN Cajas ELSE 0 END)  AS Sep_Cajas,

    -- OCTUBRE
    SUM(CASE WHEN Mes = 10 THEN Litros ELSE 0 END) AS Oct_Litros,
    SUM(CASE WHEN Mes = 10 THEN Cajas ELSE 0 END)  AS Oct_Cajas,

    -- NOVIEMBRE
    SUM(CASE WHEN Mes = 11 THEN Litros ELSE 0 END) AS Nov_Litros,
    SUM(CASE WHEN Mes = 11 THEN Cajas ELSE 0 END)  AS Nov_Cajas,

    -- DICIEMBRE
    SUM(CASE WHEN Mes = 12 THEN Litros ELSE 0 END) AS Dic_Litros,
    SUM(CASE WHEN Mes = 12 THEN Cajas ELSE 0 END)  AS Dic_Cajas

FROM Ventas
GROUP BY Region
ORDER BY Region DESC;
