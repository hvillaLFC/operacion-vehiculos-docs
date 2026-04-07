# Guía Operacional: Reactivación de Unidades Reservadas

## ¿Qué es una Unidad Reservada?

Una unidad `RESERVADA` es una **carta de intención**: el ejecutivo quiere incluir ese vehículo en una operación futura, pero actualmente está ocupado en otra operación activa. El `INVENTARIO` no cambia cuando se crea el estado `RESERVADA`.

## ¿Cuándo Aparece una Unidad RESERVADA?

Una unidad aparece como `RESERVADA` en los siguientes casos:

1. **Creación manual**: El ejecutivo selecciona una unidad `RENTADO` y la agrega como reserva a su operación.
2. **Cambio de estado en CONFIRMADA**: Una unidad `CONFIRMADA` pasa a `RESERVADA` cuando se asigna a otra operación urgente.

## ¿Cuándo Se Puede Reactivar?

La reactivación solo es posible cuando:

```
CONDICIÓN 1: OPERACION_UNIDADES.estado = 'RESERVADA'
CONDICIÓN 2: INVENTARIO.estado = 'DISPONIBLE'
```

El sistema valida ambas condiciones en tiempo real.

---

## Cuándo Aparece la Notificación de Reactivación

El sistema te notificará automáticamente cuando:

1. El vehículo que tienes `RESERVADA` completa su checkout en la operación activa.
2. La operación activa del vehículo es cancelada.

**Ejemplo de notificación:**
```
🔔 VIN-001 (Sedán 2023) ahora está disponible
La unidad que tenías RESERVADA en CUN-2024-050 ya está libre.
Actúa rápido: otros ejecutivos también pueden verla disponible.
[REACTIVAR AHORA] [Ignorar]
```

> ⚠️ **La reactivación es "primero en llegar, primero en ser atendido"**. Si otro ejecutivo reactiva la unidad antes que tú, ya no estará disponible.

---

## Procedimiento de Reactivación

### Método 1: Desde la Notificación

```
1. Recibir notificación de unidad disponible
2. Clic en [REACTIVAR AHORA]
3. El sistema valida automáticamente
4. Si exitoso: OPUN pasa a CONFIRMADA, INV pasa a APARTADO
```

### Método 2: Desde la Operación

```
1. Sistema → Operaciones → Abrir CUN-XXXX
2. En sección "Unidades", buscar unidades con estado RESERVADA
3. Verificar si el ícono de "Disponible" está activo (verde)
4. Clic en [Reactivar] junto a la unidad
```

### Método 3: Monitoreo Manual

```
1. Sistema → Operaciones → CUN-XXXX → Unidades
2. Para cada unidad RESERVADA, verificar estado actual del INVENTARIO
3. Si INV = DISPONIBLE, el botón [Reactivar] estará activo
4. Si INV ≠ DISPONIBLE, el botón estará desactivado con tooltip del estado actual
```

---

## Proceso del Sistema al Reactivar

Cuando el ejecutivo hace clic en [Reactivar]:

### Paso 1: Validación en Tiempo Real

```sql
-- El sistema verifica en tiempo real:
SELECT id_inventario FROM inventario
WHERE id_inventario = :inv
  AND estado = 'DISPONIBLE';
```

**Si pasa la validación:** → Continúa al Paso 2  
**Si falla:** → Muestra mensaje de error con estado actual

### Paso 2: Transacción Atómica

```sql
BEGIN TRANSACTION;
  -- 1. Cambiar OPUN de RESERVADA a CONFIRMADA
  UPDATE operacion_unidades
  SET estado = 'CONFIRMADA',
      fecha_confirmada = NOW()
  WHERE id_inventario = :inv
    AND id_operacion = :op
    AND estado = 'RESERVADA';
  
  -- 2. Cambiar INVENTARIO a APARTADO
  UPDATE inventario
  SET estado = 'APARTADO',
      id_operacion_activa = :op,
      fecha_estado = NOW()
  WHERE id_inventario = :inv
    AND estado = 'DISPONIBLE';
  -- Si el UPDATE anterior afecta 0 rows: ROLLBACK
COMMIT;
```

### Paso 3: Confirmación al Usuario

```
✅ VIN-001 reactivada exitosamente en CUN-2024-050
Estado: RESERVADA → CONFIRMADA
Ahora puedes proceder con el checkin cuando el cliente llegue.
```

---

## Escenarios Posibles

### ✅ Escenario 1: Reactivación Exitosa

```
Estado antes:  INV[VIN-001] = DISPONIBLE
               OPUN[CUN-050/VIN-001] = RESERVADA

Acción:        Ejecutivo hace clic en [Reactivar]

Estado después: INV[VIN-001] = APARTADO
                OPUN[CUN-050/VIN-001] = CONFIRMADA
```

---

### ❌ Escenario 2: Unidad Tomada por Otro

```
Estado antes:  INV[VIN-001] = EN_PROCESO (otro ejecutivo la tomó)
               OPUN[CUN-050/VIN-001] = RESERVADA

Acción:        Ejecutivo intenta reactivar

Resultado:     ❌ Error: "VIN-001 ya no está disponible.
               Actualmente está EN_PROCESO en otra operación.
               Opciones: 1) Esperar 2) Buscar alternativa 3) Cancelar intención"
```

---

### ⏳ Escenario 3: Unidad Aún Ocupada

```
Estado:        INV[VIN-001] = RENTADO (aún en otra operación)
               OPUN[CUN-050/VIN-001] = RESERVADA

Resultado:     Botón [Reactivar] desactivado con tooltip:
               "VIN-001 aún está RENTADO en CUN-2024-001"
```

---

### 🔀 Escenario 4: Múltiples Reservas para la Misma Unidad

```
VIN-001 está DISPONIBLE.
CUN-050 y CUN-060 ambos tienen VIN-001 en RESERVADA.

Ejecutivo de CUN-050 reactiva primero → ✅ CONFIRMADA para CUN-050
Ejecutivo de CUN-060 intenta reactivar → ❌ Error: Ya no disponible
```

---

## Cancelar una Intención Reservada

Si ya no necesitas la unidad o encontraste una alternativa:

```
Sistema → Operaciones → CUN-XXXX → Unidades
Seleccionar unidad RESERVADA
Clic en [Cancelar Intención]
Confirmar el motivo
```

**Cambio de estado:**
```
OPERACION_UNIDADES: RESERVADA → CANCELADA
INVENTARIO: Sin cambio (no fue afectado)
```

---

## Buenas Prácticas

✅ **Actuar rápido** cuando recibas una notificación de disponibilidad  
✅ **Monitorear** regularmente tus operaciones con unidades RESERVADAS  
✅ **Cancelar intenciones** que ya no sean necesarias para limpiar el sistema  
✅ **Comunicar** con el cliente las fechas estimadas de disponibilidad  
⚠️ **No depender** de que la unidad seguirá disponible; puede ser tomada  
⚠️ **Tener alternativas** preparadas por si la reactivación falla  

---

## Documentación Relacionada

- [Caso 3: Unidades Reservadas](../ejemplos/caso-3-unidades-reservadas.md)
- [Caso 4: Vencimiento y Reactivación](../ejemplos/caso-4-vencimiento-reactivacion.md)
- [Guía de Checkout](guia-checkout.md)
- [Validaciones Críticas](../docs/07-validaciones-criticas.md)
