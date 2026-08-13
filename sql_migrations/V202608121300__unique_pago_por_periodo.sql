-- ===========================================================================
-- V202608121300__unique_pago_por_periodo.sql
-- ===========================================================================

ALTER TABLE pago ADD CONSTRAINT uq_pago_contrato_periodo
    UNIQUE (id_contrato, periodo);
