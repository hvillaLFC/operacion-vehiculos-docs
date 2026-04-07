# Validaciones Críticas del Sistema

## Índice

1. [Reglas Generales](#1-reglas-generales)
2. [Validaciones por Acción](#2-validaciones-por-acción)
3. [Job Scheduler de Vencimiento](#3-job-scheduler-de-vencimiento)
4. [Reglas de Sincronización](#4-reglas-de-sincronización)
5. [Casos Especiales y Excepciones](#5-casos-especiales-y-excepciones)
6. [Errores Comunes y Cómo Evitarlos](#6-errores-comunes-y-cómo-evitarlos)

---

## 1. Reglas Generales

### 1.1 Principio de Sincronización

> **Toda acción sobre `OPERACION_UNIDADES` que cambie el estado debe reflejarse en `INVENTARIO`, EXCEPTO cuando se crea un estado `RESERVADA`.**

```
REGLA: INV.estado SIEMPRE debe ser consistente con OPUN.estado activo
EXCEPCIÓN: OPUN.estado = RESERVADA → INV permanece sin cambio (RENTADO)
```

### 1.2 Unicidad de Operación Activa

Una unidad solo puede estar activamente asignada a **una operación a la vez**:

- `INV.id_operacion_activa` indica la operación que controla el estado actual.
- Múltiples operaciones pueden tener la unidad en estado `RESERVADA`, pero solo una es la **activa**.

### 1.3 Trazabilidad

Todo cambio de estado debe registrarse en `HISTORIAL_ESTADOS`:
- `entidad` (INVENTARIO o OPERACION_UNIDADES)
- `id_entidad`
- `estado_anterior`
- `estado_nuevo`
- `id_usuario` (o sistema para cambios automáticos del Job)
- `motivo`
- `fecha_cambio`

---

## 2. Validaciones por Acción

### 2.1 Agregar Unidad a Cotización

**Precondiciones:**
```sql
-- La unidad debe estar disponible
SELECT * FROM inventario
WHERE id_inventario = :id
  AND estado = 'DISPONIBLE'
  AND id_operacion_activa IS NULL;
-- Si no retorna resultado → ERROR: Unidad no disponible
```

**Acción atómica:**
```sql
BEGIN TRANSACTION;
  INSERT INTO operacion_unidades (id_operacion, id_inventario, estado, fecha_agregada, fecha_vencimiento)
  VALUES (:op, :inv, 'EN_PROCESO', NOW(), DATE_ADD(NOW(), INTERVAL 15 MINUTE));
  
  UPDATE inventario
  SET estado = 'EN_PROCESO',
      id_operacion_activa = :op,
      fecha_estado = NOW()
  WHERE id_inventario = :inv AND estado = 'DISPONIBLE';
COMMIT;
```

**Errores posibles:**
| Código | Descripción |
|--------|-------------|
| `INV-001` | Unidad no existe |
| `INV-002` | Unidad no está en estado DISPONIBLE |
| `INV-003` | Unidad ya tiene operación activa |

---

### 2.2 Confirmar Operación (antes de 15 minutos)

**Precondiciones:**
```sql
-- Verificar que no haya vencido
SELECT id_opun FROM operacion_unidades
WHERE id_operacion = :op
  AND estado = 'EN_PROCESO'
  AND fecha_vencimiento > NOW();
-- Si no retorna → ERROR: Tiempo expirado, re-agregar unidades
```

**Acción atómica:**
```sql
BEGIN TRANSACTION;
  UPDATE operacion_unidades
  SET estado = 'CONFIRMADA',
      fecha_confirmada = NOW()
  WHERE id_operacion = :op AND estado = 'EN_PROCESO';
  
  UPDATE inventario i
  INNER JOIN operacion_unidades ou ON i.id_inventario = ou.id_inventario
  SET i.estado = 'APARTADO', i.fecha_estado = NOW()
  WHERE ou.id_operacion = :op AND ou.estado = 'CONFIRMADA';
  
  UPDATE operaciones SET estado = 'CONFIRMADA' WHERE id_operacion = :op;
COMMIT;
```

**Errores posibles:**
| Código | Descripción |
|--------|-------------|
| `OP-001` | No hay unidades EN_PROCESO en la operación |
| `OP-002` | Tiempo de confirmación expirado (> 15 min) |
| `OP-003` | Operación no existe o ya fue procesada |

---

### 2.3 Checkin

**Precondiciones:**
```sql
-- Unidad confirmada y apartada
SELECT ou.id_opun FROM operacion_unidades ou
INNER JOIN inventario i ON ou.id_inventario = i.id_inventario
WHERE ou.id_operacion = :op
  AND ou.id_inventario = :inv
  AND ou.estado = 'CONFIRMADA'
  AND i.estado = 'APARTADO';
-- Si no retorna → ERROR: Estado inconsistente
```

**Validaciones adicionales:**
- Documentación del cliente completada
- Firma del contrato registrada
- Fotografías del vehículo cargadas (si aplica)

**Acción atómica:**
```sql
BEGIN TRANSACTION;
  UPDATE operacion_unidades
  SET estado = 'EN_RENTA', fecha_checkin = NOW()
  WHERE id_opun = :id_opun AND estado = 'CONFIRMADA';
  
  UPDATE inventario
  SET estado = 'RENTADO', fecha_estado = NOW()
  WHERE id_inventario = :inv AND estado = 'APARTADO';
COMMIT;
```

---

### 2.4 Checkout

**Precondiciones:**
```sql
-- Unidad en renta
SELECT ou.id_opun FROM operacion_unidades ou
INNER JOIN inventario i ON ou.id_inventario = i.id_inventario
WHERE ou.id_operacion = :op
  AND ou.id_inventario = :inv
  AND ou.estado = 'EN_RENTA'
  AND i.estado = 'RENTADO';
```

**Acción atómica + cascada:**
```sql
BEGIN TRANSACTION;
  UPDATE operacion_unidades
  SET estado = 'FINALIZADA', fecha_checkout = NOW()
  WHERE id_opun = :id_opun AND estado = 'EN_RENTA';
  
  UPDATE inventario
  SET estado = 'DISPONIBLE',
      id_operacion_activa = NULL,
      fecha_estado = NOW()
  WHERE id_inventario = :inv AND estado = 'RENTADO';
  
  -- Notificar operaciones con esta unidad RESERVADA
  SELECT id_operacion FROM operacion_unidades
  WHERE id_inventario = :inv AND estado = 'RESERVADA';
COMMIT;
```

**Post-acción:**
- Notificar a ejecutivos de operaciones con la unidad `RESERVADA` que ya está disponible.

---

### 2.5 Crear Estado RESERVADA

**Cuándo aplica:** El ejecutivo quiere incluir una unidad que actualmente está `RENTADO` en otra operación.

**Precondiciones:**
```sql
-- La unidad DEBE estar en estado RENTADO (en otra operación)
SELECT id_inventario FROM inventario
WHERE id_inventario = :inv AND estado = 'RENTADO';
-- Si estado = DISPONIBLE → usar flujo normal (Agregar a Cotización)
-- Si estado = EN_PROCESO → NO se puede agregar
-- Si estado = APARTADO → NO se puede agregar
```

**Acción:**
```sql
-- SOLO insertar en OPERACION_UNIDADES, NO tocar INVENTARIO
INSERT INTO operacion_unidades (id_operacion, id_inventario, estado, fecha_agregada)
VALUES (:op, :inv, 'RESERVADA', NOW());
-- INVENTARIO permanece RENTADO (sin cambio)
```

**⚠️ CRÍTICO:** No ejecutar `UPDATE inventario` en este caso.

---

### 2.6 Reactivar Unidad Reservada

**Precondiciones:**
```sql
-- La unidad debe estar DISPONIBLE en inventario
SELECT id_inventario FROM inventario
WHERE id_inventario = :inv AND estado = 'DISPONIBLE';
-- Si no está DISPONIBLE → ERROR: La unidad aún está ocupada
```

```sql
-- Verificar que la OPUN está en RESERVADA
SELECT id_opun FROM operacion_unidades
WHERE id_inventario = :inv
  AND id_operacion = :op
  AND estado = 'RESERVADA';
```

**Acción atómica:**
```sql
BEGIN TRANSACTION;
  UPDATE operacion_unidades
  SET estado = 'CONFIRMADA', fecha_confirmada = NOW()
  WHERE id_opun = :id_opun AND estado = 'RESERVADA';
  
  UPDATE inventario
  SET estado = 'APARTADO',
      id_operacion_activa = :op,
      fecha_estado = NOW()
  WHERE id_inventario = :inv AND estado = 'DISPONIBLE';
COMMIT;
```

---

### 2.7 Cancelar Operación

**Unidades en CONFIRMADA:**
```sql
BEGIN TRANSACTION;
  UPDATE operacion_unidades
  SET estado = 'CANCELADA'
  WHERE id_operacion = :op AND estado = 'CONFIRMADA';
  
  UPDATE inventario i
  INNER JOIN operacion_unidades ou ON i.id_inventario = ou.id_inventario
  SET i.estado = 'DISPONIBLE',
      i.id_operacion_activa = NULL
  WHERE ou.id_operacion = :op AND ou.estado = 'CANCELADA';
COMMIT;
```

**Unidades en RESERVADA:** Solo se cancela en OPUN, INVENTARIO no cambia (está controlado por otra operación).

---

## 3. Job Scheduler de Vencimiento

### 3.1 Configuración

```
Frecuencia de ejecución: cada 30 segundos (configurable)
Ventana de vencimiento: 15 minutos desde fecha_agregada
Query de detección: fecha_vencimiento < NOW() AND estado = 'EN_PROCESO'
```

### 3.2 Lógica del Job

```sql
-- Paso 1: Obtener unidades vencidas
SELECT ou.id_opun, ou.id_inventario, ou.id_operacion
FROM operacion_unidades ou
WHERE ou.estado = 'EN_PROCESO'
  AND ou.fecha_vencimiento < NOW()
FOR UPDATE; -- Lock para evitar race conditions

-- Paso 2: Por cada registro
BEGIN TRANSACTION;
  UPDATE operacion_unidades
  SET estado = 'VENCIDA'
  WHERE id_opun = :id_opun AND estado = 'EN_PROCESO';
  
  UPDATE inventario
  SET estado = 'DISPONIBLE',
      id_operacion_activa = NULL,
      fecha_estado = NOW()
  WHERE id_inventario = :id_inventario
    AND estado = 'EN_PROCESO';
  
  INSERT INTO historial_estados
  VALUES (NULL, 'OPERACION_UNIDADES', :id_opun, 'EN_PROCESO', 'VENCIDA',
          NULL, 'Job Scheduler - Vencimiento automático', NOW());
COMMIT;
```

### 3.3 Consideraciones de Concurrencia

- Usar `FOR UPDATE` o bloqueo optimista para evitar que dos instancias del Job procesen la misma unidad.
- Si el sistema tiene múltiples nodos, usar un lock distribuido (Redis, por ejemplo).
- Registrar cada ejecución del Job en tabla `job_executions` con timestamp y cantidad de registros procesados.

---

## 4. Reglas de Sincronización

### 4.1 Tabla de Correspondencia de Estados

| Estado INVENTARIO | Estado OPUN Permitidos | Notas |
|-------------------|----------------------|-------|
| `DISPONIBLE` | `VENCIDA`, `CANCELADA`, `FINALIZADA` | Sin operación activa |
| `EN_PROCESO` | `EN_PROCESO` | Timer activo |
| `APARTADO` | `CONFIRMADA` | Esperando checkin |
| `RENTADO` | `EN_RENTA` | Unidad en circulación |
| `RENTADO` | `RESERVADA` en otra op. | Caso especial multi-op. |

### 4.2 Invariantes del Sistema

```
INV 1: Si OPUN.estado = EN_RENTA → INV.estado = RENTADO
INV 2: Si OPUN.estado = CONFIRMADA → INV.estado = APARTADO
INV 3: Si OPUN.estado = EN_PROCESO → INV.estado = EN_PROCESO
INV 4: Si OPUN.estado = RESERVADA → INV.estado = RENTADO (otra operación activa)
INV 5: INV.id_operacion_activa = NULL ↔ INV.estado IN ('DISPONIBLE', 'VENDIDO', 'NO_DISPONIBLE')
```

---

## 5. Casos Especiales y Excepciones

### 5.1 Múltiples Unidades en una Operación

Cuando una operación incluye varias unidades, cada una tiene su propio estado en `OPERACION_UNIDADES`. La confirmación de la operación debe procesar **todas** las unidades en `EN_PROCESO`.

### 5.2 Unidad Vendida/No Disponible durante Operación

Si una unidad pasa a `VENDIDO` o `NO_DISPONIBLE`:
1. Cancelar automáticamente todas sus `OPERACION_UNIDADES` pendientes.
2. Notificar a los ejecutivos de operaciones afectadas.
3. No es posible revertir `VENDIDO` o `NO_DISPONIBLE`.

### 5.3 Operaciones con Periodos (OPERACION_PERIODOS)

Los periodos permiten dividir una renta en tramos. Cada periodo tiene sus propias `OPERACION_PERIODO_UNIDADES` que sincronizan con `INVENTARIO` de la misma manera que `OPERACION_UNIDADES`.

### 5.4 Timeout del Job vs. Confirmación Manual

**Race condition posible:** El ejecutivo confirma justo cuando el Job está procesando el vencimiento.

**Solución:** Usar transacción con `FOR UPDATE` en ambos procesos para que solo uno gane.

---

## 6. Errores Comunes y Cómo Evitarlos

| Error | Causa | Solución |
|-------|-------|----------|
| Estado inconsistente INV/OPUN | Fallo en transacción | Usar transacciones atómicas siempre |
| Unidad bloqueada infinitamente | Job fallido sin rollback | Monitorear Job + alertas si tarda > 5 min |
| Doble procesamiento | Job con múltiples instancias | Lock distribuido o tabla de locks |
| Reactivación sin validar | No verificar INV.estado antes | Siempre validar INV = DISPONIBLE antes de reactivar |
| Cancelación parcial | Solo cancelar OPUN sin INV | Usar transacción que incluya ambas tablas |

---

## Referencias

- [Diagrama de estados INVENTARIO](diagramas/01-estado-inventario.puml)
- [Diagrama de estados OPERACION_UNIDADES](diagramas/02-estado-operacion-unidades.puml)
- [Diagrama de sincronización](diagramas/05-sincronizacion-estados.puml)
- [Scripts SQL](../sql/implementacion.sql)
