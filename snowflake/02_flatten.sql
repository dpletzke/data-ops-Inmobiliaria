USE WAREHOUSE WH_INMOBILIARIA;
USE DATABASE INMOBILIARIA_DW;
USE SCHEMA MANTENIMIENTO;

SELECT
  raw_data:event_id::STRING             AS event_id,
  raw_data:source_system::STRING        AS source_system,
  raw_data:reported_at::TIMESTAMP_TZ    AS reported_at,
  raw_data:id_inmueble::NUMBER          AS id_inmueble,
  raw_data:id_contrato::NUMBER          AS id_contrato,
  raw_data:categoria::STRING            AS categoria,
  raw_data:prioridad::STRING            AS prioridad,
  raw_data:estado_fuente::STRING        AS estado_fuente,
  raw_data:reportante:tipo::STRING      AS tipo_reportante,
  raw_data:reportante:nombre::STRING    AS nombre_reportante,
  raw_data:reportante:telefono::STRING  AS telefono_reportante,
  raw_data:reportante:email::STRING     AS email_reportante,
FROM RAW_SOLICITUD
ORDER BY reported_at;
 
SELECT
  raw_data:event_id::STRING AS event_id,
  d.value:area::STRING      AS area,
  d.value:detalle::STRING   AS detalle,
  d.value:severidad::NUMBER AS severidad
FROM RAW_SOLICITUD,
     LATERAL FLATTEN(input => raw_data:danios) d
ORDER BY event_id, severidad DESC;
 
SELECT
  raw_data:event_id::STRING              AS event_id,
  c.value:nombre::STRING                 AS contacto_nombre,
  c.value:telefono::STRING               AS contacto_telefono,
  c.value:email::STRING                  AS contacto_email,
  c.value:ventana_preferida::STRING      AS ventana_preferida
FROM RAW_SOLICITUD,
     LATERAL FLATTEN(input => raw_data:contactos_autorizados) c
ORDER BY event_id, contacto_nombre;

CREATE TABLE IF NOT EXISTS STG_SOLICITUD (
    event_id              STRING,
    source_system         STRING,
    reported_at           TIMESTAMP_TZ,
    id_inmueble           NUMBER,
    direccion_ref         STRING,
    id_contrato           NUMBER,
    categoria             STRING,
    prioridad             STRING,
    estado_fuente         STRING,
    descripcion           STRING,
    tipo_reportante       STRING,
    nombre_reportante     STRING,
    documento_reportante  STRING,
    telefono_reportante   STRING,
    email_reportante      STRING,
    id_empleado_asignado  NUMBER,
    empleado_asignado     STRING,
    agua_m3               FLOAT,
    lectura_registrada_at TIMESTAMP_TZ
);

TRUNCATE TABLE STG_SOLICITUD
 
INSERT INTO STG_SOLICITUD(
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

SELECT * FROM STG_SOLICITUD;

CREATE TABLE IF NOT EXISTS STG_DANIOS_FLATTENED (
    event_id       STRING,
    id_inmueble    NUMBER,
    categoria      STRING,
    prioridad      STRING,
    area           STRING,
    detalle        STRING,
    severidad      NUMBER,
     _flattened_at            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
 
TRUNCATE TABLE STG_DANIOS_FLATTENED
 
INSERT INTO STG_DANIOS_FLATTENED (event_id,id_inmueble,categoria,prioridad,area,detalle,severidad)
SELECT
  raw_data:event_id::STRING,
  raw_data:id_inmueble::NUMBER,
  raw_data:categoria::STRING,
  raw_data:prioridad::STRING,
  d.value:area::STRING,
  d.value:detalle::STRING,
  d.value:severidad::NUMBER,
FROM RAW_SOLICITUD,
     LATERAL FLATTEN(input => raw_data:danios) d;

SELECT * FROM STG_DANIOS_FLATTENED;

CREATE TABLE IF NOT EXISTS STG_CONTACTOS_FLATTENED (
    event_id             STRING,
    id_inmueble          NUMBER,
    contacto_nombre      STRING,
    contacto_telefono    STRING,
    contacto_email       STRING,
    parentesco           STRING,
    ventana_preferida    STRING,
    _flattened_at            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
 
TRUNCATE TABLE STG_CONTACTOS_FLATTENED
 
INSERT INTO STG_CONTACTOS_FLATTENED (event_id,id_inmueble,contacto_nombre,contacto_telefono,contacto_email,parentesco,ventana_preferida)
SELECT
  raw_data:event_id::STRING,
  raw_data:id_inmueble::NUMBER,
  c.value:nombre::STRING,
  c.value:telefono::STRING,
  c.value:email::STRING,
  c.value:parentesco::STRING,
  c.value:ventana_preferida::STRING,
FROM RAW_SOLICITUD,
     LATERAL FLATTEN(input => raw_data:contactos_autorizados) c;

SELECT * FROM STG_CONTACTOS_FLATTENED;

CREATE TABLE IF NOT EXISTS STG_COTIZACIONES_FLATTENED (
    event_id        STRING,
    proveedor       STRING,
    telefono        STRING,
    valor_estimado  NUMBER(14,2),
    moneda          STRING,
    _flattened_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
 
TRUNCATE TABLE STG_COTIZACIONES_FLATTENED
 
INSERT INTO STG_COTIZACIONES_FLATTENED (event_id,proveedor,telefono,valor_estimado,moneda)
SELECT
  raw_data:event_id::STRING,
  q.value:proveedor::STRING,
  q.value:telefono::STRING,
  q.value:valor_estimado::NUMBER(14,2),
  q.value:moneda::STRING,
FROM RAW_SOLICITUD,
     LATERAL FLATTEN(input => raw_data:cotizaciones, OUTER => FALSE) q;

SELECT * FROM STG_COTIZACIONES_FLATTENED;