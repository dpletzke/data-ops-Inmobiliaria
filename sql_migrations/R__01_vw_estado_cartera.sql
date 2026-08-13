-- ===========================================================================
-- R__01_vw_estado_cartera.sql
-- ===========================================================================

CREATE OR REPLACE VIEW vw_estado_cartera AS
WITH periodos_causados AS (
    SELECT c.id_contrato,
           date_trunc('month', m)::date AS periodo,
           c.valor_total                AS canon
    FROM contrato c
    CROSS JOIN LATERAL generate_series(
            c.fecha_inicio,
            LEAST(c.fecha_fin, CURRENT_DATE),
            INTERVAL '1 month') AS m
    WHERE c.tipo_contrato = 'arriendo'
      AND c.estado        = 'activo'
),
recaudo AS (
    SELECT id_contrato, periodo, SUM(monto) AS pagado
    FROM pago
    WHERE estado_pago = 'aplicado'
    GROUP BY id_contrato, periodo
)
SELECT
    c.id_contrato,
    c.id_inmueble,
    i.direccion,
    cl.nombre                                                    AS cliente,
    e.nombre                                                     AS empleado_responsable,
    COUNT(*)                                                     AS periodos_causados,
    SUM(pc.canon)                                                AS total_causado,
    COALESCE(SUM(r.pagado), 0)                                   AS total_recaudado,
    SUM(pc.canon) - COALESCE(SUM(r.pagado), 0)                   AS saldo_pendiente,
    COUNT(*) FILTER (WHERE COALESCE(r.pagado, 0) < pc.canon)     AS periodos_en_mora,
    COUNT(*) FILTER (WHERE COALESCE(r.pagado, 0) < pc.canon) > 0 AS en_mora
FROM periodos_causados pc
JOIN contrato  c  ON c.id_contrato  = pc.id_contrato
JOIN inmueble  i  ON i.id_inmueble  = c.id_inmueble
JOIN cliente   cl ON cl.id_cliente  = c.id_cliente
JOIN empleado  e  ON e.id_empleado  = c.id_empleado
LEFT JOIN recaudo r ON r.id_contrato = pc.id_contrato
                   AND r.periodo     = pc.periodo
GROUP BY c.id_contrato, c.id_inmueble, i.direccion, cl.nombre, e.nombre;
