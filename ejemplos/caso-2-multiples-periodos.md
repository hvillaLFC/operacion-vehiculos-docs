# Caso 2: Operación con Múltiples Periodos

## Descripción

Una empresa requiere el alquiler de un vehículo con dos periodos de entrega distintos: primero lo recibe el departamento de ventas, luego el departamento de logística. Esto se maneja con `OPERACION_PERIODOS` y `OPERACION_PERIODO_UNIDADES`.

## Participantes

- **Ejecutivo**: Carlos Mendoza
- **Cliente**: Corporativo ABC
- **Unidad**: VIN-010 (Camioneta)
- **Operación**: CUN-2024-010
- **Periodo 1**: 01/03/2024 – 10/03/2024 (Depto. Ventas)
- **Periodo 2**: 15/03/2024 – 25/03/2024 (Depto. Logística)

## Flujo Paso a Paso

### Paso 1: Crear Operación Principal

```
Carlos crea operación CUN-2024-010 con fecha marco:
  01/03/2024 – 25/03/2024
Estado: COTIZACION
```

---

### Paso 2: Agregar VIN-010 a la Operación

```
Validación: INV[VIN-010].estado = DISPONIBLE ✓
```

**Cambios:**
```
INVENTARIO[VIN-010]: DISPONIBLE → EN_PROCESO  ⏱️ 15 min
OPERACION_UNIDADES[CUN-010/VIN-010]: → EN_PROCESO
```

---

### Paso 3: Confirmar Operación (T+5 min)

```
INVENTARIO[VIN-010]: EN_PROCESO → APARTADO
OPERACION_UNIDADES[CUN-010/VIN-010]: EN_PROCESO → CONFIRMADA
OPERACIONES[CUN-2024-010]: COTIZACION → CONFIRMADA
```

---

### Paso 4: Crear Periodos

```
Carlos define los periodos dentro de CUN-2024-010:

OPERACION_PERIODOS:
  PERIODO-1: 01/03/2024 – 10/03/2024  (estado: ACTIVO)
  PERIODO-2: 15/03/2024 – 25/03/2024  (estado: ACTIVO)
```

**OPERACION_PERIODO_UNIDADES:**
```
PERIODO-1 / VIN-010 → estado: ACTIVO
PERIODO-2 / VIN-010 → estado: ACTIVO
```

---

### Paso 5: Checkin Periodo 1 (01/03/2024)

```
El depto. de Ventas recoge VIN-010.
Carlos registra checkin para PERIODO-1.
```

**Cambios:**
```
INVENTARIO[VIN-010]: APARTADO → RENTADO
OPERACION_UNIDADES[CUN-010/VIN-010]: CONFIRMADA → EN_RENTA
OPERACION_PERIODO_UNIDADES[P1/VIN-010]:
  fecha_checkin = 01/03/2024
OPERACIONES[CUN-2024-010]: CONFIRMADA → EN_RENTA
```

---

### Paso 6: Checkout Periodo 1 (10/03/2024)

```
Depto. de Ventas devuelve VIN-010.
Carlos registra checkout de PERIODO-1.
```

**Cambios:**
```
INVENTARIO[VIN-010]: RENTADO → DISPONIBLE
OPERACION_UNIDADES[CUN-010/VIN-010]: EN_RENTA → CONFIRMADA
  (regresa a CONFIRMADA porque hay PERIODO-2 pendiente)
OPERACION_PERIODO_UNIDADES[P1/VIN-010]:
  estado = COMPLETADO, fecha_checkout = 10/03/2024
```

> **Nota importante:** La unidad regresa a `CONFIRMADA` (no a `FINALIZADA`) porque la operación aún tiene un periodo pendiente. El INVENTARIO vuelve a `DISPONIBLE` temporalmente hasta el checkin del PERIODO-2.

---

### Paso 7: Periodo Intermedio (11/03 – 14/03)

```
VIN-010 está en DISPONIBLE.
Podría ser utilizado en otra operación durante este periodo.

Estado del sistema:
  INVENTARIO[VIN-010]: DISPONIBLE
  OPERACION_UNIDADES[CUN-010/VIN-010]: CONFIRMADA (esperando P2)
```

> **⚠️ Consideración:** Si otra operación toma VIN-010 en este periodo, el sistema debe manejar el conflicto (ver Caso 3).

---

### Paso 8: Checkin Periodo 2 (15/03/2024)

```
Validación: INV[VIN-010].estado = DISPONIBLE ✓

INVENTARIO[VIN-010]: DISPONIBLE → RENTADO
OPERACION_UNIDADES[CUN-010/VIN-010]: CONFIRMADA → EN_RENTA
OPERACION_PERIODO_UNIDADES[P2/VIN-010]:
  fecha_checkin = 15/03/2024
```

---

### Paso 9: Checkout Final Periodo 2 (25/03/2024)

```
Depto. de Logística devuelve VIN-010. Operación completada.

INVENTARIO[VIN-010]: RENTADO → DISPONIBLE
OPERACION_UNIDADES[CUN-010/VIN-010]: EN_RENTA → FINALIZADA
OPERACION_PERIODO_UNIDADES[P2/VIN-010]:
  estado = COMPLETADO, fecha_checkout = 25/03/2024
OPERACIONES[CUN-2024-010]: EN_RENTA → FINALIZADA ✓
```

---

## Resumen del Flujo con Periodos

```
        Mar 01    Mar 10    Mar 15    Mar 25
VIN-010: ├─ RENTADO ─┤ DISP ├── RENTADO ──┤ DISP
OPUN:    ├── EN_RENTA ┤ CONF ├── EN_RENTA ──┤ FINAL
P1:      ├─ ACTIVO ──┤ COMP │
P2:                         ├── ACTIVO ──────┤ COMP
```

## Estructura de Datos Resultante

```sql
-- OPERACIONES
CUN-2024-010 | Corporativo ABC | FINALIZADA

-- OPERACION_UNIDADES
CUN-010/VIN-010 | FINALIZADA | checkin: 01/03 | checkout: 25/03

-- OPERACION_PERIODOS
PERIODO-1 | 01/03 - 10/03 | COMPLETADO
PERIODO-2 | 15/03 - 25/03 | COMPLETADO

-- OPERACION_PERIODO_UNIDADES
P1/VIN-010 | COMPLETADO | checkin: 01/03 | checkout: 10/03
P2/VIN-010 | COMPLETADO | checkin: 15/03 | checkout: 25/03
```

## Puntos Clave

✅ La operación principal agrupa todos los periodos  
✅ Entre periodos, la unidad puede quedar DISPONIBLE temporalmente  
✅ La OPUN regresa a CONFIRMADA (no FINALIZADA) hasta que el último periodo termina  
✅ La sincronización ocurre por periodo, no solo por operación  
⚠️ Cuidado con conflictos si la unidad se renta en el periodo intermedio  
