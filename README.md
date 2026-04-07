# Documentación del Sistema de Control de Operaciones de Renta de Vehículos

## Descripción General

Este repositorio contiene la documentación completa del sistema de control de operaciones de renta de vehículos. El sistema gestiona la sincronización entre dos entidades principales:

- **INVENTARIO**: Estado global del vehículo en el catálogo de la empresa.
- **OPERACION_UNIDADES**: Estado del vehículo dentro de una operación específica.

## Estructura del Repositorio

```
operacion-vehiculos-docs/
├── README.md                          ← Este archivo
├── docs/
│   ├── diagramas/
│   │   ├── 01-estado-inventario.puml          ← Máquina de estados INVENTARIO
│   │   ├── 02-estado-operacion-unidades.puml  ← Máquina de estados OPERACION_UNIDADES
│   │   ├── 03-erd-estructura-datos.puml        ← Diagrama Entidad-Relación
│   │   ├── 04-flujos-secuencia.puml            ← Flujos secuenciales críticos
│   │   ├── 05-sincronizacion-estados.puml      ← Diagrama de sincronización
│   │   └── 06-matriz-transiciones.puml         ← Matriz de transiciones
│   └── 07-validaciones-criticas.md             ← Validaciones y reglas de negocio
├── ejemplos/
│   ├── caso-1-operacion-simple.md              ← Operación básica de renta
│   ├── caso-2-multiples-periodos.md            ← Operación con múltiples periodos
│   ├── caso-3-unidades-reservadas.md           ← Manejo de unidades reservadas
│   └── caso-4-vencimiento-reactivacion.md      ← Vencimiento y reactivación
├── guias/
│   ├── guia-checkin.md                         ← Guía de proceso de checkin
│   ├── guia-checkout.md                        ← Guía de proceso de checkout
│   ├── guia-reactivacion.md                    ← Guía de reactivación de reservadas
│   └── troubleshooting.md                      ← Solución de problemas comunes
└── sql/
    └── implementacion.sql                      ← Scripts SQL de implementación
```

---

## Estados del Sistema

### INVENTARIO (Estado Global del Vehículo)

| Estado | Descripción |
|--------|-------------|
| `DISPONIBLE` | Unidad libre, lista para asignarse a operaciones |
| `EN_PROCESO` | Agregada a cotización, en espera de confirmación (máx. 15 min) |
| `APARTADO` | Confirmada para operación, en espera de documentación (checkin) |
| `RENTADO` | Entregada al cliente, en período de renta activa |
| `VENDIDO` | Unidad vendida (estado final) |
| `NO_DISPONIBLE` | Unidad fuera de servicio (estado terminal) |

### OPERACION_UNIDADES (Estado dentro de una Operación)

| Estado | Descripción |
|--------|-------------|
| `EN_PROCESO` | Recién agregada a operación, espera confirmación (máx. 15 min) |
| `VENCIDA` | Superó 15 minutos sin confirmación (Job automático) |
| `CONFIRMADA` | Operación confirmada, espera documentación para checkin |
| `EN_RENTA` | Vehículo en poder del cliente, operación activa |
| `FINALIZADA` | Devuelta correctamente, ciclo completado |
| `CANCELADA` | Operación cancelada, no participó |
| `RESERVADA` | Intención en futura operación (unidad ocupada en otra op. actualmente) |

---

## Características Especiales

### ⏱️ Timer de 15 Minutos (EN_PROCESO)
Cuando una unidad se agrega a una cotización, se inicia un temporizador de 15 minutos. Si la operación no se confirma en ese tiempo:
- `INVENTARIO` regresa a `DISPONIBLE`
- `OPERACION_UNIDADES` cambia a `VENCIDA`

### 🔄 Job Scheduler de Vencimiento
Proceso automático que se ejecuta periódicamente para detectar unidades en `EN_PROCESO` que hayan superado el límite de 15 minutos y actualizar sus estados en cascada.

### 🔒 Estado RESERVADA
Permite registrar la intención de incluir un vehículo en una operación futura cuando éste se encuentra actualmente ocupado en otra operación. **No sincroniza el INVENTARIO** (la unidad sigue en `RENTADO` a nivel global).

### ♻️ Reactivación de Unidades Reservadas
Cuando una unidad `RESERVADA` queda libre (su operación activa finaliza), puede ser reactivada:
- Valida que `INVENTARIO = DISPONIBLE`
- Cambia `OPERACION_UNIDADES` a `CONFIRMADA`
- Actualiza `INVENTARIO` a `APARTADO`

---

## Matriz de Transiciones Rápida

| Acción | INV Antes | OPUN Antes | INV Después | OPUN Después | Timer |
|--------|-----------|------------|-------------|--------------|-------|
| Agregar a cotización | `DISPONIBLE` | — | `EN_PROCESO` | `EN_PROCESO` | ⏱️ 15 min |
| Confirmar operación | `EN_PROCESO` | `EN_PROCESO` | `APARTADO` | `CONFIRMADA` | — |
| Checkin | `APARTADO` | `CONFIRMADA` | `RENTADO` | `EN_RENTA` | — |
| Checkout | `RENTADO` | `EN_RENTA` | `DISPONIBLE` | `FINALIZADA` | — |
| Vencimiento (Job) | `EN_PROCESO` | `EN_PROCESO` | `DISPONIBLE` | `VENCIDA` | Auto |
| Reservar (otra op.) | `RENTADO` | — | `RENTADO` | `RESERVADA` | — |
| Reactivar reservada | `DISPONIBLE` | `RESERVADA` | `APARTADO` | `CONFIRMADA` | — |
| Cancelar confirmada | `APARTADO` | `CONFIRMADA` | `DISPONIBLE` | `CANCELADA` | — |

---

## Diagramas PlantUML

Los diagramas se encuentran en `docs/diagramas/`. Para visualizarlos:

- **GitHub**: Renderizado automático para archivos `.puml`
- **PlantUML Online**: https://www.plantuml.com/plantuml/uml/
- **VS Code**: Extensión "PlantUML" de jebbs

---

## Guías de Inicio Rápido

- 📋 [Proceso de Checkin](guias/guia-checkin.md)
- 📤 [Proceso de Checkout](guias/guia-checkout.md)
- ♻️ [Reactivación de Reservadas](guias/guia-reactivacion.md)
- 🔧 [Troubleshooting](guias/troubleshooting.md)

## Casos de Uso

- 🚗 [Caso 1: Operación Simple](ejemplos/caso-1-operacion-simple.md)
- 📅 [Caso 2: Múltiples Periodos](ejemplos/caso-2-multiples-periodos.md)
- 🔒 [Caso 3: Unidades Reservadas](ejemplos/caso-3-unidades-reservadas.md)
- ⏱️ [Caso 4: Vencimiento y Reactivación](ejemplos/caso-4-vencimiento-reactivacion.md)

## Validaciones y Reglas

- ✅ [Validaciones Críticas del Sistema](docs/07-validaciones-criticas.md)

## Scripts SQL

- 🗄️ [Scripts de Implementación](sql/implementacion.sql)