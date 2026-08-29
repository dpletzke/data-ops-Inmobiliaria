-- Dimensión de inmueble: una fila por inmueble con sus atributos y las personas
-- responsables (propietario dueño, empleado que lo captó). La consumen los modelos
-- de hechos para no repetir estos joins.

with inmuebles as (

    select * from {{ ref('stg_inmuebles') }}

),

propietarios as (

    select * from {{ ref('stg_propietarios') }}

),

empleados as (

    select * from {{ ref('stg_empleados') }}

),

final as (

    select
        i.id_inmueble,
        i.direccion,
        i.tipo_inmueble,
        i.area_m2,
        i.habitaciones,
        i.banos,
        i.valor_arriendo,
        i.valor_venta,
        i.estado                       as estado_inmueble,
        p.id_propietario,
        p.nombre                       as nombre_propietario,
        e.id_empleado                  as id_empleado_captador,
        e.nombre                       as nombre_empleado_captador

    from inmuebles i
    left join propietarios p on p.id_propietario = i.id_propietario
    left join empleados e    on e.id_empleado    = i.id_empleado_captador

)

select * from final
