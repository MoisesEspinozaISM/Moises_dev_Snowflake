-- CREAMOS BASE DE DATOS UTILS 
CREATE DATABASE UTILS;

--- CREAMOS EL ESQUEMA COALESCE dentro de la base de datos UTILS 
CREATE SCHEMA UTILS.COALESCE; 

-- CREAMOS EL TEST DE ULTIMAS FECHAS 
CREATE OR REPLACE PROCEDURE UTILS.COALESCE.TEST_ULTIMAS_FECHAS(
  table_fqn      STRING,     -- Nombre completo de la tabla
  date_column    STRING,     -- Columna de fecha a validar
  dias_retraso   INTEGER,    -- Días máximos de retraso permitidos
  excluir_domingo BOOLEAN    -- TRUE: excluir domingos, FALSE: incluir todos los días
)
RETURNS TABLE (max_fecha DATE, fecha_limite DATE, dias_retraso_actual INTEGER, estado STRING)
LANGUAGE SQL
AS
$$
DECLARE
  rs RESULTSET;
  query STRING;
  safe_date_column STRING := REPLACE(date_column, '''', '''''');
  safe_table_fqn STRING := REPLACE(table_fqn, '''', '''''');
  excluir_str STRING := CASE WHEN excluir_domingo THEN 'TRUE' ELSE 'FALSE' END;
  dias_base_str STRING := CAST(dias_retraso AS STRING);
BEGIN
  query := '
    WITH fecha_maxima AS (
      SELECT MAX(CAST(IDENTIFIER(''' || safe_date_column || ''') AS DATE)) AS max_fecha
      FROM IDENTIFIER(''' || safe_table_fqn || ''')
    ),
    calculo_dias AS (
      SELECT 
        CASE 
          WHEN ' || excluir_str || ' AND DAYOFWEEK(CURRENT_DATE) = 1 
            THEN ' || dias_base_str || ' + 1
          ELSE ' || dias_base_str || '
        END AS dias_totales
    )
    SELECT 
      f.max_fecha, 
      DATEADD(day, -c.dias_totales, CURRENT_DATE) AS fecha_limite,
      DATEDIFF(day, f.max_fecha, CURRENT_DATE) AS dias_retraso_actual,
      CASE 
        WHEN f.max_fecha < DATEADD(day, -c.dias_totales, CURRENT_DATE) THEN ''FUERA_RANGO''
        ELSE ''DENTRO_RANGO''
      END AS estado
    FROM fecha_maxima f
    CROSS JOIN calculo_dias c
    WHERE f.max_fecha < DATEADD(day, -c.dias_totales, CURRENT_DATE)';
  
  rs := (EXECUTE IMMEDIATE :query);
  RETURN TABLE(rs);
END;
$$;

SELECT *
FROM TABLE(UTILS.COALESCE.TEST_ULTIMAS_FECHAS(
  'TEST_BRONZE.COMERCIAL.STG_VBRK', 
  'FKDAT', 
  1,    -- 1 día de retraso normalmente
  TRUE  -- Excluir domingos (si es domingo, permite 2 días hacia atras)
));



 
/////////////// DAMOS LOS PERMISOS A LOS ROLES PARA QUE PUEDAN USAR ESTE PROCEDIMIENTO /////// 
GRANT USAGE ON DATABASE UTILS TO ROLE ROLE_APP_COALESCE;
GRANT USAGE ON SCHEMA UTILS.COALESCE TO ROLE ROLE_APP_COALESCE;
GRANT USAGE ON PROCEDURE UTILS.COALESCE.TEST_REGISTROS_ANALYSIS(VARCHAR, VARCHAR, NUMBER) TO ROLE ROLE_APP_COALESCE;



