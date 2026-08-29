with fuente as (

    select * from {{ source('raw_inmobiliaria', 'cliente') }}

),

renombrado as (

    select
        id_cliente::integer as id_cliente,
        nombre::string      as nombre,
        telefono::string    as telefono,
        email::string       as email

    from fuente

)

select * from renombrado
