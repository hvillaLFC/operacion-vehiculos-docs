# Guía Operacional: Proceso de Checkout

## ¿Qué es el Checkout?

El checkout es el proceso formal de devolución del vehículo por parte del cliente. Marca el fin de la renta activa y sincroniza los estados: `OPERACION_UNIDADES` (`EN_RENTA → FINALIZADA`) e `INVENTARIO` (`RENTADO → DISPONIBLE`).

> **Importante:** Después del checkout, el sistema busca automáticamente otras operaciones que tengan la unidad en estado `RESERVADA` y notifica a los ejecutivos correspondientes.

## Prerrequisitos

### 1. Estado del Sistema

| Verificación | Estado esperado |
|--------------|-----------------|
| Estado OPUN | `EN_RENTA` |
| Estado INV | `RENTADO` |
| Operación | `EN_RENTA` |

### 2. Documentación Requerida para Devolución

- [ ] Inspección final del vehículo completada
- [ ] Fotografías de devolución (frente, costados, trasera, interior)
- [ ] Kilometraje final registrado
- [ ] Nivel de combustible final
- [ ] Firma del cliente en formulario de devolución
- [ ] Cálculo de cargos adicionales (si aplica)

---

## Procedimiento

### Paso 1: Recibir el Vehículo

```
Realizar inspección física del vehículo:
1. Comparar estado actual vs. inspección inicial
2. Registrar cualquier daño nuevo
3. Verificar nivel de combustible
4. Registrar kilometraje actual
```

### Paso 2: Acceder a la Operación

```
Sistema → Operaciones → Buscar CUN-XXXX → Abrir
Verificar que el estado sea "EN_RENTA"
```

### Paso 3: Iniciar Checkout

```
En la sección "Unidades", seleccionar la unidad a devolver
Clic en botón [INICIAR CHECKOUT]
```

### Paso 4: Registrar Información del Checkout

Complete el formulario:

| Campo | Descripción | Obligatorio |
|-------|-------------|-------------|
| Fecha y hora de devolución | Momento exacto de regreso | ✅ |
| Kilometraje final | Odómetro al devolver | ✅ |
| Nivel de combustible | % o indicador | ✅ |
| Estado del vehículo | Sin daños / Con daños | ✅ |
| Daños nuevos | Descripción si aplica | Condicional |
| Cargos adicionales | Combustible, daños, etc. | Si aplica |
| Nombre del responsable | Quien recibe el vehículo | ✅ |
| Observaciones | Notas adicionales | Opcional |

### Paso 5: Calcular Cargos Adicionales (si aplica)

```
Cargos por combustible: si nivel < nivel inicial
Cargos por kilometraje extra: si km > km del contrato
Cargos por daños: según política de la empresa
Cargos por entrega tardía: si fecha > fecha_fin_contrato
```

### Paso 6: Confirmar y Finalizar

```
El cliente firma el formulario de devolución
Clic en botón [CONFIRMAR CHECKOUT]
```

**Cambios de estado automáticos:**
```
OPERACION_UNIDADES: EN_RENTA → FINALIZADA
  fecha_checkout = NOW()
INVENTARIO: RENTADO → DISPONIBLE
  id_operacion_activa = NULL

Sistema busca OPUN con estado RESERVADA para esta unidad:
  Si encuentra → Notifica ejecutivos correspondientes
```

---

## Proceso Post-Checkout: Notificación de Reservadas

Después de completar el checkout, el sistema ejecuta automáticamente:

```sql
SELECT ou.id_operacion, u.nombre AS ejecutivo, u.correo
FROM operacion_unidades ou
INNER JOIN operaciones o ON ou.id_operacion = o.id_operacion
INNER JOIN usuarios u ON o.id_ejecutivo = u.id_usuario
WHERE ou.id_inventario = :inv_liberado
  AND ou.estado = 'RESERVADA'
ORDER BY ou.fecha_agregada ASC;
```

**Notificación enviada a ejecutivos:**
```
🔔 NOTIFICACIÓN: VIN-001 ahora está disponible
La unidad [VIN-001 - Sedán 2023] que tenías RESERVADA en 
[CUN-2024-050] ya está libre.
Ingresa al sistema para reactivarla antes de que alguien más la tome.
[BOTÓN: Reactivar ahora]
```

---

## Validaciones Automáticas

| Validación | Acción si falla |
|------------|-----------------|
| OPUN ≠ EN_RENTA | Bloquear checkout, mostrar estado actual |
| INV ≠ RENTADO | Alerta de inconsistencia, escalar a admin |
| Firma del cliente | Requerir antes de confirmar |

---

## Errores Comunes

### Error: "La unidad no está en estado EN_RENTA"

**Causa:** El estado puede haber sido modificado manualmente o hay una inconsistencia.  
**Solución:** Verificar historial de estados y escalar a administrador si es necesario.

### Error: "No se puede completar checkout: estado inconsistente"

**Causa:** `OPUN = EN_RENTA` pero `INV ≠ RENTADO` (o viceversa).  
**Solución:** Ejecutar script de corrección de estados (ver [Troubleshooting](troubleshooting.md)).

---

## Resumen Visual

```
ANTES DEL CHECKOUT:           DESPUÉS DEL CHECKOUT:
  OPUN = EN_RENTA        →      OPUN = FINALIZADA
  INV  = RENTADO         →      INV  = DISPONIBLE
                                 ↓
                         Sistema notifica a ejecutivos
                         con esta unidad RESERVADA
```

## Casos Especiales

### Checkout Parcial (Operación con Múltiples Unidades)

Si la operación tiene múltiples unidades, se pueden hacer checkouts independientes por unidad. La operación completa solo pasa a `FINALIZADA` cuando **todas** las unidades han hecho checkout.

### Checkout en Múltiples Periodos

Si la operación tiene periodos, el checkout de un periodo no finaliza la operación completa. Ver [Caso 2: Múltiples Periodos](../ejemplos/caso-2-multiples-periodos.md).

---

## Documentación Relacionada

- [Guía de Checkin](guia-checkin.md)
- [Guía de Reactivación](guia-reactivacion.md)
- [Caso 3: Unidades Reservadas](../ejemplos/caso-3-unidades-reservadas.md)
- [Validaciones Críticas](../docs/07-validaciones-criticas.md)
