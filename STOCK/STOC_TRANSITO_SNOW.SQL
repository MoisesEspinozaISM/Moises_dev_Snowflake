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
      mseg.MEINS AS unidad_medida, -- UoM base
      /* Origen (emisor) */
      mseg.WERKS AS werks_origen,
      mseg.LGORT AS lgort_origen,
      /* Destino (receptor) */
      mseg.UMWRK AS werks_destino,
      mseg.UMLGO AS lgort_destino,
      /* Referencias (STO) */
      mseg.EBELN AS ebeln_sto,
      mseg.EBELP AS ebelp_sto,
      mseg.BWART,
      mseg.SHKZG,
      mseg.MENGE AS cantidad,
      mseg.CHARG AS lote,
      mkpf.BUDAT AS fecha_documento,
      mara.XCHPF AS es_lote, -- 'X' si maneja lote
      /* ===== Flags de calidad ===== */
      CASE
        WHEN mseg.BWART IN ('641', '351', '313', '303')
        AND mseg.SHKZG <> 'H' THEN 1
        WHEN mseg.BWART IN ('101', '315', '305')
        AND mseg.SHKZG <> 'S' THEN 1
        WHEN mseg.BWART IN ('642', '352', '314', '304')
        AND mseg.SHKZG <> 'S' THEN 1
        WHEN mseg.BWART IN ('102', '316', '306')
        AND mseg.SHKZG <> 'H' THEN 1
        ELSE 0
      END AS flag_incoherencia_signo,
      /* Exigir CHARG solo si el material es batch-managed */
      CASE
        WHEN mara.XCHPF = 'X'
        AND (
          mseg.CHARG IS NULL
          OR mseg.CHARG = ''
        ) THEN 1
        ELSE 0
      END AS flag_lote_faltante,
      /* ===== Efecto en tránsito (rol por BWART) ===== */
      CASE
      /* salidas que crean tránsito */
        WHEN mseg.BWART IN ('641', '351', '313', '303') THEN + mseg.MENGE
        /* entradas que consumen tránsito */
        WHEN mseg.BWART IN ('101', '315', '305') THEN - mseg.MENGE
        /* reversas de salidas (anulan tránsito creado) */
        WHEN mseg.BWART IN ('642', '352', '314', '304') THEN - mseg.MENGE
        /* reversas de entradas (reabren pendiente) */
        WHEN mseg.BWART IN ('102', '316', '306') THEN + mseg.MENGE
        ELSE 0
      END AS qty_efecto
    FROM
      STAGING_RD_HT_GT.SAP.MSEG AS mseg
      INNER JOIN STAGING_RD_HT_GT.SAP.MKPF AS mkpf ON mseg.MANDT = mkpf.MANDT
      AND mseg.MBLNR = mkpf.MBLNR
      AND mseg.MJAHR = mkpf.MJAHR
      INNER JOIN STAGING_RD_HT_GT.SAP.MARA AS mara ON mara.MATNR = mseg.MATNR
      LEFT JOIN STAGING_RD_HT_GT.SAP.MAKT AS makt ON makt.MATNR = mseg.MATNR
      AND makt.SPRAS = 'S'
    WHERE
      mara.MTART = 'ZFER' -- producto terminado
      AND mseg.MENGE > 0
      /* Solo set de tránsito (con reversas) */
      AND mseg.BWART IN (
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
      /* Exigir lote solo si corresponde */
      AND (
        mara.XCHPF <> 'X'
        OR (
          mseg.CHARG IS NOT NULL
          AND mseg.CHARG <> ''
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
          WHEN bwart IN ('641', '351', '313', '303') THEN cantidad
          WHEN bwart IN ('642', '352', '314', '304') THEN - cantidad
          ELSE 0
        END
      ) AS qty_emitida_raw,
      SUM(
        CASE
          WHEN bwart IN ('101', '315', '305') THEN cantidad
          WHEN bwart IN ('102', '316', '306') THEN - cantidad
          ELSE 0
        END
      ) AS qty_recibida_raw,
      SUM(qty_efecto) AS qty_pendiente_raw,
      MAX(flag_incoherencia_signo) AS flag_incoherencia_signo,
      MAX(flag_lote_faltante) AS flag_lote_faltante,
      /* Flag: tránsito creado y cerrado el mismo día */
      CASE
        WHEN MIN(fecha_documento) = MAX(fecha_documento)
        AND SUM(
          CASE
            WHEN bwart IN ('641', '351', '313', '303') THEN 1
            ELSE 0
          END
        ) > 0
        AND SUM(
          CASE
            WHEN bwart IN ('101', '315', '305') THEN 1
            ELSE 0
          END
        ) > 0 THEN 1
        ELSE 0
      END AS flag_mismo_dia_cierre,
      /* Decimales de la UoM desde T006 (ANDEC). Fallback: 3 */
      COALESCE(MAX(t006.ANDEC), 3) AS decimales_uom
    FROM
      movimientos m
      LEFT JOIN STAGING_RD_HT_GT.SAP.T006 t006 ON t006.MSEHI = m.unidad_medida
    WHERE
      flag_incoherencia_signo = 0
    GROUP BY
      id_producto,
      ebeln_sto,
      ebelp_sto
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
  /* Tolerancia: medio “tick” de la UoM → limpia residuos ínfimos */
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
  END AS estado_transito,
  /* Extras de control / auditoría */
  a.flag_incoherencia_signo,
  a.flag_lote_faltante,
  a.flag_mismo_dia_cierre,
  a.decimales_uom
FROM
  agrupado a
  LEFT JOIN STAGING_RD_HT_GT.SAP.T001 t001 ON t001.BUKRS = a.id_sociedad
  /* Solo pendientes reales y recientes */
WHERE
  (
    CASE
      WHEN ABS(ROUND(a.qty_pendiente_raw, a.decimales_uom)) <= CASE
        WHEN a.decimales_uom = 0 THEN 0.5
        ELSE POWER(10, - a.decimales_uom) / 2
      END THEN 0
      ELSE ROUND(a.qty_pendiente_raw, a.decimales_uom)
    END
  ) > 0
  AND a.flag_incoherencia_signo = 0
  AND a.flag_mismo_dia_cierre = 0
  AND a.fecha_ultimo_mov >= ADD_MONTHS (CURRENT_DATE, -12)
ORDER BY
  a.fecha_salida asc,
  a.doc_referencia,
  a.id_producto;