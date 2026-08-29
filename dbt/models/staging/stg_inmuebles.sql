with fuente as (

    select * from {{ source('raw_inmobiliaria', 'inmueble') }}

),

renombrado as (

    select
        id_inmueble::integer          as id_inmueble,
        id_propietario::integer       as id_propietario,
        id_empleado_captador::integer as id_empleado_captador,
        direccion::string             as direccion,
        tipo_inmueble::string         as tipo_inmueble,
        area_m2::float                as area_m2,
        habitaciones::integer         as habitaciones,
        banos::integer                as banos,
        valor_arriendo::float         as valor_arriendo,
        valor_venta::float            as valor_venta,
        estado::string                as estado

    from fuente

)

select * from renombrado
