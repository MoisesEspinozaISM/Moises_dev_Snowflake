/////////////////////////// LIKP /////////////////////////////////////////
SELECT
  YEAR(TO_DATE(ERDAT, 'YYYY-MM-DD'))  AS anio,
  MONTH(TO_DATE(ERDAT, 'YYYY-MM-DD')) AS mes,
  COUNT(*)                          AS registros
FROM STAGING_RD_HT_GT.SAP.LIKP
WHERE TO_DATE(ERDAT, 'YYYY-MM-DD') >= TO_DATE('2025-01-01', 'YYYY-MM-DD')
  AND TO_DATE(ERDAT, 'YYYY-MM-DD') <  TO_DATE('2025-12-31', 'YYYY-MM-DD')
GROUP BY
  YEAR(TO_DATE(ERDAT, 'YYYY-MM-DD')),
  MONTH(TO_DATE(ERDAT, 'YYYY-MM-DD'))
ORDER BY anio, mes;

SELECT COUNT(*) FROM STAGING_RD_HT_GT.SAP.LIKP
WHERE ERDAT >= '2025-01-01'
;
-- 5 813 839
-- 5 817 607
/////////////////////////// VBRK /////////////////////////////////////////
SELECT
  YEAR(TO_DATE(FKDAT, 'YYYY-MM-DD'))  AS anio,
  MONTH(TO_DATE(FKDAT, 'YYYY-MM-DD')) AS mes,
  COUNT(*)                          AS registros
FROM STAGING_RD_HT_GT.SAP.VBRK
WHERE TO_DATE(FKDAT, 'YYYY-MM-DD') >= TO_DATE('2025-01-01', 'YYYY-MM-DD')
  AND TO_DATE(FKDAT, 'YYYY-MM-DD') <  TO_DATE('2025-12-31', 'YYYY-MM-DD')
GROUP BY
  YEAR(TO_DATE(FKDAT, 'YYYY-MM-DD')),
  MONTH(TO_DATE(FKDAT, 'YYYY-MM-DD'))
ORDER BY anio, mes;

DELETE FROM STAGING_RD_HT_GT.SAP.VBRK
WHERE FKDAT >= '2025-01-01'
; 


/////////////////////////// VBRP /////////////////////////////////////////
SELECT
  YEAR(TO_DATE(ERDAT, 'YYYY-MM-DD'))  AS anio,
  MONTH(TO_DATE(ERDAT, 'YYYY-MM-DD')) AS mes,
  COUNT(*)                          AS registros
FROM STAGING_RD_HT_GT.SAP.VBRP
WHERE TO_DATE(ERDAT, 'YYYY-MM-DD') >= TO_DATE('2024-01-01', 'YYYY-MM-DD')
  AND TO_DATE(ERDAT, 'YYYY-MM-DD') <  TO_DATE('2025-12-31', 'YYYY-MM-DD')
GROUP BY
  YEAR(TO_DATE(ERDAT, 'YYYY-MM-DD')),
  MONTH(TO_DATE(ERDAT, 'YYYY-MM-DD'))
ORDER BY anio, mes;


/////////////////////////// ZFIT_HEAD_LIQR /////////////////////////////////////////
SELECT
  YEAR(TO_DATE(DATEN, 'YYYY-MM-DD'))  AS anio,
  MONTH(TO_DATE(DATEN, 'YYYY-MM-DD')) AS mes,
  COUNT(*)                          AS registros
FROM STAGING_RD_HT_GT.SAP.ZFIT_HEAD_LIQR
WHERE TO_DATE(DATEN, 'YYYY-MM-DD') >= TO_DATE('2024-01-01', 'YYYY-MM-DD')
  AND TO_DATE(DATEN, 'YYYY-MM-DD') <  TO_DATE('2025-12-31', 'YYYY-MM-DD')
GROUP BY
  YEAR(TO_DATE(DATEN, 'YYYY-MM-DD')),
  MONTH(TO_DATE(DATEN, 'YYYY-MM-DD'))
ORDER BY anio, mes;

DELETE FROM STAGING_RD_HT_GT.SAP.ZFIT_HEAD_LIQR
WHERE DATEN >= '2025-06-01'


; 

SELECT * FROM DEV_SILVER_MJ.COMERCIAL.HISTORICO_KPIS_CATEGORIA_MARCA;


///////////////////////// 

SELECT
  YEAR(TO_DATE(bldat, 'YYYY-MM-DD'))  AS anio,
  MONTH(TO_DATE(bldat, 'YYYY-MM-DD')) AS mes,
  COUNT(*)                          AS registros
FROM STAGING_RD_HT_GT.SAP.COBK
WHERE TO_DATE(bldat, 'YYYY-MM-DD') >= TO_DATE('2024-01-01', 'YYYY-MM-DD')
  AND TO_DATE(bldat, 'YYYY-MM-DD') <  TO_DATE('2025-12-31', 'YYYY-MM-DD')
GROUP BY
  YEAR(TO_DATE(bldat, 'YYYY-MM-DD')),
  MONTH(TO_DATE(bldat, 'YYYY-MM-DD'))
ORDER BY anio, mes;

DELETE FROM STAGING_RD_HT_GT.SAP.ZFIT_HEAD_LIQR
WHERE DATEN >= '2025-06-01'