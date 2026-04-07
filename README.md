# Vehicle Rental Operational Flow Documentation

## Project Overview
This repository contains comprehensive documentation for the operational flow of vehicle rental services. It includes diagrams, entity definitions, state documentation, synchronization rules, and operational flows.

## Navigation Guide
- **/diagrams**: Contains PlantUML files for various state machines and diagrams relevant to the vehicle rental operation.
- **/docs**: Contains Markdown documentation detailing entities, states, synchronization, operational flows, and edge cases.

## Quick Reference Tables
| Document | Description |
|----------|-------------|
| 01-entidades.md | Detailed entity definitions |
| 02-estados-inventario.md | INVENTARIO states documentation |
| 03-estados-operacion-unidades.md | OPERACION_UNIDADES states documentation |
| 04-sincronizacion.md | Synchronization rules and logic |
| 05-flujos-operacionales.md | Operational flows documentation |
| 06-casos-borde.md | Edge cases and exceptions |

## Diagram Index
1. **inventario-state-machine.puml**: State transitions for INVENTARIO entity.
2. **operacion-unidades-state-machine.puml**: State transitions for OPERACION_UNIDADES entity.
3. **sincronizacion-dependencias.puml**: Dependency and synchronization diagram.
4. **erd-operaciones.puml**: Entity-Relationship Diagram for vehicle rental operations.
5. **flujos-criticos.puml**: Critical operational flows including checkin, checkout, expiration, and reactivation.