WITH
    movimientos AS (
        SELECT
            mseg.MANDT,
            mseg.MBLNR,
            mseg.MJAHR,
            mseg.ZEILE,
            mseg.MATNR AS id_producto,
            makt.MAKTX AS descp_producto,
            mseg.BUKRS AS id_sociedad,
            mseg.MEINS AS unidad_medida, -- Unidad base del material
            /* Origen (emisor) */
            mseg.WERKS AS werks_origen,
            mseg.LGORT AS lgort_origen,
            /* Destino (receptor) informado en el apunte emisor o en el tránsito */
            mseg.UMWRK AS werks_destino,
            mseg.UMLGO AS lgort_destino,
            /* Referencias logísticas (útiles para STO/delivery) */
            mseg.EBELN AS ebeln_sto,
            mseg.EBELP AS ebelp_sto,
            mseg.BWART,
            mseg.SHKZG,
            mseg.MENGE AS cantidad,
            mkpf.BUDAT AS fecha_documento,
            /* Estandarización: +crea tránsito, -liquida tránsito */
            CASE
                WHEN mseg.BWART IN ('641', '351', '313', '303') THEN + mseg.MENGE -- salida (emisor) -> genera tránsito
                WHEN mseg.BWART IN ('101', '315', '305') THEN - mseg.MENGE -- entrada (receptor) -> consume tránsito
                ELSE 0
            END AS qty_efecto
        FROM
            SAPPRD.MSEG AS mseg
            INNER JOIN SAPPRD.MKPF AS mkpf ON mseg.MANDT = mkpf.MANDT
            AND mseg.MBLNR = mkpf.MBLNR
            AND mseg.MJAHR = mkpf.MJAHR
            INNER JOIN SAPPRD.MARA AS mara ON mara.MATNR = mseg.MATNR
            LEFT JOIN SAPPRD.MAKT AS makt ON makt.MATNR = mseg.MATNR
            AND makt.SPRAS = 'S'
        WHERE
            mara.MTART IN ('ZFER') -- Producto terminado 
            AND mseg.BWART IN ('641', '351', '313', '303', '101', '315', '305')
            AND mseg.MENGE > 0
    ),
    agrupado AS (
        SELECT
            id_producto,
            MAX(descp_producto) AS descp_producto,
            MAX(id_sociedad) AS id_sociedad,
            MAX(unidad_medida) AS unidad_medida,
            COALESCE(ebeln_sto, mblnr) AS doc_referencia,
            COALESCE(ebelp_sto, 0) AS pos_referencia,
            MAX(werks_origen) AS werks_origen,
            MAX(lgort_origen) AS lgort_origen,
            MAX(werks_destino) AS werks_destino,
            MAX(lgort_destino) AS lgort_destino,
            MIN(fecha_documento) AS fecha_salida,
            MAX(fecha_documento) AS fecha_ultimo_mov,
            SUM(
                CASE
                    WHEN bwart IN ('641', '351', '313', '303') THEN cantidad
                    ELSE 0
                END
            ) AS qty_emitida,
            SUM(
                CASE
                    WHEN bwart IN ('101', '315', '305') THEN cantidad
                    ELSE 0
                END
            ) AS qty_recibida,
            SUM(qty_efecto) AS qty_pendiente
        FROM
            movimientos
        GROUP BY
            id_producto,
            COALESCE(ebeln_sto, mblnr),
            COALESCE(ebelp_sto, 0)
    )
SELECT
    a.id_sociedad AS id_sociedad,
    t001.BUTXT AS descp_sociedad,
    t001.LAND1 AS id_pais,
    a.id_producto AS id_producto,
    a.descp_producto AS descp_producto,
    a.unidad_medida AS unidad_medida,
    a.doc_referencia AS doc_referencia,
    a.pos_referencia AS pos_referencia,
    a.werks_origen AS id_centro_emisor,
    a.lgort_origen AS id_almacen_emisor,
    a.werks_destino AS id_centro_receptor,
    a.lgort_destino AS id_almacen_receptor,
    a.fecha_salida AS fecha_salida,
    a.fecha_ultimo_mov AS fecha_ultimo_mov,
    a.qty_emitida AS cantidad_emitida,
    a.qty_recibida AS cantidad_recibida,
    a.qty_pendiente AS cantidad_pendiente,
    CASE
        WHEN a.qty_pendiente > 0 THEN 'EN TRANSITO'
        WHEN a.qty_pendiente = 0
        AND a.qty_emitida > 0 THEN 'RECIBIDO'
        ELSE 'SIN MOVIMIENTOS'
    END AS estado_transito
FROM
    agrupado a
    LEFT JOIN SAPPRD.T001 AS t001 ON t001.BUKRS = a.id_sociedad
WHERE
    a.qty_pendiente > 0
ORDER BY
    a.fecha_salida DESC,
    a.doc_referencia,
    a.id_producto;