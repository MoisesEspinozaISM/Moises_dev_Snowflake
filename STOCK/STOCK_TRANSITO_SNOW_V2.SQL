WITH
    movimientos AS (
        SELECT
            mseg.MANDT,
            mseg.MBLNR,
            mseg.MJAHR,
            mseg.ZEILE,
            /* IDs y descripciones */
            LPAD (TO_VARCHAR (mseg.MATNR), 18, '0') AS id_producto,
            makt.MAKTX AS descp_producto,
            /* Claves normalizadas */
            TRIM(mseg.BUKRS) AS id_sociedad,
            TRIM(mseg.MEINS) AS unidad_medida,
            /* Origen (emisor) */
            TRIM(mseg.WERKS) AS werks_origen,
            TRIM(mseg.LGORT) AS lgort_origen,
            /* Destino (receptor) */
            TRIM(mseg.UMWRK) AS werks_destino,
            TRIM(mseg.UMLGO) AS lgort_destino,
            /* Referencias (STO) normalizadas */
            LPAD (TO_VARCHAR (mseg.EBELN), 10, '0') AS ebeln_sto,
            LPAD (TO_VARCHAR (mseg.EBELP), 5, '0') AS ebelp_sto,
            /* BWART / SHKZG normalizados */
            TRIM(UPPER(mseg.BWART)) AS BWART,
            TRIM(UPPER(mseg.SHKZG)) AS SHKZG,
            /* Cantidad en magnitud (signo lo aporta la regla de BWART) */
            ABS(mseg.MENGE) AS cantidad,
            /* Lote y batch */
            NULLIF(TRIM(mseg.CHARG), '') AS lote,
            CAST(mkpf.BUDAT AS DATE) AS fecha_documento,
            TRIM(UPPER(mara.XCHPF)) AS es_lote
        FROM
            STAGING_RD_HT_GT.SAP.MSEG AS mseg
            INNER JOIN STAGING_RD_HT_GT.SAP.MKPF AS mkpf ON mseg.MANDT = mkpf.MANDT
            AND mseg.MBLNR = mkpf.MBLNR
            AND mseg.MJAHR = mkpf.MJAHR
            INNER JOIN STAGING_RD_HT_GT.SAP.MARA AS mara ON mara.MATNR = mseg.MATNR
            LEFT JOIN STAGING_RD_HT_GT.SAP.MAKT AS makt ON makt.MATNR = mseg.MATNR
            AND TRIM(makt.SPRAS) = 'S'
        WHERE
            /* Producto terminado */
            TRIM(UPPER(mara.MTART)) = 'ZFER'
            AND ABS(mseg.MENGE) > 0
            /* Solo set de tránsito (incluye reversas) */
            AND TRIM(UPPER(mseg.BWART)) IN (
                '641',
                '642',
                '351',
                '352',
                '313',
                '314',
                '303',
                '304',
                '101',
                '102',
                '315',
                '316',
                '305',
                '306'
            )
            /* Exigir CHARG solo si corresponde (robusto a espacios/nulos) */
            AND (
                TRIM(UPPER(mara.XCHPF)) <> 'X'
                OR NULLIF(TRIM(mseg.CHARG), '') IS NOT NULL
            )
            /* >>> Coherencia BWART↔SHKZG: se filtra AQUÍ, no se necesitan flags <<< */
            AND (
                (
                    TRIM(UPPER(mseg.BWART)) IN ('641', '351', '313', '303')
                    AND TRIM(UPPER(mseg.SHKZG)) = 'H'
                )
                OR (
                    TRIM(UPPER(mseg.BWART)) IN ('101', '315', '305')
                    AND TRIM(UPPER(mseg.SHKZG)) = 'S'
                )
                OR (
                    TRIM(UPPER(mseg.BWART)) IN ('642', '352', '314', '304')
                    AND TRIM(UPPER(mseg.SHKZG)) = 'S'
                )
                OR (
                    TRIM(UPPER(mseg.BWART)) IN ('102', '316', '306')
                    AND TRIM(UPPER(mseg.SHKZG)) = 'H'
                )
            )
    ),
    agrupado AS (
        SELECT
            id_producto,
            MAX(descp_producto) AS descp_producto,
            MAX(id_sociedad) AS id_sociedad,
            MAX(unidad_medida) AS unidad_medida,
            ebeln_sto AS doc_referencia,
            ebelp_sto AS pos_referencia,
            MAX(werks_origen) AS werks_origen,
            MAX(lgort_origen) AS lgort_origen,
            MAX(werks_destino) AS werks_destino,
            MAX(lgort_destino) AS lgort_destino,
            MIN(fecha_documento) AS fecha_salida,
            MAX(fecha_documento) AS fecha_ultimo_mov,
            /* Cantidades crudas (incluyendo reversas) */
            SUM(
                CASE
                    WHEN BWART IN ('641', '351', '313', '303') THEN cantidad
                    WHEN BWART IN ('642', '352', '314', '304') THEN - cantidad
                    ELSE 0
                END
            ) AS qty_emitida_raw,
            SUM(
                CASE
                    WHEN BWART IN ('101', '315', '305') THEN cantidad
                    WHEN BWART IN ('102', '316', '306') THEN - cantidad
                    ELSE 0
                END
            ) AS qty_recibida_raw,
            /* Efecto en tránsito (rol por BWART) */
            SUM(
                CASE
                    WHEN BWART IN ('641', '351', '313', '303') THEN + cantidad
                    WHEN BWART IN ('101', '315', '305') THEN - cantidad
                    WHEN BWART IN ('642', '352', '314', '304') THEN - cantidad
                    WHEN BWART IN ('102', '316', '306') THEN + cantidad
                    ELSE 0
                END
            ) AS qty_pendiente_raw,
            /* Flag: tránsito creado y cerrado el mismo día */
            CASE
                WHEN MIN(fecha_documento) = MAX(fecha_documento)
                AND SUM(
                    CASE
                        WHEN BWART IN ('641', '351', '313', '303') THEN 1
                        ELSE 0
                    END
                ) > 0
                AND SUM(
                    CASE
                        WHEN BWART IN ('101', '315', '305') THEN 1
                        ELSE 0
                    END
                ) > 0 THEN 1
                ELSE 0
            END AS flag_mismo_dia_cierre,
            /* Decimales de la UoM desde T006 (ANDEC). Fallback: 3 */
            COALESCE(MAX(t006.ANDEC), 3) AS decimales_uom
        FROM
            movimientos m
            LEFT JOIN STAGING_RD_HT_GT.SAP.T006 t006 ON TRIM(t006.MSEHI) = m.unidad_medida
            /* Solo agrupamos por la combinación STO + material */
        GROUP BY
            id_producto,
            ebeln_sto,
            ebelp_sto
            /* >>> Guardarraíl: exige al menos una “salida” (o su reversa) en el grupo <<< */
        HAVING
            SUM(
                CASE
                    WHEN BWART IN (
                        '641',
                        '351',
                        '313',
                        '303',
                        '642',
                        '352',
                        '314',
                        '304'
                    ) THEN 1
                    ELSE 0
                END
            ) > 0
    )
SELECT
    t001.LAND1 AS id_pais,
    a.id_sociedad AS id_sociedad,
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
    /* Redondeo por decimales de la UoM */
    ROUND(a.qty_emitida_raw, a.decimales_uom) AS cantidad_emitida,
    ROUND(a.qty_recibida_raw, a.decimales_uom) AS cantidad_recibida,
    ROUND(a.qty_pendiente_raw, a.decimales_uom) AS cantidad_pendiente,
    /* Tolerancia: medio “tick” */
    CASE
        WHEN ABS(ROUND(a.qty_pendiente_raw, a.decimales_uom)) <= CASE
            WHEN a.decimales_uom = 0 THEN 0.5
            ELSE POWER(10, - a.decimales_uom) / 2
        END THEN 0
        ELSE ROUND(a.qty_pendiente_raw, a.decimales_uom)
    END AS cantidad_pendiente_ajustada,
    /* Estado basado en AJUSTADA */
    CASE
        WHEN (
            CASE
                WHEN ABS(ROUND(a.qty_pendiente_raw, a.decimales_uom)) <= CASE
                    WHEN a.decimales_uom = 0 THEN 0.5
                    ELSE POWER(10, - a.decimales_uom) / 2
                END THEN 0
                ELSE ROUND(a.qty_pendiente_raw, a.decimales_uom)
            END
        ) > 0 THEN 'EN TRANSITO'
        WHEN ROUND(a.qty_pendiente_raw, a.decimales_uom) = 0
        AND ROUND(a.qty_emitida_raw, a.decimales_uom) > 0 THEN 'RECIBIDO'
        ELSE 'SIN MOVIMIENTOS'
    END AS estado_transito
FROM
    agrupado a
    LEFT JOIN STAGING_RD_HT_GT.SAP.T001 t001 ON TRIM(t001.BUKRS) = a.id_sociedad
WHERE
    /* Solo pendientes reales y recientes */
    (
        CASE
            WHEN ABS(ROUND(a.qty_pendiente_raw, a.decimales_uom)) <= CASE
                WHEN a.decimales_uom = 0 THEN 0.5
                ELSE POWER(10, - a.decimales_uom) / 2
            END THEN 0
            ELSE ROUND(a.qty_pendiente_raw, a.decimales_uom)
        END
    ) > 0
    AND a.flag_mismo_dia_cierre = 0
    AND a.fecha_ultimo_mov >= ADD_MONTHS (CURRENT_DATE, -12)
ORDER BY
    a.fecha_salida ASC,
    a.doc_referencia asc,
    a.id_producto;