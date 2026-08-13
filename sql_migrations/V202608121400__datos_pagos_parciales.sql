-- ===========================================================================
-- V202608121400__datos_pagos_parciales.sql
-- ===========================================================================

-- Primer abono: 60 % del canon.
INSERT INTO pago (id_contrato, fecha_pago, periodo, monto, tipo_pago, estado_pago)
SELECT c.id_contrato,
       DATE '2026-08-03',
       DATE '2026-08-01',
       (c.valor_total * 0.60)::numeric(14,2),
       'transferencia',
       'aplicado'
FROM contrato c
WHERE c.tipo_contrato = 'arriendo'
  AND c.estado        = 'activo'
  AND c.fecha_fin     > DATE '2026-08-01'
  AND c.id_contrato % 29 = 0;

-- Segundo abono: el 40 % restante. Mismo contrato, mismo periodo.
INSERT INTO pago (id_contrato, fecha_pago, periodo, monto, tipo_pago, estado_pago)
SELECT c.id_contrato,
       DATE '2026-08-19',
       DATE '2026-08-01',
       (c.valor_total * 0.40)::numeric(14,2),
       'efectivo',
       'aplicado'
FROM contrato c
WHERE c.tipo_contrato = 'arriendo'
  AND c.estado        = 'activo'
  AND c.fecha_fin     > DATE '2026-08-01'
  AND c.id_contrato % 29 = 0;
