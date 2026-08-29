-- Un daño por fila: expande el arreglo raw_data:danios de cada evento con LATERAL FLATTEN.
-- Varias filas comparten event_id; la agregación por inmueble ocurre en core.

with fuente as (

    select * from {{ source('raw_mantenimiento', 'raw_solicitud') }}

),

aplanado as (

    select
        raw_data:event_id::string     as event_id,
        raw_data:id_inmueble::integer as id_inmueble,
        raw_data:categoria::string    as categoria,
        raw_data:prioridad::string    as prioridad,
        d.value:area::string          as area,
        d.value:detalle::string       as detalle,
        d.value:severidad::integer    as severidad

    from fuente,
         lateral flatten(input => raw_data:danios) d

)

select * from aplanado
