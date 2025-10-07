-- Vamos de definir una funciona de limpieza de textos 
create or replace function UTILS.COALESCE.FN_NORMALIZAR_TEXTO(s string)
returns string
language sql
as
$$
  trim(
    regexp_replace(
      upper(translate(coalesce(s,''),'ÁÉÍÓÚÜÑáéíóúü','AEIOUUNAEIOUU')),
      '[^A-Z0-9 X]', ' '
    )
  )
$$;


GRANT USAGE ON FUNCTION UTILS.COALESCE.FN_NORMALIZAR_TEXTO(VARCHAR) TO ROLE ROLE_APP_COALESCE;


select * from DEV_BRONZE_M.COMERCIAL.STG_CATEGORIA_MARCA_SABOR; 
select * from STAGING_CORP.SHAREPOINT.CATEGORIA_MARCA_SABOR;
select COUNT(*) from DEV_BRONZE_M.COMERCIAL.STG_CATEGORIA_MARCA_SABOR;
select COUNT(*) from STAGING_CORP.SHAREPOINT.CATEGORIA_MARCA_SABOR;


/////////// REALIZANDO EL CODIGO PARA ENCONTRAR MARCA Y CATEGORIA //////////////////// 
WITH ejemplos AS (
SELECT 
  LISTAGG(
    CONCAT(
      'En la Descripción buscamos marca: ', MARCA, 'y sabor: ', SABOR, ' y pertenecen a la categoria: ', CATEGORIA, ' .',
      'Resultado esperado: {"marca":"', MARCA, '", "sabor":"', SABOR, '","marca":"', CATEGORIA, '"}'
    ),
    '\n'
  ) AS patrones
FROM  DEV_BRONZE_M.COMERCIAL.STG_CATEGORIA_MARCA_SABOR
  WHERE ID_PAIS IN ('DO', 'HT', 'GT')
    AND MARCA IS NOT NULL
    AND SABOR IS NOT NULL
)
SELECT
  P.ID_SKU_ORIGEN,
  P.NOM_SKU,
  AI_COMPLETE(
    MODEL => 'llama3.1-70b', -- mistral-large2 , llama3.1-70b
    prompt => CONCAT(
      'Del texto descripctivo de un producto vamos a identificar la marca y sabor, para ello te vas a guiar de los siguientes patrones relacion marca-sabor que tenemos en nuestra organizacion:\n\n',
      e.patrones, '\n\n',
      'Si encuentras nuevos sabores o marcas que no esten en los patrones mostrados, puedes tomarlos siempre y cuando tengan coherencia de ser marca y sabor de un producto sku de una empresa de retail. En el caso de no encontrar marca ni sabor colocar "NO ENCONTRADO".\n\n',
      'Para el caso de la Marca tenemos algunos casos especiales por ejemplo si hay "GASEOSA K" o "KR" la marca es "KOLA REAL", Cuando en la marca tengamos "ENERGIZANTE 360" " la marca es "360", Si el producto tiene en su descripcion "JUGO" acompañado con algun sabor, la marca es "FRUTOP".\n\n',
      'Si el producto en la descripcion contiene "AGUA" y no encuentro patron para el sabor colocar "SIN GAS".\n\n',
      'Ahora procesa esta descripción y devuelve solo un JSON con la marca, el sabor del producto y adiciona al JSON la categoria de acuerdo a la marca seguns los patrones.\n',
      'Descripción: ', P.NOM_SKU
    ),
    response_format => OBJECT_CONSTRUCT(
      'type', 'json',
      'schema', OBJECT_CONSTRUCT(
        'type', 'object',
        'properties', OBJECT_CONSTRUCT(
          'marca', OBJECT_CONSTRUCT('type', 'string'),
          'sabor', OBJECT_CONSTRUCT('type', 'string'),
          'categoria', OBJECT_CONSTRUCT('type', 'string')
        ),
        'required', ARRAY_CONSTRUCT('marca','sabor', 'categoria')
      )
    ),
    model_parameters => OBJECT_CONSTRUCT('temperature', 0, 'max_tokens', 100),
    show_details => FALSE
  ) AS salida_json,
    salida_json:marca::STRING AS marca,
    salida_json:sabor::STRING AS sabor,
    salida_json:categoria::STRING AS categoria
FROM DEV_BRONZE_M.COMERCIAL.SKU_DETALLADO_CARIBE p, ejemplos e
where p.id_tipo_material = 'ZFER'
;


/// version mejorado con la IA 

WITH ejemplos AS (
  SELECT 
    LISTAGG(
      CONCAT(
        'Descripción de ejemplo: contiene la marca "', MARCA, '" y el sabor "', SABOR, '", y pertenece a la categoría "', CATEGORIA, '".\n',
        'Resultado: {"marca":"', MARCA, '", "sabor":"', SABOR, '", "categoria":"', CATEGORIA, '"}'
      ),
      '\n\n'
    ) AS patrones
  FROM (
    SELECT DISTINCT MARCA, SABOR, CATEGORIA
    FROM DEV_BRONZE_M.COMERCIAL.STG_CATEGORIA_MARCA_SABOR
    WHERE ID_PAIS IN ('DO', 'HT', 'GT')
      AND MARCA IS NOT NULL
      AND SABOR IS NOT NULL
      AND CATEGORIA IS NOT NULL
  )
)

SELECT
  P.ID_SKU_ORIGEN,
  P.NOM_SKU,
  AI_COMPLETE(
    MODEL => 'llama3.1-70b',
    prompt => CONCAT(
      'Analiza la siguiente descripción de producto con el objetivo de identificar tres atributos: la marca, el sabor y la categoría a la que pertenece.\n\n',
      
      'Para guiarte, te proporcionamos ejemplos reales de combinaciones válidas de marca, sabor y categoría registradas por nuestra organización:\n\n',
      e.patrones, '\n\n',

      'Instrucciones adicionales:\n',
      '- Si identificas nuevas marcas o sabores que no aparecen en los ejemplos, puedes proponerlos siempre que tengan coherencia con un producto del sector retail.\n',
      '- Si no encuentras marca o sabor, utiliza "NO ENCONTRADO" como valor por defecto.\n',
      '- En caso de ambigüedad, prioriza las marcas conocidas que aparezcan frecuentemente en los ejemplos.\n\n',

      'Casos especiales:\n',
      '- Si ves "KR" o "GASEOSA K", interpreta la marca como "KOLA REAL".\n',
      '- Si aparece "ENERGIZANTE 360", interpreta la marca como "360".\n',
      '- Si el producto contiene la palabra "JUGO" y un sabor válido, la marca predeterminada es "FRUTOP".\n',
      '- Si se trata de "AGUA" y no se identifica un sabor claro, el sabor debe ser "SIN GAS".\n\n',

      'Validación de coherencia::\n',
      '- Solo debes asignar una categoría si la descripción del producto indica claramente que se trata de una bebida o producto alimenticio para consumo humano, como gaseosa, jugo, agua, té, energizante, etc.\n\n',

      'Tu única salida debe ser un objeto JSON con esta estructura exacta: {"marca":"...","sabor":"...","categoria":"..."}.\n\n',
      'Descripción: ', P.NOM_SKU
    ),
    response_format => OBJECT_CONSTRUCT(
      'type', 'json',
      'schema', OBJECT_CONSTRUCT(
        'type', 'object',
        'properties', OBJECT_CONSTRUCT(
          'marca', OBJECT_CONSTRUCT('type', 'string'),
          'sabor', OBJECT_CONSTRUCT('type', 'string'),
          'categoria', OBJECT_CONSTRUCT('type', 'string')
        ),
        'required', ARRAY_CONSTRUCT('marca','sabor', 'categoria')
      )
    ),
    model_parameters => OBJECT_CONSTRUCT('temperature', 0, 'max_tokens', 100),
    show_details => FALSE
  ) AS salida_json,
    salida_json:marca::STRING AS marca,
    salida_json:sabor::STRING AS sabor,
    salida_json:categoria::STRING AS categoria
FROM DEV_BRONZE_M.COMERCIAL.SKU_DETALLADO_CARIBE p, ejemplos e
WHERE p.id_tipo_material = 'ZFER';


SELECT "SKU_DETALLADO_PE_CH"."ID_PRODUCTO" AS "ID_PRODUCTO",
  "SKU_DETALLADO_PE_CH"."ID_SOCIEDAD" AS "ID_SOCIEDAD",
  "SKU_DETALLADO_PE_CH"."ID_SKU_ORIGEN" AS "ID_SKU_ORIGEN",
  "SKU_DETALLADO_PE_CH"."NOM_SKU" AS "NOM_SKU",
  AI_COMPLETE(
    MODEL => 'llama3.1-70b',
    prompt => CONCAT(
      'Analiza la siguiente descripción de producto con el objetivo de identificar tres atributos: la marca, el sabor y la categoría a la que pertenece.\n\n',
      'Para guiarte, te proporcionamos ejemplos reales de combinaciones válidas de marca, sabor y categoría registradas por nuestra organización:\n\n',
      "HOMOLOGACION_PATRONES_FABRIC"."PATRONES",
      '\n\n',
      'Instrucciones adicionales:\n',
      '- Si identificas nuevas marcas o sabores que no aparecen en los ejemplos, puedes proponerlos siempre que tengan coherencia con un producto del sector retail.\n',
      '- Si no encuentras marca o sabor, utiliza "NO DEFINIDO" como valor por defecto.\n',
      '- En caso de ambigüedad, prioriza las marcas conocidas que aparezcan frecuentemente en los ejemplos.\n\n',
      'Casos especiales:\n',
      '- Si ves "KR" o "GASEOSA K", interpreta la marca como "KOLA REAL" y encuentra el sabor.\n',
      '- Si aparece "ENERGY DRINK", interpreta la marca como "360".\n',
      '- Si aparece "GOOB", interpreta la marca como "GOOB" categoria "GASEOSA" y encuentra el sabor.\n',
      '- Si se trata de "AGUA" y no se identifica un sabor claro, el sabor debe ser "SIN GAS".\n\n',
      'Validación de coherencia::\n',
      '- Solo debes asignar una categoría si la marca del producto esta dentro de los ejemplos, caso contrario colocar "NO DEFINIDO".\n\n',
      'Tu única salida debe ser un objeto JSON con esta estructura exacta: {"marca":"...","sabor":"...","categoria":"..."} sin texto adicional.\n\n',
      'Descripción: ',
      "SKU_DETALLADO_PE_CH"."NOM_SKU"
    ),
    response_format => OBJECT_CONSTRUCT(
      'type',
      'json',
      'schema',
      OBJECT_CONSTRUCT(
        'type',
        'object',
        'properties',
        OBJECT_CONSTRUCT(
          'marca',
          OBJECT_CONSTRUCT('type', 'string'),
          'sabor',
          OBJECT_CONSTRUCT('type', 'string'),
          'categoria',
          OBJECT_CONSTRUCT('type', 'string')
        ),
        'required',
        ARRAY_CONSTRUCT('marca', 'sabor', 'categoria')
      )
    ),
    model_parameters => OBJECT_CONSTRUCT('temperature', 0, 'max_tokens', 400),
    show_details => FALSE
  ) AS "JSON_CORTEX",
  "SKU_DETALLADO_PE_CH"."SISTEMA_ORIGEN" AS "SISTEMA_ORIGEN",
  "SKU_DETALLADO_PE_CH"."ID_PAIS" AS "ID_PAIS",
  "SKU_DETALLADO_PE_CH"."SABOR" AS "SABOR",
  JSON_CORTEX :sabor::STRING AS "SABOR_CORP",
  "SKU_DETALLADO_PE_CH"."CATEGORIA" AS "CATEGORIA",
  JSON_CORTEX :categoria::STRING AS "CATEGORIA_CORP",
  "SKU_DETALLADO_PE_CH"."GRUPO_ARTICULOS" AS "GRUPO_ARTICULOS",
  "SKU_DETALLADO_PE_CH"."ID_TIPO_MATERIAL" AS "ID_TIPO_MATERIAL",
  "SKU_DETALLADO_PE_CH"."MARCA" AS "MARCA",
  JSON_CORTEX :marca::STRING AS "MARCA_CORP",
  "SKU_DETALLADO_PE_CH"."FORMATO" AS "FORMATO",
  "SKU_DETALLADO_PE_CH"."SIGLAS" AS "SIGLAS",
  "SKU_DETALLADO_PE_CH"."UNIDAD_BASE" AS "UNIDAD_BASE",
  "SKU_DETALLADO_PE_CH"."VOLUMEN_ML_UN" AS "VOLUMEN_ML_UN",
  "SKU_DETALLADO_PE_CH"."VOLUMEN_LTS_UN" AS "VOLUMEN_LTS_UN",
  "SKU_DETALLADO_PE_CH"."VOLUMEN_M3_UN" AS "VOLUMEN_M3_UN",
  "SKU_DETALLADO_PE_CH"."PESO_BRUTO_KG_UN" AS "PESO_BRUTO_KG_UN",
  "SKU_DETALLADO_PE_CH"."PESO_NETO_KG_UN" AS "PESO_NETO_KG_UN",
  "SKU_DETALLADO_PE_CH"."UNIDADES_X_PQT" AS "UNIDADES_X_PQT",
  "SKU_DETALLADO_PE_CH"."UNIDADES_X_CAJA" AS "UNIDADES_X_CAJA",
  "SKU_DETALLADO_PE_CH"."UNIDADES_X_PALLET" AS "UNIDADES_X_PALLET",
  "SKU_DETALLADO_PE_CH"."FACTOR_CONV_CAJA_FISICA" AS "FACTOR_CONV_CAJA_FISICA",
  "SKU_DETALLADO_PE_CH"."FACTOR_CONV_CAJA_UNITARIA" AS "FACTOR_CONV_CAJA_UNITARIA",
  "SKU_DETALLADO_PE_CH"."ESTADO" AS "ESTADO",
  "SKU_DETALLADO_PE_CH"."SEGMENTO" AS "SEGMENTO",
  "SKU_DETALLADO_PE_CH"."ROTACION" AS "ROTACION",
  "SKU_DETALLADO_PE_CH"."FEC_CREACION_SKU" AS "FEC_CREACION_SKU"
FROM "DEV_BRONZE_M"."COMERCIAL"."SKU_DETALLADO_PE_CH" SKU_DETALLADO_PE_CH
  CROSS JOIN "DEV_BRONZE_M"."COMERCIAL"."HOMOLOGACION_PATRONES_FABRIC" HOMOLOGACION_PATRONES_FABRIC
WHERE "SKU_DETALLADO_PE_CH"."ID_TIPO_MATERIAL" IN ('ZHAW')
AND SKU_DETALLADO_PE_CH.CATEGORIA IN ('AGUA', 'JUGO', 'GASEOSA', 'AGUA SABORIZADA', ' ENERGIZANTE' , 'ALOE' )
limit 1999
;

select COUNT(*) FROM "DEV_BRONZE_M"."COMERCIAL"."SKU_DETALLADO_PE_CH"
where "SKU_DETALLADO_PE_CH"."ID_TIPO_MATERIAL" IN ('ZHAW')
AND SKU_DETALLADO_PE_CH.CATEGORIA IN ('AGUA', 'JUGO', 'GASEOSA', 'AGUA SABORIZADA', ' ENERGIZANTE' , 'ALOE' )
; 

select * FROM "DEV_BRONZE_M"."COMERCIAL"."SKU_DETALLADO_PE_CH"
where SKU_DETALLADO_PE_CH.CATEGORIA IN ('S/E' )
; 
select * FROM "DEV_BRONZE_M"."COMERCIAL"."SKU_DETALLADO_CARIBE"
where "SKU_DETALLADO_CARIBE"."ID_TIPO_MATERIAL" IN ('ZHAW')
; 
select * from "DEV_BRONZE_M"."COMERCIAL"."HOMOLOGACION_PATRONES_FABRIC"

;
SELECT 
ID_PRODUCTO, 
ID_SOCIEDAD, 
ID_SKU_ORIGEN, 
NOM_SKU, 
CATEGORIA_CORP, 
MARCA_CORP,
SABOR, 
CATEGORIA_CORTEX,
MARCA_CORTEX,
SABOR_CORTEX
FROM DEV_BRONZE_M.COMERCIAL.SKU_DETALLADO_BR_CORTEX; 

SELECT * FROM TEST_SILVER.COMERCIAL.SILVER_VENTA_NETA_CORP
WHERE ID_SKU_ORIGEN = '61';

SELECT * FROM DEV_BRONZE_M.COMERCIAL.SKU_DETALLADO_PE_CH
WHERE ID_TIPO_MATERIAL = 'ZFER'; 

SELECT DISTINCT ID_TIPO_MATERIAL FROM DEV_BRONZE_M.COMERCIAL.SKU_DETALLADO_PE_CH
;

SELECT 
ID_PRODUCTO, 
ID_SOCIEDAD, 
ID_SKU_ORIGEN, 
NOM_SKU, 
CATEGORIA_CORP, 
MARCA_CORP,
SABOR, 
CATEGORIA_CORTEX,
MARCA_CORTEX,
SABOR_CORTEX
FROM DEV_BRONZE_M.COMERCIAL.SKU_DETALLADO_PE_CH_CORTEX;

SELECT * FROM DEV_BRONZE_M.COMERCIAL.SKU_DETALLADO_PE_CH_FINAL;

SELECT 
ID_PRODUCTO, 
ID_SOCIEDAD, 
ID_SKU_ORIGEN, 
NOM_SKU, 
CATEGORIA_CORP, 
MARCA_CORP,
SABOR, 
CATEGORIA_CORTEX,
MARCA_CORTEX,
SABOR_CORTEX
FROM DEV_BRONZE_M.COMERCIAL.SKU_DETALLADO_CARIBE_CORTEX;

SELECT * FROM PROD_SILVER.COMERCIAL.SILVER_VENTA_NETA_CORP LIMIT 100;

SELECT COUNT(*) FROM "DEV_BRONZE_M"."COMERCIAL"."SKU_DETALLADO_BR_CORTEX";
-- 2264 

SELECT * FROM TEST_SILVER.COMERCIAL.SILVER_MAESTRO_PRODUCTO;
