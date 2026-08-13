-- ===========================================================================
-- V202608121350__fix_unique_pago_periodo.sql
-- ===========================================================================

-- uq_pago_contrato_periodo (V202608121300) asumía un solo pago por contrato
-- y periodo. El negocio sí permite abonos: varios pagos parciales dentro del
-- mismo periodo para el mismo contrato, como en V202608121400. Se elimina la
-- restricción; vw_estado_cartera ya agrupa y suma por (id_contrato, periodo),
-- así que soporta múltiples pagos sin cambios.

ALTER TABLE pago
    DROP CONSTRAINT uq_pago_contrato_periodo;
