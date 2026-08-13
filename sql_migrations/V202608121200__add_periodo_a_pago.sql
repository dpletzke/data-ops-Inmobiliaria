-- ===========================================================================
-- V202608121200__add_periodo_a_pago.sql
-- ===========================================================================

ALTER TABLE pago ADD COLUMN periodo DATE;

UPDATE pago SET periodo = date_trunc('month', fecha_pago)::date;

ALTER TABLE pago ALTER COLUMN periodo SET NOT NULL;

ALTER TABLE pago ADD CONSTRAINT chk_pago_periodo_primer_dia
    CHECK (periodo = date_trunc('month', periodo)::date);
