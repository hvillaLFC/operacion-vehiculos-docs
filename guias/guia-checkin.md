# Guía Operacional: Proceso de Checkin

## ¿Qué es el Checkin?

El checkin es el proceso formal de entrega del vehículo al cliente. Marca el inicio oficial de la renta y sincroniza los estados de `OPERACION_UNIDADES` (`CONFIRMADA → EN_RENTA`) e `INVENTARIO` (`APARTADO → RENTADO`).

## Prerrequisitos

Antes de iniciar el checkin, verifica que se cumplan **todas** estas condiciones:

### 1. Estado del Sistema

| Verificación | Cómo validar | Estado esperado |
|--------------|--------------|-----------------|
| Estado OPUN | Sistema → CUN → Unidades | `CONFIRMADA` |
| Estado INV | Sistema → Inventario → Unidad | `APARTADO` |
| Operación activa | Estado de la operación | `CONFIRMADA` |

### 2. Documentación Requerida

- [ ] Contrato de renta firmado por el cliente
- [ ] Copia de identificación oficial del conductor
- [ ] Copia de licencia de conducir vigente
- [ ] Depósito o autorización de tarjeta de crédito
- [ ] Comprobante de seguro vigente (si aplica)
- [ ] Formulario de inspección inicial del vehículo

### 3. Inspección del Vehículo

- [ ] Fotografías del vehículo (frente, costados, trasera, interior)
- [ ] Nivel de gasolina documentado
- [ ] Kilometraje inicial registrado
- [ ] Accesorios del vehículo inventariados (gato, llanta de refacción, etc.)
- [ ] Daños preexistentes documentados y firmados por el cliente

---

## Procedimiento

### Paso 1: Acceder a la Operación

```
Sistema → Operaciones → Buscar CUN-XXXX → Abrir
Verificar que el estado sea "CONFIRMADA"
```

### Paso 2: Iniciar Checkin

```
En la sección "Unidades", seleccionar la unidad a entregar
Clic en botón [INICIAR CHECKIN]
```

**El sistema valida automáticamente:**
```
✓ OPUN.estado = CONFIRMADA
✓ INV.estado = APARTADO
✓ Documentación completa (si hay validación automática)
```

### Paso 3: Registrar Información del Checkin

Complete el formulario:
- **Fecha y hora de entrega**: Registrar exactamente
- **Kilometraje inicial**: Obligatorio
- **Nivel de combustible**: Indicar porcentaje o indicador
- **Nombre del receptor**: Quién firma de recibido
- **Observaciones**: Cualquier nota relevante

### Paso 4: Confirmar y Firmar

```
El cliente firma el contrato de entrega (digital o físico)
Clic en botón [CONFIRMAR CHECKIN]
```

**Cambios de estado automáticos:**
```
OPERACION_UNIDADES: CONFIRMADA → EN_RENTA
INVENTARIO: APARTADO → RENTADO
OPERACIONES: (actualiza fecha_inicio_real)
```

### Paso 5: Entregar Documentos al Cliente

- [ ] Copia del contrato de renta
- [ ] Formulario de inspección firmado
- [ ] Tarjeta de emergencias/contacto

---

## Validaciones Automáticas del Sistema

| Validación | Acción si falla |
|------------|-----------------|
| OPUN ≠ CONFIRMADA | Bloquear checkin, mostrar estado actual |
| INV ≠ APARTADO | Alerta de inconsistencia, escalar a admin |
| Documentación incompleta | Advertencia (puede ser configurable) |

---

## Errores Comunes

### Error: "La unidad no está en estado CONFIRMADA"

**Causa:** La operación puede haber vencido o cancelado.  
**Solución:** Verificar el estado actual de la OPUN y re-confirmar si es necesario.

### Error: "Estado inconsistente entre INVENTARIO y OPERACION_UNIDADES"

**Causa:** Posible fallo en una transacción anterior.  
**Solución:** Escalar al administrador del sistema para corrección manual.

### Error: "No se puede realizar checkin: faltan documentos"

**Causa:** El formulario no está completo.  
**Solución:** Completar toda la documentación requerida antes de intentar nuevamente.

---

## Notas Importantes

> ⚠️ **No realizar checkin sin la documentación completa.** El cliente debe firmar antes de recibir el vehículo.

> ✅ **El checkin es irreversible** salvo autorización del supervisor. Una vez en `EN_RENTA`, solo el checkout puede cambiar el estado.

> 📋 **Registrar con precisión** el kilometraje y estado del vehículo. Esta información es crítica para el checkout.

---

## Referencia de Estados

```
Antes del Checkin:       Después del Checkin:
OPUN = CONFIRMADA   →   OPUN = EN_RENTA
INV  = APARTADO     →   INV  = RENTADO
```

## Documentación Relacionada

- [Guía de Checkout](guia-checkout.md)
- [Caso 1: Operación Simple](../ejemplos/caso-1-operacion-simple.md)
- [Validaciones Críticas](../docs/07-validaciones-criticas.md)
