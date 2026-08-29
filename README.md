# data-ops-Inmobiliaria

Plataforma de datos para una inmobiliaria, en dos capas:

1. **Operacional** — el esquema transaccional en Neon (PostgreSQL), versionado
   con Flyway y desplegado por GitHub Actions.
2. **Analítica** — un data warehouse en Snowflake alimentado por dos fuentes:
   un ELT relacional desde Neon y una ingesta de eventos JSON desde S3,
   procesada con Tasks y protegida con masking policies.

Ver [docs/dominio_de_negocio.md](docs/dominio_de_negocio.md) para la
descripción del dominio y el diagrama entidad-relación.

## Stack

- **Neon.tech** — PostgreSQL gestionado, con dos branches: `dev` y `main`.
- **Flyway** — versionado y migración del esquema operacional.
- **GitHub Actions** — aplica las migraciones automáticamente
  ([`.github/workflows/flyway-migrate.yml`](.github/workflows/flyway-migrate.yml)).
- **Snowflake** — warehouse `WH_INMOBILIARIA`, base `INMOBILIARIA_DW`, con los
  schemas `RAW` (carga relacional desde Neon) y `MANTENIMIENTO` (eventos JSON).
- **Python + uv** — el script de ELT ([`elt_postgres_to_snowflake.py`](elt_postgres_to_snowflake.py)).
- **dbt** — transforma RAW en modelos Silver/Gold dentro de Snowflake, corrido
  por GitHub Actions ([`dbt/`](dbt/)).

## Estructura

```
sql_migrations/            Migraciones Flyway (V__ versionadas, R__ repetibles)
snowflake/                 Scripts SQL del warehouse, en orden de ejecución
elt_postgres_to_snowflake.py   ELT Neon -> Snowflake (schema RAW)
external_data/             JSON de solicitudes de mantenimiento (fuente para S3)
dbt/                       Proyecto dbt: modelos staging (Silver) y core (Gold)
docs/                      Documento de dominio y evidencias de runs en Actions
flyway.conf.example        Plantilla de configuración de Flyway
.env.example               Plantilla de credenciales de Neon y Snowflake
```

---

# Capa operacional — Neon + Flyway

## Ejecutar las migraciones localmente

Requiere [Docker](https://www.docker.com/) y una connection string de Neon
(Console → Connection Details, endpoint **directo**, no el `-pooler`).

1. Copiar la plantilla de configuración:

   ```bash
   cp flyway.conf.example flyway.conf
   ```

2. Completar `flyway.url`, `flyway.user` y `flyway.password` en `flyway.conf`
   con los datos de tu branch de Neon. `flyway.conf` está en `.gitignore` y
   nunca debe commitearse.

3. Correr Flyway vía Docker:

   ```bash
   docker run --rm \
     -v "$(pwd)/sql_migrations:/flyway/sql:ro" \
     -v "$(pwd)/flyway.conf:/flyway/conf/flyway.conf:ro" \
     flyway/flyway:13.1.0-alpine \
     migrate
   ```

   Cambiar `migrate` por `info` o `validate` según se necesite.

## Agregar una migración nueva

- **Evolutiva** (cambio de esquema o datos puntuales): crear un archivo en
  `sql_migrations/` con el nombre `V<timestamp>__descripcion.sql`, por ejemplo
  `V202608130900__add_columna_x.sql`. El timestamp determina el orden de
  aplicación — debe ser mayor al de la última migración versionada.
- **Repetible** (funciones, vistas, procedimientos): `R__descripcion.sql`. Se
  vuelve a aplicar cada vez que cambia su contenido.
- Nunca editar una migración `V__` ya aplicada en algún ambiente: Flyway
  valida su checksum y el pipeline falla si no coincide. Las correcciones se
  hacen con una migración nueva (roll forward) — ver
  [docs/evidencias/roll_forward_unique_pago_periodo.md](docs/evidencias/roll_forward_unique_pago_periodo.md)
  para un ejemplo real.

Al hacer push, el workflow aplica automáticamente las migraciones pendientes:
un pull request contra `main` migra la branch `dev` de Neon; un push a `main`
migra la branch `main`.

---

# Capa analítica — Snowflake

## Preparar la cuenta

Ejecutar en un Worksheet de Snowsight, con rol `ACCOUNTADMIN`:

```
snowflake/setup.sql        Warehouse, base INMOBILIARIA_DW, schema RAW y rol
                           de servicio INMOBILIARIA_DATAOPS_LOADER
```

## ELT relacional: Neon → schema RAW

[`elt_postgres_to_snowflake.py`](elt_postgres_to_snowflake.py) extrae las
tablas operacionales (`rol_empleado`, `empleado`, `propietario`, `cliente`,
`inmueble`, `contrato`, `pago`) desde la branch `dev` de Neon y las carga sin
transformar en `INMOBILIARIA_DW.RAW`. Es ELT, no ETL: la transformación ocurre
después, dentro de Snowflake.

Configuración:

```bash
cp .env.example .env    # completar credenciales de Neon y Snowflake
uv sync
```

Uso:

```bash
uv run elt_postgres_to_snowflake.py                   # carga todas las tablas
uv run elt_postgres_to_snowflake.py --tabla pago      # solo una tabla
uv run elt_postgres_to_snowflake.py --solo-verificar  # detecta drift, no escribe
```

Si una tabla en Neon gana una columna que la tabla destino no tiene, el script
**falla antes de escribir** y muestra el `ALTER TABLE` que resuelve el drift,
para aplicarlo a mano en Snowsight. Cada carga usa `overwrite=True`: la capa
RAW es un reflejo completo del origen, no un incremental.

## Ingesta de eventos JSON: S3 → schema MANTENIMIENTO

Las solicitudes de mantenimiento llegan como JSON anidado desde un sistema
externo. Los archivos de ejemplo están en [`external_data/`](external_data/) y
se suben a un bucket S3 que Snowflake lee vía external stage.

Scripts, en orden:

| Script | Qué hace |
|---|---|
| [`snowflake/01_setup_stage_and_raw.sql`](snowflake/01_setup_stage_and_raw.sql) | Schema `MANTENIMIENTO`, file format JSON, external stage sobre S3 y tabla `RAW_SOLICITUD (raw_data VARIANT)` |
| [`snowflake/02_flatten.sql`](snowflake/02_flatten.sql) | Aplana el VARIANT en tablas de staging: `STG_SOLICITUD` y, con `LATERAL FLATTEN`, `STG_DANIOS_FLATTENED`, `STG_CONTACTOS_FLATTENED` y `STG_COTIZACIONES_FLATTENED` |
| [`snowflake/03_tasks_staging_from_raw_solicitud.sql.sql`](snowflake/03_tasks_staging_from_raw_solicitud.sql.sql) | Automatiza lo anterior como un DAG de Tasks: `TASK_INGEST_SOLICITUDES_S3` (cron horario) → `TASK_STG_DESDE_RAW_SOLICITUD` |
| [`snowflake/04_masking.sql`](snowflake/04_masking.sql) | Roles `ROLE_DATA_ENGINEER` / `ROLE_DATA_ANALYST` y masking policies sobre el teléfono y el email de los contactos |

El enmascaramiento es dinámico y depende del rol de la sesión: el data
engineer ve el dato crudo, el analista ve el contacto parcialmente oculto
(`+57-300-***`, `iv***@correo.co`) y cualquier otro rol no ve nada útil.

---

# Capa de modelado — dbt (Momento 3)
Proyecto dbt que transforma los datos crudos del warehouse en modelos listos para
consumo analítico, bajo arquitectura Medallón, con tests de calidad y automatización
por GitHub Actions.
## Arquitectura
```
Fuentes crudas (Bronze)                Silver (staging/)              Gold (core/)
──────────────────────                 ────────────────              ────────────
INMOBILIARIA_DW.RAW          ─┐        stg_inmuebles      ─┐
  (ELT relacional, Momento 2) │        stg_contratos       │         dim_inmueble
                              ├──────► stg_pagos           ├───────► fct_cartera_por_contrato
INMOBILIARIA_DW.MANTENIMIENTO │        stg_clientes        │         fct_mantenimiento_por_inmueble
  (eventos JSON, Momento 2)  ─┘        stg_empleados       │           (cruza los dos orígenes)
                                       stg_propietarios    │
                                       stg_solicitudes_... │
                                       stg_danios_...     ─┘
```
- **staging/** (Silver) — una view por fuente: solo `cast` y `rename`, usando
  `source()`. Los modelos sobre `raw_solicitud` aplanan el VARIANT (uno con
  `LATERAL FLATTEN` sobre `danios`).
- **core/** (Gold) — tables, usando `ref()` exclusivamente. Nunca consultan `source()`.
### Preguntas de negocio que responde la capa Gold
| Modelo | Pregunta | Grano |
|---|---|---|
| `fct_cartera_por_contrato` | ¿Cuánto se ha causado, recaudado y qué saldo/mora tiene cada contrato de arriendo activo? | 1 fila / contrato |
| `fct_mantenimiento_por_inmueble` | ¿Qué carga de mantenimiento acumula cada inmueble y cuáles requieren atención prioritaria? | 1 fila / inmueble |
| `dim_inmueble` | Dimensión de apoyo: inmueble + propietario + captador | 1 fila / inmueble |
`fct_mantenimiento_por_inmueble` es el modelo que **cruza los dos orígenes**: eventos
JSON de mantenimiento (semi-estructurado) contra el inventario y los contratos
relacionales, por `id_inmueble`.
## Preparar Snowflake (una vez)
Ejecutar en un Worksheet con rol `ACCOUNTADMIN`:
```
snowflake/05_setup_dbt.sql   -- crea schemas STAGING y CORE, otorga grants al rol de dbt
```
## Correr localmente
```bash
cd dbt
cp .env.example .env          # completar credenciales de Snowflake
set -a && source .env && set +a
uv sync
uv run dbt deps    --profiles-dir .
uv run dbt debug   --profiles-dir .   # "All checks passed"
uv run dbt build   --profiles-dir .   # run + test de todos los modelos
uv run dbt docs generate --profiles-dir .
uv run dbt docs serve    --profiles-dir .   # lineage graph en el navegador
```
`dbt build` = `dbt run` + `dbt test` respetando el DAG. Si un test de Silver falla,
los modelos Gold que dependen de él no se construyen.
## Tests de calidad
- **Genéricos** (`unique`, `not_null`, `accepted_values`, `relationships`) sobre las
  llaves y relaciones de todos los modelos Silver y Gold.
- **`dbt-expectations`** (paquete `metaplane/dbt_expectations`), cada uno con su
  justificación de negocio comentada en el `.yml`:
  - `stg_pagos.monto` entre 0 y 100 M — detecta errores de escala (centavos vs pesos).
  - `stg_danios_mantenimiento.severidad` entre 1 y 5 — escala definida por la fuente.
  - `stg_solicitudes_mantenimiento.email_reportante` con formato de correo válido.
  - `fct_cartera_por_contrato.saldo_pendiente` en rango razonable — detecta doble
    contabilización de periodos.
  - `fct_mantenimiento_por_inmueble.severidad_maxima` entre 1 y 5.
## Automatización
[`.github/workflows/dbt-build.yml`](../.github/workflows/dbt-build.yml) corre
`uv sync` → `dbt deps` → `dbt build` en cada push a `main` que toque `dbt/**`, en
`workflow_dispatch` y en un cron diario (07:00 UTC).
Secretos requeridos en `Settings → Secrets and variables → Actions`:
`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`, `SNOWFLAKE_ROLE`,
`SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_SCHEMA`.
`profiles.yml` está versionado a propósito: no contiene credenciales (todos los
valores se resuelven con `env_var()`), y el workflow lo necesita.
## Evidencias
En [`../docs/evidencias/`](../docs/evidencias/):
- `dbt_build_local.txt` — salida de `dbt build` local.
- `lineage_graph.png` — captura del lineage de `dbt docs`.
- `gha_dbt_build_run.md` — enlace a la corrida exitosa de GitHub Actions.

---

## Secretos y credenciales

**GitHub Actions** — en `Settings → Secrets and variables → Actions`:

| Secreto | Contenido |
|---|---|
| `NEON_DEV_DATABASE_URL` | Connection string de la branch `dev` de Neon |
| `NEON_MAIN_DATABASE_URL` | Connection string de la branch `main` de Neon |
| `SNOWFLAKE_ACCOUNT` / `SNOWFLAKE_USER` / `SNOWFLAKE_PASSWORD` | Credenciales de Snowflake para dbt |
| `SNOWFLAKE_ROLE` / `SNOWFLAKE_WAREHOUSE` / `SNOWFLAKE_DATABASE` / `SNOWFLAKE_SCHEMA` | Contexto de conexión de dbt |

Las dos de Neon en el formato que entrega Neon Console:
`postgresql://usuario:clave@host.neon.tech/neondb?sslmode=require`, usando el
endpoint directo (sin `-pooler`).

**Local** — `flyway.conf` (Flyway) y `.env` (ELT). Los dos están en
`.gitignore`; versionadas solo están las plantillas `flyway.conf.example` y
`.env.example`. `dbt/profiles.yml` sí está versionado — no tiene credenciales,
todo lo resuelve con `env_var()` en tiempo de ejecución.
