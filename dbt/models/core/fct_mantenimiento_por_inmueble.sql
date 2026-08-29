-- Pregunta de negocio: ¿qué carga de mantenimiento acumula cada inmueble y cómo se
-- relaciona con su situación contractual? Sirve para priorizar intervenciones en
-- inmuebles con contrato activo y daños severos abiertos.
--
-- Este es el modelo Gold que CRUZA LOS DOS ORÍGENES del proyecto:
--   - eventos JSON de mantenimiento (fuente semi-estructurada, S3 → external stage)
--   - inventario y contratos relacionales (fuente relacional, Neon → ELT)
-- El join es por id_inmueble.
--
-- Grano: una fila por inmueble presente en el catálogo relacional.

with solicitudes as (

    select * from {{ ref('stg_solicitudes_mantenimiento') }}

),

danios as (

    select * from {{ ref('stg_danios_mantenimiento') }}

),

inmuebles as (

    select * from {{ ref('dim_inmueble') }}

),

contratos as (

    select * from {{ ref('stg_contratos') }}

),

solicitudes_por_inmueble as (

    select
        id_inmueble,
        count(*)                              as num_solicitudes,
        count_if(estado_fuente = 'abierta')   as num_solicitudes_abiertas,
        count_if(prioridad = 'critica')       as num_solicitudes_criticas,
        max(reported_at)                      as ultima_solicitud_at

    from solicitudes
    group by id_inmueble

),

danios_por_inmueble as (

    select
        id_inmueble,
        count(*)                as num_danios,
        max(severidad)          as severidad_maxima,
        round(avg(severidad), 2) as severidad_promedio

    from danios
    group by id_inmueble

),

contrato_activo as (

    select distinct id_inmueble
    from contratos
    where estado = 'activo'

),

final as (

    select
        i.id_inmueble,
        i.direccion,
        i.tipo_inmueble,
        i.estado_inmueble,
        i.nombre_propietario,
        coalesce(s.num_solicitudes, 0)          as num_solicitudes,
        coalesce(s.num_solicitudes_abiertas, 0) as num_solicitudes_abiertas,
        coalesce(s.num_solicitudes_criticas, 0) as num_solicitudes_criticas,
        coalesce(d.num_danios, 0)               as num_danios,
        d.severidad_maxima,
        d.severidad_promedio,
        s.ultima_solicitud_at,
        (ca.id_inmueble is not null)            as tiene_contrato_activo,
        (
            ca.id_inmueble is not null
            and coalesce(s.num_solicitudes_abiertas, 0) > 0
            and coalesce(d.severidad_maxima, 0) >= 4
        )                                       as requiere_atencion_prioritaria

    from inmuebles i
    left join solicitudes_por_inmueble s on s.id_inmueble = i.id_inmueble
    left join danios_por_inmueble d      on d.id_inmueble = i.id_inmueble
    left join contrato_activo ca         on ca.id_inmueble = i.id_inmueble

)

select * from final
