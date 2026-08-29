with fuente as (

    select * from {{ source('raw_inmobiliaria', 'empleado') }}

),

renombrado as (

    select
        id_empleado::integer            as id_empleado,
        id_rol::integer                 as id_rol,
        id_supervisor::integer          as id_supervisor,
        nombre::string                  as nombre,
        telefono::string                as telefono,
        fecha_contratacion::date        as fecha_contratacion,
        activo::boolean                 as activo

    from fuente

)

select * from renombrado
