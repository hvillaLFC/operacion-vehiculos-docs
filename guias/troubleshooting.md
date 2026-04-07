# Troubleshooting - Solución de Problemas Comunes

## Índice

1. [Problemas de Estado](#1-problemas-de-estado)
2. [Problemas con el Timer de 15 Minutos](#2-problemas-con-el-timer-de-15-minutos)
3. [Problemas con el Job Scheduler](#3-problemas-con-el-job-scheduler)
4. [Problemas con Unidades Reservadas](#4-problemas-con-unidades-reservadas)
5. [Inconsistencias INVENTARIO / OPUN](#5-inconsistencias-inventario--opun)
6. [Consultas de Diagnóstico](#6-consultas-de-diagnóstico)
7. [Contacto y Escalamiento](#7-contacto-y-escalamiento)

---

## 1. Problemas de Estado

### P: No puedo confirmar la operación — "Tiempo expirado"

**Síntoma:** Al intentar confirmar, el sistema dice que las unidades han vencido.

**Causa:** Han pasado más de 15 minutos desde que se agregaron las unidades.

**Solución:**
1. Ver qué unidades están en estado `VENCIDA` en la operación.
2. Re-agregar cada unidad (si siguen disponibles).
3. Confirmar dentro del nuevo período de 15 minutos.
4. Si la unidad ya no está disponible, seleccionar alternativa.

```sql
-- Consultar unidades vencidas en una operación
SELECT id_inventario, estado, fecha_agregada, fecha_vencimiento
FROM operacion_unidades
WHERE id_operacion = 'CUN-XXXX'
  AND estado = 'VENCIDA';
```

---

### P: El botón de Checkin está desactivado

**Síntoma:** La unidad aparece como `CONFIRMADA` pero no puedo hacer checkin.

**Causas posibles:**

| Causa | Diagnóstico | Solución |
|-------|-------------|----------|
| Documentación incompleta | Revisar lista de documentos | Completar documentación |
| Fecha de inicio no llegada | Verificar fecha del contrato | Esperar la fecha o adelantar |
| Permisos insuficientes | Verificar rol del usuario | Solicitar permiso a admin |

---

### P: No puedo hacer checkout — "Estado incorrecto"

**Síntoma:** La unidad dice `EN_RENTA` pero el sistema rechaza el checkout.

**Diagnóstico:**
```sql
-- Verificar estados de OPUN e INV
SELECT 
  ou.id_opun,
  ou.estado AS opun_estado,
  i.estado AS inv_estado,
  i.id_operacion_activa
FROM operacion_unidades ou
INNER JOIN inventario i ON ou.id_inventario = i.id_inventario
WHERE ou.id_operacion = 'CUN-XXXX'
  AND ou.id_inventario = 'VIN-XXX';
```

**Si OPUN = EN_RENTA pero INV ≠ RENTADO:** Ver sección [Inconsistencias](#5-inconsistencias-inventario--opun).

---

### P: La unidad aparece como "No disponible" pero no está en ninguna operación

**Síntoma:** `INV.estado = EN_PROCESO` pero no hay `OPUN` en `EN_PROCESO`.

**Causa:** Fallo en transacción anterior; el inventario quedó bloqueado.

**Diagnóstico:**
```sql
-- Verificar si hay OPUN activa para esta unidad
SELECT * FROM operacion_unidades
WHERE id_inventario = 'VIN-XXX'
  AND estado NOT IN ('FINALIZADA', 'CANCELADA', 'VENCIDA');
```

**Solución:**
1. Si no hay OPUN activa → Ejecutar corrección manual (ver Sección 5).
2. Si hay OPUN activa → La unidad está correctamente asignada.

---

## 2. Problemas con el Timer de 15 Minutos

### P: La unidad venció antes de los 15 minutos

**Causa posible:** El Job Scheduler tiene configuración incorrecta o problema de zona horaria.

**Verificación:**
```sql
-- Verificar timestamps
SELECT 
  id_opun,
  fecha_agregada,
  fecha_vencimiento,
  TIMESTAMPDIFF(MINUTE, fecha_agregada, fecha_vencimiento) AS minutos_configurados,
  NOW() AS ahora
FROM operacion_unidades
WHERE id_opun = :id_opun;
```

**Solución:** Verificar la zona horaria del servidor vs. la base de datos:
```sql
SELECT @@global.time_zone, @@session.time_zone, NOW(), UTC_TIMESTAMP();
```

---

### P: La unidad lleva más de 15 min en EN_PROCESO y no ha vencido

**Causa:** El Job Scheduler no está ejecutándose o está fallando silenciosamente.

**Verificación:**
```sql
-- Ver últimas ejecuciones del Job
SELECT * FROM job_executions
WHERE job_nombre = 'VENCIMIENTO_OPUN'
ORDER BY fecha_inicio DESC
LIMIT 10;
```

**Solución:**
1. Verificar que el Job Scheduler esté activo en el servidor.
2. Revisar logs del servidor para errores del Job.
3. Ejecutar el Job manualmente si es urgente.

---

## 3. Problemas con el Job Scheduler

### P: El Job no se ejecuta

**Síntomas:** Unidades vencidas no se actualizan automáticamente.

**Checklist:**
- [ ] ¿El servicio del Job Scheduler está activo?
- [ ] ¿Hay suficiente memoria/CPU en el servidor?
- [ ] ¿El usuario de BD del Job tiene permisos de escritura?
- [ ] ¿Hay errores en los logs del Job?

**Comandos de diagnóstico (Linux):**
```bash
# Verificar servicio
systemctl status vehicle-job-scheduler

# Ver logs recientes
journalctl -u vehicle-job-scheduler -n 100 --no-pager

# Verificar conectividad a BD desde el servicio
```

---

### P: El Job procesa la misma unidad dos veces

**Causa:** Múltiples instancias del Job corriendo en paralelo sin lock.

**Síntoma:** La misma unidad tiene dos registros en `HISTORIAL_ESTADOS` con vencimiento al mismo timestamp.

**Solución:**
1. Implementar lock distribuido (Redis o tabla de locks en BD).
2. Asegurar que solo una instancia del Job corra a la vez.

```sql
-- Verificar duplicados en historial
SELECT id_entidad, fecha_cambio, COUNT(*)
FROM historial_estados
WHERE entidad = 'OPERACION_UNIDADES'
  AND estado_nuevo = 'VENCIDA'
GROUP BY id_entidad, DATE(fecha_cambio)
HAVING COUNT(*) > 1;
```

---

## 4. Problemas con Unidades Reservadas

### P: La notificación de reactivación no llegó

**Causas posibles:**
- El servicio de notificaciones está caído.
- El correo electrónico del ejecutivo no está registrado.
- La notificación fue a spam.

**Diagnóstico manual:**
```sql
-- Ver unidades RESERVADAS que deberían haber sido notificadas
SELECT 
  ou.id_inventario,
  ou.id_operacion,
  ou.estado,
  i.estado AS inv_estado
FROM operacion_unidades ou
INNER JOIN inventario i ON ou.id_inventario = i.id_inventario
WHERE ou.estado = 'RESERVADA'
  AND i.estado = 'DISPONIBLE';
```

**Si hay registros:** La unidad está lista para reactivar. Ir directamente a la operación y reactivar manualmente.

---

### P: El botón de Reactivar no aparece

**Causa:** El INVENTARIO no está en estado `DISPONIBLE`.

**Solución:**
```sql
-- Ver el estado actual del inventario
SELECT id_inventario, estado, id_operacion_activa
FROM inventario
WHERE id_inventario = 'VIN-XXX';
```

Esperar a que la operación activa libere la unidad o contactar al ejecutivo de esa operación.

---

### P: Reactivé la unidad pero ahora aparece como CONFIRMADA sin poder hacer checkin

**Causa normal:** Esto es correcto. Después de reactivar, debes esperar la fecha de inicio y hacer el checkin normalmente.

**Si hay un problema real:** Verificar que `INV.estado = APARTADO` después de la reactivación.

---

## 5. Inconsistencias INVENTARIO / OPUN

> ⚠️ **Estas correcciones solo deben realizarlas administradores del sistema.**

### Diagnóstico General de Inconsistencias

```sql
-- Detectar inconsistencias entre INV y OPUN
SELECT 
  i.id_inventario,
  i.estado AS inv_estado,
  ou.estado AS opun_estado,
  ou.id_operacion,
  'INCONSISTENTE' AS diagnostico
FROM inventario i
LEFT JOIN operacion_unidades ou 
  ON i.id_inventario = ou.id_inventario
  AND ou.estado IN ('EN_PROCESO', 'CONFIRMADA', 'EN_RENTA')
WHERE 
  -- INV dice EN_PROCESO pero no hay OPUN en EN_PROCESO
  (i.estado = 'EN_PROCESO' AND ou.id_opun IS NULL)
  OR
  -- INV dice APARTADO pero no hay OPUN CONFIRMADA
  (i.estado = 'APARTADO' AND ou.estado != 'CONFIRMADA')
  OR
  -- INV dice RENTADO pero no hay OPUN EN_RENTA
  (i.estado = 'RENTADO' AND ou.estado != 'EN_RENTA' AND ou.estado != 'RESERVADA');
```

### Corrección: INV bloqueado sin OPUN activa

```sql
-- SOLO ejecutar si el diagnóstico confirma que no hay OPUN activa
BEGIN TRANSACTION;
  UPDATE inventario
  SET estado = 'DISPONIBLE',
      id_operacion_activa = NULL,
      fecha_estado = NOW()
  WHERE id_inventario = 'VIN-XXX'
    AND estado IN ('EN_PROCESO', 'APARTADO');
  
  INSERT INTO historial_estados (entidad, id_entidad, estado_anterior, estado_nuevo, 
                                  id_usuario, motivo, fecha_cambio)
  VALUES ('INVENTARIO', 'VIN-XXX', 'EN_PROCESO', 'DISPONIBLE',
          NULL, 'Corrección manual de inconsistencia por admin', NOW());
COMMIT;
```

---

## 6. Consultas de Diagnóstico

### Vista General del Sistema

```sql
-- Dashboard: resumen de estados del inventario
SELECT estado, COUNT(*) AS cantidad
FROM inventario
GROUP BY estado
ORDER BY FIELD(estado, 'DISPONIBLE', 'EN_PROCESO', 'APARTADO', 
                          'RENTADO', 'VENDIDO', 'NO_DISPONIBLE');
```

### Operaciones en Riesgo (unidades a punto de vencer)

```sql
-- Unidades que vencen en los próximos 5 minutos
SELECT 
  ou.id_operacion,
  ou.id_inventario,
  ou.fecha_vencimiento,
  TIMESTAMPDIFF(SECOND, NOW(), ou.fecha_vencimiento) AS segundos_restantes
FROM operacion_unidades ou
WHERE ou.estado = 'EN_PROCESO'
  AND ou.fecha_vencimiento BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 5 MINUTE)
ORDER BY ou.fecha_vencimiento ASC;
```

### Operaciones con Unidades RESERVADAS Disponibles

```sql
-- Unidades RESERVADAS que ya están listas para reactivar
SELECT 
  ou.id_operacion,
  ou.id_inventario,
  i.estado AS inv_estado,
  ou.fecha_agregada
FROM operacion_unidades ou
INNER JOIN inventario i ON ou.id_inventario = i.id_inventario
WHERE ou.estado = 'RESERVADA'
  AND i.estado = 'DISPONIBLE';
```

---

## 7. Contacto y Escalamiento

| Nivel | Cuándo escalar | Contacto |
|-------|----------------|----------|
| Soporte L1 | Problemas de UI, permisos, dudas operativas | Mesa de ayuda |
| Soporte L2 | Errores de sistema, comportamientos inesperados | Equipo técnico |
| DBA / Admin | Inconsistencias de base de datos, correcciones manuales | DBA de guardia |
| Desarrollo | Bugs confirmados, mejoras urgentes | Equipo de desarrollo |

### Información a Proporcionar al Escalar

1. **CUN** de la operación afectada
2. **VIN** de la unidad con problemas
3. **Captura de pantalla** del error o estado incorrecto
4. **Hora exacta** cuando ocurrió el problema
5. **Acciones realizadas** antes del problema
6. **Resultado esperado** vs. resultado obtenido

---

## Documentación Relacionada

- [Validaciones Críticas](../docs/07-validaciones-criticas.md)
- [Scripts SQL](../sql/implementacion.sql)
- [Diagramas de Estado](../docs/diagramas/)
