-- SELECT RESUMEN GUATEMAL
SELECT BSEG.BUKRS AS "Sociedad",
    COALESCE(BSEG.WERKS, BSEG.BUKRS) AS "Centro",
    BSEG.BELNR AS "Documento Contable",
    VBRP.VBELN AS "Numero Faturas",
    VBRK.KUNAG AS "Cliente",
    VBRK.KUNRG AS "Respons. de Pago",
    T001W.NAME1 AS "Nombre Centro",
    BSEG.HKONT AS "Cuenta de Mayor",
    BSEG.GJAHR AS "Ejercicio",
    BKPF.MONAT AS "Período",
    TO_CHAR(BKPF.BUDAT, 'DD') AS "Dia",
    TO_DATE(BKPF.BUDAT) AS "FECHA",
    BSEG.KOSTL AS "Centro de Costo",
    BSEG.PRCTR AS "CeBe",
    VBRK.VTWEG AS "Canal",
    VBRK.FKART AS "TipoFactura",
    BSEG.MATNR AS "Codigo_material",
    MAKT.MAKTX AS "Descripcion_material",
    VBRP.POSNR AS "Posicion",
    CASE
        WHEN VBRP.PRSFD = 'X'
        AND SUM(
            CASE
                WHEN BSEG.SHKZG = 'H' THEN - BSEG.DMBTR
                ELSE BSEG.DMBTR
            END
        ) >= 0
        AND VBRP.PSTYV NOT IN ('ZG3N', 'ZG2N', 'G2N')
        AND BKPF.BLART <> 'AB'
        AND BSEG.MENGE <> 0 THEN 0
        WHEN BSEG.MENGE = 0 THEN 0
        WHEN BSEG.BSCHL = '50' THEN ROUND((VBRP.FKLMG / ZTSD_MATCAT.UN) * -1, 4)
        WHEN BSEG.BSCHL = '40' THEN ROUND((VBRP.FKLMG / ZTSD_MATCAT.UN), 4)
        ELSE 0
    END AS "Paquetes",
    SUM(
        CASE
            WHEN BSEG.SHKZG = 'H' THEN - BSEG.DMBTR
            ELSE BSEG.DMBTR
        END
    ) AS "Importe Total ML",
    -- Condicion = Venta, Descuento, Bonificacion o Bonificacion contra partida.
    CASE
        -- Descuento Facturas
        WHEN VBRP.PRSFD = 'X'
        AND SUM(
            CASE
                WHEN BSEG.SHKZG = 'H' THEN - BSEG.DMBTR
                ELSE BSEG.DMBTR
            END
        ) > 0 --AND VBRP.PSTYV NOT IN ('ZG3N', 'ZG2N','G2N')
        AND BKPF.BLART <> 'AB'
        AND VBRK.VBTYP <> 'O' THEN 'DESCUENTO' -- Descuento Notas de Creditos
        WHEN VBRP.PRSFD = 'X'
        AND SUM(
            CASE
                WHEN BSEG.SHKZG = 'H' THEN BSEG.DMBTR
                ELSE - BSEG.DMBTR
            END
        ) > 0 --AND VBRP.PSTYV NOT IN ('ZG3N', 'ZG2N','G2N')
        AND BKPF.BLART <> 'AB'
        AND VBRK.VBTYP = 'O' THEN 'DESCUENTO' -- Bonificaciones (con inversión si BLART ∈ ('H1','B1'))
        WHEN VBRP.PRSFD = 'B' THEN CASE
            WHEN SUM(
                CASE
                    WHEN BSEG.SHKZG = 'H' THEN - BSEG.DMBTR
                    ELSE BSEG.DMBTR
                END
            ) >= 0 THEN CASE
                WHEN VBRP.PSTYV IN ('ZHGR', 'ZRGR') THEN CASE
                    WHEN BKPF.BLART IN ('H1', 'B1', 'A1', 'C1') THEN 'BONIFICACION'
                    ELSE 'BONIFICACION CONTRA PARTIDA'
                END
                ELSE CASE
                    WHEN BKPF.BLART IN ('H1', 'B1', 'A1', 'C1') THEN 'BONIFICACION CONTRA PARTIDA'
                    ELSE 'BONIFICACION'
                END
            END
            ELSE -- Monto < 0
            CASE
                WHEN VBRP.PSTYV IN ('ZHGR', 'ZRGR') THEN CASE
                    WHEN BKPF.BLART IN ('H1', 'B1', 'A1', 'C1') THEN 'BONIFICACION CONTRA PARTIDA'
                    ELSE 'BONIFICACION'
                END
                ELSE CASE
                    WHEN BKPF.BLART IN ('H1', 'B1', 'A1', 'C1') THEN 'BONIFICACION'
                    ELSE 'BONIFICACION CONTRA PARTIDA'
                END
            END
        END -- Venta por PRSFD X y monto negativo
        WHEN VBRP.PRSFD = 'X'
        AND SUM(
            CASE
                WHEN BSEG.SHKZG = 'H' THEN - BSEG.DMBTR
                ELSE BSEG.DMBTR
            END
        ) <= 0 THEN 'VENTA' -- Venta por tipo de posición
        WHEN VBRP.PSTYV IN ('ZG3N', 'ZG2N', 'G2N') THEN 'VENTA'
        ELSE 'VENTA'
    END AS "Condicion",
    VBRP.PSTYV AS "Tipo de Bonificacion",
    BSEG.PSWSL AS "Moneda"
FROM SAPPRD.VBRK
    INNER JOIN SAPPRD.VBRP on VBRK.VBELN = VBRP.VBELN
    INNER JOIN SAPPRD.BKPF on VBRK.VBELN = BKPF.AWKEY
    INNER JOIN SAPPRD.BSEG ON BKPF.BELNR = BSEG.BELNR
    AND BKPF.GJAHR = BSEG.GJAHR
    AND VBRP.PAOBJNR = BSEG.PAOBJNR
    AND VBRP.MATNR = VBRP.MATNR
    LEFT JOIN SAPPRD.T001W ON BSEG.WERKS = T001W.WERKS
    LEFT JOIN SAPPRD.MAKT ON BSEG.MATNR = MAKT.MATNR
    AND MAKT.SPRAS = 'S'
    INNER JOIN SAPPRD.MARA ON MARA.MATNR = MAKT.MATNR
    INNER JOIN SAPPRD.ZTSD_MATCAT ON MARA.MATNR = ZTSD_MATCAT.MATNR
WHERE BSEG.BUKRS = 'C100'
    AND BSEG.HKONT IN ('7020100000', '7020200000', '7410100000')
    AND BKPF.BUDAT BETWEEN '20250901' AND '20250930'
    AND BKPF.XREVERSAL = ''
    AND VBRK.FKART IN ('S1', 'ZD40', 'ZP40', 'ZP99')
    AND VBRK.VTWEG != '91'
    AND VBRK.KUNRG NOT IN(
        'C101',
        'C102',
        'C103',
        'C104',
        'C105',
        'C106',
        'C107',
        '0000000101',
        '0000000102',
        '0000000103',
        '0000000104',
        '0000000105',
        '0000000106',
        '0000000107',
        '0300000000',
        'C300000000',
        '0000003000',
        '000000C101',
        '000000C102',
        '000000C103',
        '000000C104',
        '000000C105',
        '000000C106',
        '000000C107',
        '1600000000',
        '1600000016',
        '1600000020',
        '1600000011',
        '1600000025',
        '1600000030',
        '1600000031',
        '1600000032',
        '1600000033',
        '1600000034',
        '1600000041',
        '1300000172',
        '1300000190',
        '1300000195',
        '1300000198',
        '1300000199',
        '1300000206',
        '1300000218',
        '1300000236',
        '1300000238',
        '1300000239',
        '1300000240',
        '1300000331',
        '1300000340',
        '1300000341',
        '1300000342',
        '1300000343',
        '1300000018',
        '1300000024',
        '1300000028',
        '1300000052',
        '1300000078',
        '1300000094',
        '1300000104',
        '1300000162',
        '1300000165',
        '1300000196',
        '1300000259',
        '1300000266',
        '1300000292',
        '1300000300',
        '1300000308',
        '1300000316',
        '1300000320',
        '1300000335',
        '0500000038',
        '0500000133',
        '0500000137',
        '0500000138',
        '0500000140',
        '0500000142',
        '0500000170',
        '0500000260',
        '0500000402',
        '0500000507',
        '1300000061',
        '1300000081',
        '1200000100',
        '0003002584',
        '0002000001',
        '1900000000',
        '0600000000',
        '0800000005',
        '0700000000',
        '0200000000',
        '1300000270',
        '0700000010',
        '0700000006',
        '0700000005',
        '0700000020',
        '0800000061',
        '0800000014',
        '0800000033',
        '0800000002',
        '0800000001',
        '0800000000',
        '1300000350',
        '1300000299',
        '1300000071',
        '1300000402',
        '1300000381',
        '1300000314',
        '1300000154',
        '1300000101',
        '0003002585',
        '0500000624',
        '0500000662',
        '0500000649',
        '0500000646',
        '0500000089',
        '1500133250'
    )
GROUP BY BSEG.WERKS,
    BSEG.BUKRS,
    T001W.NAME1,
    BSEG.MATNR,
    MAKT.MAKTX,
    BKPF.BUDAT,
    ZTSD_MATCAT.UN,
    BSEG.BELNR,
    VBRP.VBELN,
    VBRK.KUNAG,
    VBRK.KUNRG,
    BSEG.HKONT,
    BSEG.GJAHR,
    BKPF.MONAT,
    BSEG.KOSTL,
    BSEG.PRCTR,
    VBRK.VTWEG,
    VBRK.FKART,
    BSEG.BSCHL,
    VBRP.FKLMG,
    VBRP.PRSFD,
    VBRP.PSTYV,
    BKPF.BLART,
    BSEG.PSWSL,
    VBRP.POSNR,
    BSEG.MENGE,
    BSEG.SHKZG,
    VBRK.VBTYP

    ; 

    SELECT 
    --SUM(CANTIDAD_VENDIDA_UN), -- SELECT *
    --SUM(CANTIDAD_RECHAZO_UN), 
    SUM(PQT_VENDIDOS), 
    SUM(PQT_RECHAZADOS), 
    SUM(PQT_NETOS)
    FROM TEST_SILVER.COMERCIAL.SILVER_VENTA_NETA_CORP 
    WHERE ID_PAIS = 'GT'
    AND ID_CENTRO_ORIGEN = 'C101'
    AND PERIODO = '202510'
    ;

    select * from 
    staging_rd_ht_gt.sap.mseg 
    where mblnr = '4980004127';