# Caso 4: Vencimiento Automático y Reactivación

## Descripción

Un ejecutivo agrega unidades a una cotización pero no la confirma en 15 minutos. El Job Scheduler detecta el vencimiento y libera las unidades. Luego el ejecutivo debe re-agregar y confirmar manualmente.

## Participantes

- **Ejecutivo**: Roberto Salinas
- **Unidades**: VIN-003, VIN-004, VIN-005
- **Operación**: CUN-2024-025
- **Job Scheduler**: Proceso automático (cada 30 seg)

---

## Flujo Paso a Paso

### Paso 1: Crear Cotización y Agregar Unidades (T=10:00:00)

```
Roberto crea CUN-2024-025 y agrega 3 unidades:
  VIN-003: agregada a las 10:00:00 (vence: 10:15:00)
  VIN-004: agregada a las 10:02:00 (vence: 10:17:00)
  VIN-005: agregada a las 10:03:00 (vence: 10:18:00)
```

**Estado del sistema:**
| Unidad | INVENTARIO | OPUN | Vence en |
|--------|-----------|------|----------|
| VIN-003 | EN_PROCESO | EN_PROCESO | 10:15:00 |
| VIN-004 | EN_PROCESO | EN_PROCESO | 10:17:00 |
| VIN-005 | EN_PROCESO | EN_PROCESO | 10:18:00 |

---

### Paso 2: Roberto se Distrae (T=10:00 – 10:20)

```
Roberto recibe una llamada importante y olvida confirmar la operación.
El timer sigue corriendo...
```

---

### Paso 3: Job Scheduler Detecta Vencimiento (T=10:15:30)

```
Job ejecuta query:
SELECT * FROM operacion_unidades
WHERE estado = 'EN_PROCESO'
AND fecha_vencimiento < NOW()
```

**Resultado:** VIN-003 ha vencido (fecha_vencimiento = 10:15:00 < 10:15:30)

**Acción automática para VIN-003:**
```
INVENTARIO[VIN-003]: EN_PROCESO → DISPONIBLE
OPUN[CUN-025/VIN-003]: EN_PROCESO → VENCIDA
```

**Notificación al ejecutivo:**
```
⚠️ Roberto: VIN-003 ha sido liberada por timeout.
La unidad VIN-003 en CUN-2024-025 ha vencido.
```

---

### Paso 4: Job Continúa (T=10:17:30 y T=10:18:30)

```
Job T=10:17:30: Detecta VIN-004 vencida
  INVENTARIO[VIN-004]: EN_PROCESO → DISPONIBLE
  OPUN[CUN-025/VIN-004]: EN_PROCESO → VENCIDA

Job T=10:18:30: Detecta VIN-005 vencida
  INVENTARIO[VIN-005]: EN_PROCESO → DISPONIBLE
  OPUN[CUN-025/VIN-005]: EN_PROCESO → VENCIDA
```

**Estado del sistema (T=10:19):**
| Unidad | INVENTARIO | OPUN | Nota |
|--------|-----------|------|------|
| VIN-003 | DISPONIBLE | VENCIDA | Liberada por Job |
| VIN-004 | DISPONIBLE | VENCIDA | Liberada por Job |
| VIN-005 | DISPONIBLE | VENCIDA | Liberada por Job |

---

### Paso 5: Roberto Regresa (T=10:20)

```
Roberto ve las notificaciones y las 3 unidades aparecen como VENCIDA.
```

**Opciones del sistema:**
1. Re-agregar las mismas unidades (si siguen disponibles)
2. Buscar unidades alternativas
3. Cancelar la operación

**Roberto decide re-agregar:**

---

### Paso 6: Intento de Re-Agregar VIN-003 (T=10:21)

```
Roberto hace clic en "Re-agregar VIN-003" en CUN-025.
```

**Validación:**
```sql
SELECT * FROM inventario WHERE id = 'VIN-003' AND estado = 'DISPONIBLE';
-- ✓ VIN-003 está DISPONIBLE (nadie la tomó en el ínterin)
```

**Acción:**
```
INVENTARIO[VIN-003]: DISPONIBLE → EN_PROCESO  ⏱️ Nuevo timer: 15 min
OPUN[CUN-025/VIN-003]: VENCIDA → EN_PROCESO (nuevo registro o update)
fecha_vencimiento = 10:36:00
```

---

### Paso 7: VIN-004 ya No Está Disponible (T=10:21)

```
Roberto intenta re-agregar VIN-004.
```

**Validación:**
```sql
SELECT * FROM inventario WHERE id = 'VIN-004' AND estado = 'DISPONIBLE';
-- ❌ Sin resultados: VIN-004 está EN_PROCESO en CUN-2024-099
-- (Otra ejecutiva la tomó entre T=10:17 y T=10:21)
```

**Sistema responde:**
```
❌ VIN-004 ya no está disponible.
Fue tomada por otra operación.
Por favor seleccione una unidad alternativa.
```

**Roberto selecciona VIN-007 como alternativa:**
```
INVENTARIO[VIN-007]: DISPONIBLE → EN_PROCESO  ⏱️ Nuevo timer: 15 min
OPUN[CUN-025/VIN-007]: (nueva) → EN_PROCESO
```

---

### Paso 8: Re-Agregar VIN-005 (T=10:22)

```
INVENTARIO[VIN-005]: DISPONIBLE → EN_PROCESO  ⏱️ Nuevo timer: 15 min
OPUN[CUN-025/VIN-005]: VENCIDA → EN_PROCESO
```

---

### Paso 9: Roberto Confirma Esta Vez (T=10:25)

```
Roberto confirma la operación con las 3 unidades disponibles.
(4 minutos después de re-agregarlas, dentro del nuevo timer de 15 min)
```

**Cambios:**
```
INVENTARIO[VIN-003]: EN_PROCESO → APARTADO
OPUN[CUN-025/VIN-003]: EN_PROCESO → CONFIRMADA

INVENTARIO[VIN-007]: EN_PROCESO → APARTADO
OPUN[CUN-025/VIN-007]: EN_PROCESO → CONFIRMADA

INVENTARIO[VIN-005]: EN_PROCESO → APARTADO
OPUN[CUN-025/VIN-005]: EN_PROCESO → CONFIRMADA

OPERACIONES[CUN-2024-025]: COTIZACION → CONFIRMADA ✓
```

---

## Resumen del Flujo de Vencimiento

```
T=10:00  VIN-003, VIN-004, VIN-005 → EN_PROCESO ⏱️
T=10:15  Job vence VIN-003          → DISPONIBLE/VENCIDA
T=10:17  Job vence VIN-004          → DISPONIBLE/VENCIDA
T=10:18  Job vence VIN-005          → DISPONIBLE/VENCIDA
T=10:20  Roberto regresa
T=10:21  VIN-003 re-agregada ✓      → EN_PROCESO (nuevo timer)
T=10:21  VIN-004 tomada por otro ❌  → Roberto usa VIN-007
T=10:22  VIN-005 re-agregada ✓      → EN_PROCESO
T=10:25  Operación confirmada ✓
```

## Registro del Job Scheduler

| Timestamp | Acción | Unidades Procesadas |
|-----------|--------|---------------------|
| 10:15:30 | Vencimiento | VIN-003 |
| 10:17:30 | Vencimiento | VIN-004 |
| 10:18:30 | Vencimiento | VIN-005 |

---

## Puntos Clave

✅ El Job libera unidades automáticamente después de 15 min  
✅ El estado `VENCIDA` es informativo, no bloquea re-intentos  
✅ Las unidades liberadas pueden ser tomadas por otros  
✅ Re-agregar reinicia el timer de 15 minutos  
⚠️ No hay garantía de que la unidad siga disponible al re-intentar  
⚠️ El ejecutivo debe actuar rápido para no perder unidades valiosas  

## Configuración Recomendada del Job

```properties
# Job Scheduler - Configuración
job.vencimiento.intervalo=30s          # Ejecutar cada 30 segundos
job.vencimiento.timeout=15m            # Ventana de vencimiento
job.vencimiento.batch_size=100         # Máximo de registros por lote
job.vencimiento.lock_timeout=5s        # Tiempo máximo de bloqueo
job.vencimiento.notificar_ejecutivo=true  # Enviar notificación
```
