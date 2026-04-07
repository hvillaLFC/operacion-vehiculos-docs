# Caso 1: Operación Simple de Renta

## Descripción

Una empresa contrata el alquiler de 2 vehículos por 7 días. Este es el flujo estándar sin complicaciones.

## Participantes

- **Ejecutivo**: Ana García
- **Cliente**: Empresa XYZ S.A. de C.V.
- **Unidades**: VIN-001 (Sedán), VIN-002 (SUV)
- **Operación**: CUN-2024-001

## Flujo Paso a Paso

### Paso 1: Crear la Cotización

```
Ejecutivo Ana García crea nueva operación:
  - Cliente: Empresa XYZ
  - Fechas: 01/02/2024 al 07/02/2024
  - CUN generado: CUN-2024-001
  - Estado inicial: COTIZACION
```

**Estado del sistema:**
| Entidad | ID | Estado |
|---------|-----|--------|
| OPERACIONES | CUN-2024-001 | COTIZACION |

---

### Paso 2: Agregar VIN-001 a la Cotización

```
Ana busca vehículos disponibles y selecciona VIN-001 (Sedán 2023).
```

**Validación del sistema:**
```
INV[VIN-001].estado == DISPONIBLE ✓
INV[VIN-001].id_operacion_activa == NULL ✓
```

**Cambios de estado:**
```
INVENTARIO[VIN-001]: DISPONIBLE → EN_PROCESO  ⏱️ Timer: 15 min
OPERACION_UNIDADES[CUN-001/VIN-001]: (nueva) → EN_PROCESO
```

**Estado del sistema (T+0 min):**
| Entidad | ID | Estado | Timer |
|---------|-----|--------|-------|
| INVENTARIO | VIN-001 | EN_PROCESO | 15 min |
| OPUN | CUN-001/VIN-001 | EN_PROCESO | 15 min |

---

### Paso 3: Agregar VIN-002 a la Cotización

```
Ana también agrega VIN-002 (SUV 2022).
```

**Cambios de estado:**
```
INVENTARIO[VIN-002]: DISPONIBLE → EN_PROCESO  ⏱️ Timer: 15 min
OPERACION_UNIDADES[CUN-001/VIN-002]: (nueva) → EN_PROCESO
```

---

### Paso 4: Confirmar la Operación (T+8 min)

```
Ana confirma la operación con el cliente antes de los 15 min.
```

**Validación del sistema:**
```
OPUN[VIN-001].estado == EN_PROCESO ✓
OPUN[VIN-001].fecha_vencimiento > NOW() ✓ (7 min restantes)
OPUN[VIN-002].estado == EN_PROCESO ✓
OPUN[VIN-002].fecha_vencimiento > NOW() ✓
```

**Cambios de estado:**
```
INVENTARIO[VIN-001]: EN_PROCESO → APARTADO
OPERACION_UNIDADES[CUN-001/VIN-001]: EN_PROCESO → CONFIRMADA

INVENTARIO[VIN-002]: EN_PROCESO → APARTADO
OPERACION_UNIDADES[CUN-001/VIN-002]: EN_PROCESO → CONFIRMADA

OPERACIONES[CUN-2024-001]: COTIZACION → CONFIRMADA
```

**Estado del sistema (T+8 min):**
| Entidad | ID | Estado |
|---------|-----|--------|
| INVENTARIO | VIN-001 | APARTADO |
| INVENTARIO | VIN-002 | APARTADO |
| OPUN | CUN-001/VIN-001 | CONFIRMADA |
| OPUN | CUN-001/VIN-002 | CONFIRMADA |

---

### Paso 5: Checkin (01/02/2024 09:00)

```
El cliente llega, se firman contratos, se toman fotos.
Ana registra el checkin de ambas unidades.
```

**Cambios de estado:**
```
INVENTARIO[VIN-001]: APARTADO → RENTADO
OPERACION_UNIDADES[CUN-001/VIN-001]: CONFIRMADA → EN_RENTA
OPUN[CUN-001/VIN-001].fecha_checkin = 01/02/2024 09:00

INVENTARIO[VIN-002]: APARTADO → RENTADO
OPERACION_UNIDADES[CUN-001/VIN-002]: CONFIRMADA → EN_RENTA
OPUN[CUN-001/VIN-002].fecha_checkin = 01/02/2024 09:00

OPERACIONES[CUN-2024-001]: CONFIRMADA → EN_RENTA
```

---

### Paso 6: Checkout (07/02/2024 17:00)

```
El cliente devuelve ambos vehículos al finalizar la renta.
Ana registra el checkout.
```

**Cambios de estado:**
```
INVENTARIO[VIN-001]: RENTADO → DISPONIBLE
OPERACION_UNIDADES[CUN-001/VIN-001]: EN_RENTA → FINALIZADA
OPUN[CUN-001/VIN-001].fecha_checkout = 07/02/2024 17:00

INVENTARIO[VIN-002]: RENTADO → DISPONIBLE
OPERACION_UNIDADES[CUN-001/VIN-002]: EN_RENTA → FINALIZADA
OPUN[CUN-001/VIN-002].fecha_checkout = 07/02/2024 17:00

OPERACIONES[CUN-2024-001]: EN_RENTA → FINALIZADA
```

---

## Resumen del Flujo

```
CUN-2024-001:
  Creación     → COTIZACION
  Agregar VINs → Timers activos (EN_PROCESO)
  Confirmación → CONFIRMADA (< 15 min)
  Checkin      → EN_RENTA
  Checkout     → FINALIZADA ✓

VIN-001 y VIN-002:
  DISPONIBLE → EN_PROCESO → APARTADO → RENTADO → DISPONIBLE
  (completan el ciclo completo)
```

## Diagrama de Tiempo

```
Tiempo  VIN-001           VIN-002           CUN-001
T+0     DISPONIBLE        DISPONIBLE        COTIZACION
T+1     EN_PROCESO ⏱️     DISPONIBLE        COTIZACION
T+2     EN_PROCESO ⏱️     EN_PROCESO ⏱️    COTIZACION
T+8     APARTADO          APARTADO          CONFIRMADA
D1 09h  RENTADO           RENTADO           EN_RENTA
D7 17h  DISPONIBLE        DISPONIBLE        FINALIZADA ✓
```

---

## Puntos Clave

✅ Ambas unidades se confirman antes del timeout de 15 min  
✅ El ciclo completo de DISPONIBLE → DISPONIBLE se cumple  
✅ La operación finaliza correctamente  
✅ Las unidades quedan disponibles para nuevas operaciones  
