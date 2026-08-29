with fuente as (

    select * from {{ source('raw_inmobiliaria', 'pago') }}

),

renombrado as (

    select
        id_pago::integer     as id_pago,
        id_contrato::integer  as id_contrato,
        fecha_pago::date      as fecha_pago,
        periodo::date         as periodo,
        monto::float          as monto,
        tipo_pago::string     as tipo_pago,
        estado_pago::string   as estado_pago

    from fuente

)

select * from renombrado
