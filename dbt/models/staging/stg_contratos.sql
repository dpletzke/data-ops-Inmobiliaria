with fuente as (

    select * from {{ source('raw_inmobiliaria', 'contrato') }}

),

renombrado as (

    select
        id_contrato::integer  as id_contrato,
        id_inmueble::integer   as id_inmueble,
        id_cliente::integer    as id_cliente,
        id_empleado::integer   as id_empleado,
        tipo_contrato::string  as tipo_contrato,
        fecha_inicio::date     as fecha_inicio,
        fecha_fin::date        as fecha_fin,
        valor_total::float     as valor_total,
        estado::string         as estado

    from fuente

)

select * from renombrado
