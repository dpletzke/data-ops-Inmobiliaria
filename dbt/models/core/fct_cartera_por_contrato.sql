-- Pregunta de negocio: por cada contrato de arriendo activo, ¿cuánto se ha causado
-- (canon mensual x meses transcurridos), cuánto se ha recaudado con pagos aplicados y
-- cuál es el saldo pendiente y el estado de mora?
--
-- Grano: una fila por contrato de arriendo activo.
-- Réplica en dbt de la vista operacional vw_estado_cartera, sobre modelos Silver.

with contratos as (

    select * from {{ ref('stg_contratos') }}

),

pagos as (

    select * from {{ ref('stg_pagos') }}

),

inmuebles as (

    select * from {{ ref('dim_inmueble') }}

),

clientes as (

    select * from {{ ref('stg_clientes') }}

),

-- Un periodo (mes) causado por cada mes transcurrido entre el inicio del contrato y
-- hoy (o su fecha de fin, si ya pasó). Cada periodo causa un canon = valor_total.
periodos_causados as (

    select
        c.id_contrato,
        c.valor_total as canon,
        dateadd(
            'month',
            row_number() over (partition by c.id_contrato order by seq.seq) - 1,
            date_trunc('month', c.fecha_inicio)
        )::date as periodo

    from contratos c
    join table(generator(rowcount => 120)) seq
        on seq.seq <= datediff(
            'month',
            date_trunc('month', c.fecha_inicio),
            date_trunc('month', least(coalesce(c.fecha_fin, current_date()), current_date()))
        ) + 1
    where c.tipo_contrato = 'arriendo'
      and c.estado = 'activo'

),

recaudo_por_periodo as (

    select
        id_contrato,
        periodo,
        sum(monto) as pagado

    from pagos
    where estado_pago = 'aplicado'
    group by id_contrato, periodo

),

por_contrato as (

    select
        pc.id_contrato,
        count(*)                                                  as periodos_causados,
        sum(pc.canon)                                             as total_causado,
        coalesce(sum(r.pagado), 0)                                as total_recaudado,
        sum(pc.canon) - coalesce(sum(r.pagado), 0)                as saldo_pendiente,
        count_if(coalesce(r.pagado, 0) < pc.canon)                as periodos_en_mora

    from periodos_causados pc
    left join recaudo_por_periodo r
        on r.id_contrato = pc.id_contrato
       and r.periodo = pc.periodo
    group by pc.id_contrato

),

final as (

    select
        c.id_contrato,
        c.id_inmueble,
        i.direccion,
        cl.nombre                             as cliente,
        c.valor_total                         as canon_mensual,
        pc.periodos_causados,
        pc.total_causado,
        pc.total_recaudado,
        pc.saldo_pendiente,
        pc.periodos_en_mora,
        (pc.periodos_en_mora > 0)             as en_mora

    from contratos c
    join por_contrato pc on pc.id_contrato = c.id_contrato
    left join inmuebles i on i.id_inmueble = c.id_inmueble
    left join clientes cl on cl.id_cliente = c.id_cliente

)

select * from final
