# Caso 3: Manejo de Unidades Reservadas

## Descripción

Un vehículo está actualmente rentado en una operación. Un segundo ejecutivo quiere incluirlo en una nueva operación que comienza cuando la primera termine. El sistema maneja esto con el estado `RESERVADA`.

## Participantes

- **Ejecutivo 1**: Ana García → Operación CUN-2024-001
- **Ejecutivo 2**: Luis Torres → Operación CUN-2024-050
- **Unidad**: VIN-001 (Sedán 2023)

## Estado Inicial

```
INVENTARIO[VIN-001]:
  estado = RENTADO
  id_operacion_activa = CUN-2024-001

OPERACION_UNIDADES[CUN-001/VIN-001]:
  estado = EN_RENTA
  fecha_checkout_estimado = 15/03/2024
```

---

## Flujo Paso a Paso

### Escenario: Luis quiere VIN-001 para CUN-050 (inicio: 16/03/2024)

### Paso 1: Luis crea CUN-2024-050 e intenta agregar VIN-001

```
Luis busca VIN-001 en el sistema.
Sistema detecta: INV[VIN-001].estado = RENTADO
```

**El sistema ofrece dos opciones:**
1. ❌ No agregar (buscar otro vehículo)
2. ✅ Agregar como RESERVADA (carta de intención)

```
Luis selecciona: Agregar como RESERVADA
```

**Acción del sistema:**
```sql
-- SOLO insertar en OPERACION_UNIDADES, NO modificar INVENTARIO
INSERT INTO operacion_unidades (id_operacion, id_inventario, estado, fecha_agregada)
VALUES ('CUN-2024-050', 'VIN-001', 'RESERVADA', NOW());

-- INVENTARIO permanece sin cambio:
-- INV[VIN-001].estado = RENTADO (sin modificar)
```

**Estado del sistema:**
| Entidad | Operación | Estado | Nota |
|---------|-----------|--------|------|
| INVENTARIO | — | RENTADO | Controlado por CUN-001 |
| OPUN | CUN-001/VIN-001 | EN_RENTA | Operación activa |
| OPUN | CUN-050/VIN-001 | RESERVADA | Carta de intención |

---

### Paso 2: Checkout en CUN-001 (15/03/2024)

```
Ana registra que VIN-001 fue devuelto por el cliente de CUN-001.
```

**Cambios en CUN-001:**
```
INVENTARIO[VIN-001]: RENTADO → DISPONIBLE
  id_operacion_activa = NULL
OPUN[CUN-001/VIN-001]: EN_RENTA → FINALIZADA
  fecha_checkout = 15/03/2024
```

**El sistema detecta automáticamente:**
```sql
-- Job/trigger busca RESERVADAS para VIN-001
SELECT id_operacion FROM operacion_unidades
WHERE id_inventario = 'VIN-001' AND estado = 'RESERVADA';
-- Resultado: CUN-2024-050
```

**Notificación:**
```
⚠️ Sistema notifica a Luis Torres:
"VIN-001 está ahora disponible. CUN-2024-050 tiene una
intención RESERVADA. ¿Desea reactivar la unidad?"
```

---

### Paso 3: Luis reactiva VIN-001 en CUN-050

```
Luis ve la notificación y hace clic en "Reactivar VIN-001 en CUN-050".
```

**Validación del sistema:**
```sql
SELECT * FROM inventario WHERE id = 'VIN-001' AND estado = 'DISPONIBLE';
-- Resultado: ✓ VIN-001 está DISPONIBLE
```

**Acción atómica:**
```sql
BEGIN TRANSACTION;
  UPDATE operacion_unidades
  SET estado = 'CONFIRMADA', fecha_confirmada = NOW()
  WHERE id_inventario = 'VIN-001'
    AND id_operacion = 'CUN-2024-050'
    AND estado = 'RESERVADA';
  
  UPDATE inventario
  SET estado = 'APARTADO',
      id_operacion_activa = 'CUN-2024-050',
      fecha_estado = NOW()
  WHERE id_inventario = 'VIN-001' AND estado = 'DISPONIBLE';
COMMIT;
```

**Estado final:**
| Entidad | Operación | Estado |
|---------|-----------|--------|
| INVENTARIO | — | APARTADO |
| OPUN | CUN-001/VIN-001 | FINALIZADA |
| OPUN | CUN-050/VIN-001 | CONFIRMADA |

---

### Paso 4: Checkin CUN-050 (16/03/2024)

```
Luis completa el checkin normalmente.

INVENTARIO[VIN-001]: APARTADO → RENTADO
OPUN[CUN-050/VIN-001]: CONFIRMADA → EN_RENTA
OPERACIONES[CUN-2024-050]: CONFIRMADA → EN_RENTA
```

---

## Escenario Alternativo: La Reactivación Falla

### Situación: VIN-001 fue tomado por otra operación

```
Después del checkout de CUN-001, otra ejecutiva (María) agrega
VIN-001 a su operación CUN-2024-099 ANTES de que Luis reactive.

INVENTARIO[VIN-001]: DISPONIBLE → EN_PROCESO (CUN-099)
```

**Luis intenta reactivar:**
```sql
SELECT * FROM inventario WHERE id = 'VIN-001' AND estado = 'DISPONIBLE';
-- Resultado: Sin resultados (está EN_PROCESO en CUN-099)
```

**Sistema responde:**
```
❌ Error: VIN-001 ya no está disponible.
Fue tomado por otra operación (CUN-2024-099).
Opciones:
1. Cancelar la intención de VIN-001 en CUN-050
2. Buscar una unidad alternativa
```

---

## Escenario Alternativo: Múltiples Reservas

### Situación: Tres operaciones reservan el mismo vehículo

```
VIN-001 está RENTADO en CUN-001.

CUN-050: VIN-001 → RESERVADA (Luis, 16/03)
CUN-060: VIN-001 → RESERVADA (María, 17/03)
CUN-070: VIN-001 → RESERVADA (Pedro, 18/03)
```

**Cuando VIN-001 queda DISPONIBLE:**
```
Sistema notifica a: Luis (CUN-050), María (CUN-060), Pedro (CUN-070)

El PRIMERO en reactivar obtiene la unidad.
Los otros dos ven el error "ya no disponible" si llegan tarde.
```

> **Recomendación:** Implementar un sistema de prioridad o cola para las reactivaciones cuando hay múltiples reservas.

---

## Resumen del Flujo RESERVADA

```
VIN-001 Timeline:
  ├── RENTADO (CUN-001) ──────────────────────────┤ DISPONIBLE
                           ├── RESERVADA (CUN-050)─┤ CONFIRMADA → RENTADO (CUN-050)

INVENTARIO nunca cambia durante RESERVADA.
Solo cambia cuando se REACTIVA.
```

## Puntos Clave

✅ `RESERVADA` es una carta de intención, no una reserva definitiva  
✅ El INVENTARIO no cambia al crear `RESERVADA`  
✅ La reactivación requiere validar que `INV = DISPONIBLE`  
✅ Múltiples operaciones pueden tener la misma unidad `RESERVADA`  
⚠️ La reactivación es "primero que llega, primero que gana"  
⚠️ Si otro proceso toma la unidad primero, la reactivación falla gracefully  
