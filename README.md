# data-ops-Inmobiliaria

Pipeline de CI/CD para el esquema de una base de datos de una inmobiliaria,
usando Neon (PostgreSQL), Flyway y GitHub Actions.

Ver [docs/dominio_de_negocio.md](docs/dominio_de_negocio.md) para la
descripción del dominio y el diagrama entidad-relación.

## Stack

- **Neon.tech** — PostgreSQL gestionado, con dos branches: `dev` y `main`.
- **Flyway** — versionado y migración del esquema.
- **GitHub Actions** — aplica las migraciones automáticamente
  ([`.github/workflows/flyway-migrate.yml`](.github/workflows/flyway-migrate.yml)).

## Estructura

```
sql_migrations/   Migraciones Flyway (V__ versionadas, R__ repetibles)
docs/             Documento de dominio y evidencias de runs en Actions
flyway.conf.example   Plantilla de configuración local
```

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

## Secretos requeridos

Configurados en `Settings → Secrets and variables → Actions` del repositorio:

| Secreto | Contenido |
|---|---|
| `NEON_DEV_DATABASE_URL` | Connection string de la branch `dev` de Neon |
| `NEON_MAIN_DATABASE_URL` | Connection string de la branch `main` de Neon |

Ambos en el formato que entrega Neon Console:
`postgresql://usuario:clave@host.neon.tech/neondb?sslmode=require`, usando el
endpoint directo (sin `-pooler`).
