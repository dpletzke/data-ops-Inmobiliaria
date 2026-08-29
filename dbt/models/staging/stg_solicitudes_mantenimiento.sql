-- Aplana el VARIANT de la fuente semi-estructurada a una fila por evento de solicitud.
-- Solo extracción y cast: la lógica de negocio (conteos, cruces) vive en la capa core.

with fuente as (

    select * from {{ source('raw_mantenimiento', 'raw_solicitud') }}

),

aplanado as (

    select
        raw_data:event_id::string                    as event_id,
        raw_data:source_system::string               as source_system,
        raw_data:reported_at::timestamp_tz           as reported_at,
        raw_data:id_inmueble::integer                as id_inmueble,
        raw_data:id_contrato::integer               as id_contrato,
        raw_data:categoria::string                   as categoria,
        raw_data:prioridad::string                   as prioridad,
        raw_data:estado_fuente::string               as estado_fuente,
        raw_data:descripcion::string                 as descripcion,
        raw_data:reportante:tipo::string             as tipo_reportante,
        raw_data:reportante:nombre::string           as nombre_reportante,
        raw_data:reportante:email::string            as email_reportante,
        raw_data:empleado_asignado:id_empleado::integer as id_empleado_asignado,
        raw_data:empleado_asignado:nombre::string    as nombre_empleado_asignado

    from fuente

)

select * from aplanado
