# NPC Deployables Plan

Documento de direccion para siguiente fase (sin contradecir runtime actual).

## 1) Base ya implementada
- Relaciones/facciones centralizadas (`EntityRelations`, `DamageUtil`).
- Runtime autonomo central (`AutonomousEntityService`).
- Targeting reusable (`TargetingUtil`).
- Deployables humanoid con animacion profile-driven.
- Plantables por spot en pipeline separado (`PlantableService`).

## 2) Objetivo siguiente fase
Escalar a NPCs de varios roles sin romper arquitectura:
- `Chaser`
- `Healer`
- `Blocker`
- `Trap`
- `Turret`

## 3) Reglas para implementaciones nuevas
1. Toda entidad autonoma se registra en `AutonomousEntityService`.
2. Toda decision de aliado/enemigo usa `DamageUtil`/`EntityRelations`.
3. Toda acquisition usa `TargetingUtil`.
4. Animaciones por `animationProfileId`, no ids hardcodeados.
5. Plantables por spot siguen fuera de `AbilityService`.

## 4) Donde extender
- Config runtime por entidad: `Config/Deployables/*`.
- Config colocacion por spot: `Config/Plantables/*`.
- Runtime de comportamiento: `server/GW/DeployableRuntimes/*`.
- Dispatch de kind: `DeployableService.runPrototype`.

## 5) Pendientes tecnicos
- pathfinding avanzado y recuperacion de atasco.
- politicas de navegacion por mapa/obstaculos.
- optimizacion para alta cantidad de entidades autonomas.
- capa de status effects (`StatusService`) aun stub.

## 6) Checklist para nuevo arquetipo NPC
1. Crear deployable config + profile de animacion.
2. Proveer asset humanoid correcto.
3. Crear runtime con estados claros.
4. Integrar en `runPrototype` por `kind`.
5. Probar dano/targeting/facciones.
6. Documentar contract en docs principales.
