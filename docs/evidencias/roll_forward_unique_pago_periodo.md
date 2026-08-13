# Evidencia — error de diseño y corrección vía roll forward

## Qué falló

`V202608121300__unique_pago_por_periodo.sql` agregó la restricción
`UNIQUE (id_contrato, periodo)` sobre `pago`, asumiendo que solo podía existir
un pago por contrato en cada periodo.

Esa restricción no reflejaba una regla real del negocio: un contrato puede
pagarse en varios abonos dentro del mismo periodo. Al aplicar
`V202608121400__datos_pagos_parciales.sql` que inserta un abono del 60 % y
otro del 40 % para el mismo contrato y el mismo periodo, la migración viola
el `UNIQUE` y el pipeline falla:

- **Run fallido:** https://github.com/dpletzke/data-ops-Inmobiliaria/actions/runs/31666609258

## Diagnóstico

El error no era sintáctico: el `UNIQUE` estaba mal concebido desde el diseño,
no le faltaba una columna. La vista `R__01_vw_estado_cartera.sql` ya agrupa y
suma pagos por `(id_contrato, periodo)`, así que soporta múltiples pagos por
periodo sin cambios — la restricción sobraba.

## Corrección vía roll forward

Se agregó `V202608121350__fix_unique_pago_periodo.sql`, que elimina el
`UNIQUE` (`DROP CONSTRAINT uq_pago_contrato_periodo`). No se editó
`V202608121300` ni `V202608121400`: Flyway ya había registrado sus checksums,
y modificarlas habría roto `validate` en el siguiente run.

El archivo se versionó como `V202608121350` entre `V1300` y `V1400`, para
que una reconstrucción desde cero también funcione: el `UNIQUE` se elimina
antes de que `V1400` intente insertar los dos abonos.

- **Run exitoso (con la corrección aplicada):** https://github.com/dpletzke/data-ops-Inmobiliaria/actions/runs/31667363018
