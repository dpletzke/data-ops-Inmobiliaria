USE WAREHOUSE WH_INMOBILIARIA;
USE DATABASE INMOBILIARIA_DW;
USE SCHEMA MANTENIMIENTO;

GRANT EXECUTE TASK ON ACCOUNT TO ROLE INMOBILIARIA_DATAOPS_LOADER
 
CREATE OR REPLACE TASK TASK_INGEST_SOLICITUDES_S3
  WAREHOUSE = WH_INMOBILIARIA
  SCHEDULE = 'USING CRON 0 * * * * America/Bogota'
  COMMENT = 'Root del DAG: ingesta JSON desde S3 hacia RAW_SOLICITUD'
AS
COPY INTO RAW_SOLICITUD (raw_data)
FROM (
    SELECT $1
    FROM @STG_MANTENIMIENTO_SOLICITUD_S3
)
FILE_FORMAT = (FORMAT_NAME = FF_MANTENIMIENTO_JSON)
ON_ERROR = ABORT_STATEMENT;
 
CREATE OR REPLACE TASK TASK_STG_DESDE_RAW_SOLICITUD
  WAREHOUSE = WH_INMOBILIARIA
  AFTER TASK_INGEST_SOLICITUDES_S3
AS
BEGIN
  INSERT OVERWRITE INTO STG_SOLICITUD (
    event_id,
    source_system,
    reported_at,
    id_inmueble,
    direccion_ref,
    id_contrato,
    categoria,
    prioridad,
    estado_fuente,
    descripcion,
    tipo_reportante,
    nombre_reportante,
    documento_reportante,
    telefono_reportante,
    email_reportante,
    id_empleado_asignado,
    empleado_asignado,
    agua_m3
  )
  SELECT
    raw_data:event_id::STRING,
    raw_data:source_system::STRING,
    raw_data:reported_at::TIMESTAMP_TZ,
    raw_data:id_inmueble::NUMBER,
    raw_data:direccion_ref::STRING,
    raw_data:id_contrato::NUMBER,
    raw_data:categoria::STRING,
    raw_data:prioridad::STRING,
    raw_data:estado_fuente::STRING,
    raw_data:descripcion::STRING,
    raw_data:reportante:tipo::STRING,
    raw_data:reportante:nombre::STRING,
    raw_data:reportante:documento::STRING,
    raw_data:reportante:telefono::STRING,
    raw_data:reportante:email::STRING,
    raw_data:empleado_asignado:id_empleado::NUMBER,
    raw_data:empleado_asignado:nombre::STRING,
    raw_data:lectura_medidor:agua_m3::FLOAT
  FROM RAW_SOLICITUD;
 
  INSERT OVERWRITE INTO STG_DANIOS_FLATTENED (
    event_id,
    id_inmueble,
    categoria,
    prioridad,
    area,
    detalle,
    severidad
  )
  SELECT
    raw_data:event_id::STRING,
    raw_data:id_inmueble::NUMBER,
    raw_data:categoria::STRING,
    raw_data:prioridad::STRING,
    d.value:area::STRING,
    d.value:detalle::STRING,
    d.value:severidad::NUMBER
  FROM RAW_SOLICITUD,
       LATERAL FLATTEN(input => raw_data:danios) d;
 
  INSERT OVERWRITE INTO STG_CONTACTOS_FLATTENED (
    event_id,
    id_inmueble,
    contacto_nombre,
    contacto_telefono,
    contacto_email,
    parentesco,
    ventana_preferida
  )
  SELECT
    raw_data:event_id::STRING,
    raw_data:id_inmueble::NUMBER,
    c.value:nombre::STRING,
    c.value:telefono::STRING,
    c.value:email::STRING,
    c.value:parentesco::STRING,
    c.value:ventana_preferida::STRING
  FROM RAW_SOLICITUD,
       LATERAL FLATTEN(input => raw_data:contactos_autorizados) c;
 
  INSERT OVERWRITE INTO STG_COTIZACIONES_FLATTENED (
    event_id,
    proveedor,
    telefono,
    valor_estimado,
    moneda
  )
  SELECT
    raw_data:event_id::STRING,
    q.value:proveedor::STRING,
    q.value:telefono::STRING,
    q.value:valor_estimado::NUMBER(14,2),
    q.value:moneda::STRING
  FROM RAW_SOLICITUD,
       LATERAL FLATTEN(input => raw_data:cotizaciones, OUTER => FALSE) q;
END;
 
SHOW TASKS IN SCHEMA MANTENIMIENTO;

ALTER TASK TASK_INGEST_SOLICITUDES_S3 RESUME
ALTER TASK TASK_STG_DESDE_RAW_SOLICITUD RESUME
 
EXECUTE TASK TASK_INGEST_SOLICITUDES_S3;
 
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = 'INMOBILIARIA_DW'
  AND schema_name = 'MANTENIMIENTO'
ORDER BY scheduled_time DESC;
