# Dominio de negocio — Inmobiliaria

Este proyecto modela la operación de una **inmobiliaria** que administra inmuebles
en arriendo o venta a nombre de terceros (propietarios). Un equipo de empleados,
organizado en una jerarquía simple (director → coordinadores → asesores /
personal de mantenimiento), capta inmuebles, gestiona contratos con clientes y
da seguimiento a los pagos y solicitudes de mantenimiento de cada inmueble. El
esquema cubre el ciclo completo: captación del inmueble, firma del contrato,
registro de pagos (incluyendo abonos parciales dentro de un mismo periodo) y
solicitudes de mantenimiento asociadas al inmueble.

## Diagrama entidad-relación

```mermaid
erDiagram
    ROL_EMPLEADO ||--o{ EMPLEADO : clasifica
    EMPLEADO ||--o{ EMPLEADO : supervisa
    EMPLEADO ||--o{ INMUEBLE : capta
    EMPLEADO ||--o{ CONTRATO : gestiona
    EMPLEADO ||--o{ SOLICITUD_MANTENIMIENTO : atiende
    PROPIETARIO ||--o{ INMUEBLE : posee
    INMUEBLE ||--o{ CONTRATO : "objeto de"
    INMUEBLE ||--o{ SOLICITUD_MANTENIMIENTO : origina
    CLIENTE ||--o{ CONTRATO : firma
    CONTRATO ||--o{ PAGO : recibe

    ROL_EMPLEADO {
        int id_rol PK
        text nombre_rol
        text descripcion
    }
    EMPLEADO {
        int id_empleado PK
        int id_rol FK
        int id_supervisor FK
        text nombre
        text telefono
        date fecha_contratacion
        bool activo
    }
    PROPIETARIO {
        int id_propietario PK
        text nombre
        text documento_identidad
        text telefono
        text email
    }
    CLIENTE {
        int id_cliente PK
        text nombre
        text telefono
        text email
    }
    INMUEBLE {
        int id_inmueble PK
        int id_propietario FK
        int id_empleado_captador FK
        text direccion
        text tipo_inmueble
        numeric area_m2
        smallint habitaciones
        smallint banos
        numeric valor_arriendo
        numeric valor_venta
        text estado
    }
    CONTRATO {
        int id_contrato PK
        int id_inmueble FK
        int id_cliente FK
        int id_empleado FK
        text tipo_contrato
        date fecha_inicio
        date fecha_fin
        numeric valor_total
        text estado
    }
    PAGO {
        int id_pago PK
        int id_contrato FK
        date fecha_pago
        date periodo
        numeric monto
        text tipo_pago
        text estado_pago
    }
    SOLICITUD_MANTENIMIENTO {
        int id_solicitud PK
        int id_inmueble FK
        int id_empleado FK
        date fecha_solicitud
        text descripcion
        text estado
    }
```

## Entidades

- **rol_empleado / empleado** — jerarquía interna del equipo (director,
  coordinador, asesor comercial, mantenimiento). Un empleado puede supervisar
  a otros (`id_supervisor` referencia a `empleado`).
- **propietario** — dueño del inmueble, ajeno a la operación de la inmobiliaria.
- **cliente** — quien arrienda o compra un inmueble.
- **inmueble** — captado por un empleado a nombre de un propietario; tiene
  precio de arriendo y/o de venta, y un estado (`disponible`, `arrendado`,
  `vendido`, `retirado`).
- **contrato** — vincula un inmueble, un cliente y el empleado responsable;
  puede ser de arriendo (con fecha de fin obligatoria) o de venta.
- **pago** — pagos asociados a un contrato, agrupados por `periodo` (mes). Un
  mismo periodo puede tener varios pagos si el cliente paga en abonos.
- **solicitud_mantenimiento** — reportes sobre un inmueble, opcionalmente
  asignados a un empleado de mantenimiento.

Este diagrama refleja el esquema tal como queda tras aplicar todas las
migraciones en `sql_migrations/` (baseline + evolutivas + repetible).
