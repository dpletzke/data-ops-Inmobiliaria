with fuente as (

    select * from {{ source('raw_inmobiliaria', 'propietario') }}

),

renombrado as (

    select
        id_propietario::integer     as id_propietario,
        nombre::string              as nombre,
        documento_identidad::string as documento_identidad,
        telefono::string            as telefono,
        email::string               as email

    from fuente

)

select * from renombrado
