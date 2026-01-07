select count(*) from staging_br.oracle.view_vendasbr_ml; 
--12 054 441

SELECT count(*) AS CONTEO, 
SALESDATE 
FROM staging_br.oracle.view_vendasbr_ml 
GROUP BY SALESDATE 
ORDER BY SALESDATE ASC; 