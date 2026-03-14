# AGENTS

Guia operativa para agentes/cambios en este repo.

## 1) Proyecto
- Tipo: shooter modular estilo Garden Warfare.
- Stack: Roblox + LuaU + Rojo.
- Arquitectura: separacion estricta `Client / Server / Shared`.
- Sistemas activos:
  - combate hitscan autoritativo
  - habilidades por personaje
  - animaciones character-driven por profile
  - deployables/summons
  - plantables por spot (pipeline separado)
  - runtime autonomo base para entidades/NPCs

## 2) Reglas de trabajo
1. No mover carpetas/archivos sin motivo tecnico claro.
2. No romper separacion `Client / Server / Shared`.
3. No hardcodear valores repetidos en multiples scripts.
4. Centralizar tunables en `src/shared/GW/Config`.
5. Primero causa raiz, luego refactor.
6. Agregar logs antes de adivinar.
7. Evitar require circular entre registries/services.
8. Evitar returns silenciosos en pipelines criticos.
9. Mantener compatibilidad cliente/servidor.
10. No duplicar reglas de equipo/faccion fuera de `EntityRelations`/`DamageUtil`.
11. Plantables por spot NO van en `AbilityService`.
12. Comportamiento autonomo debe pasar por `AutonomousEntityService`.
13. No meter animaciones hardcodeadas en abilities/runtime de gameplay.
14. Resolver animaciones por profile (`AnimationProfiles`) + action keys.

## 3) Fuente de verdad por dominio
- Relaciones/equipos/facciones: `src/shared/GW/Shared/EntityRelations.luau`
- Dano/target/heal: `src/shared/GW/Shared/DamageUtil.luau`
- Target acquisition reusable: `src/shared/GW/Shared/TargetingUtil.luau`
- Spot contract: `src/shared/GW/Shared/PlantSpotUtil.luau`
- Runtime autonomo: `src/server/GW/AutonomousEntityService.luau`
- Spawn/effects deployables: `src/server/GW/DeployableService.luau`
- Pipeline plantables: `src/server/GW/PlantableService.server.luau`
- Profiles animacion: `src/shared/GW/Config/AnimationProfiles/*`
- Runtime animacion cliente: `src/shared/GW/Shared/ClientAnimationService.luau`
- Runtime animacion servidor: `src/server/GW/ServerAnimationService.luau`

## 4) Convenciones
### Naming
- IDs estables: `SoldierRifle`, `BackRocket`, `PlantZombieExploder`, `PlantZombieSpotExploder`.
- Config por ID: `Config/<Domain>/<Id>.luau`.
- Cliente: `*.client.luau`.
- Servidor: `*.server.luau`.

### Config domains
- `Weapons`: combate arma principal
- `Abilities`: gameplay de habilidades (sin AnimationId)
- `Characters`: binds/loadout/profile
- `AnimationProfiles`: locomotion + actions + trigger
- `Deployables`: runtime de entidades invocadas
- `Plantables`: colocacion por spot

### Logging
- Usar `Logger.scoped("<System>")`.
- Loguear decisiones y rechazos antes de return temprano.
- Remover logs temporales cuando termine la depuracion intensa.

## 5) Checklist por tipo de cambio
### Nuevo deployable/NPC invocado
1. Crear `Config/Deployables/<Id>.luau`.
2. Validar contra `ConfigValidator`.
3. Integrar `kind` en `DeployableService.runPrototype`.
4. Reusar `TargetingUtil` + `DamageUtil`.
5. Verificar herencia owner/faccion/team.
6. Documentar en `CONFIG_GUIDE`, `DEPLOYABLES_AND_NPCS`, `FLOWS`.

### Nuevo plantable por spot
1. Crear `Config/Plantables/<Id>.luau`.
2. Bind en `Config/Characters/<Id>.luau` (`plantables`).
3. Validar `spotType`, cooldown, `maxActive`.
4. Probar ocupacion/liberacion del spot.
5. Actualizar docs relevantes.

### Cambio de animaciones
1. Editar profile en `Config/AnimationProfiles/*`.
2. Referenciar profile en character/deployable.
3. Mapear `animationActionKey` en slot de character cuando aplique.
4. No tocar ability config para cambiar AnimationId.
5. Actualizar `ANIMATION_ARCHITECTURE.md` y `CONFIG_GUIDE.md`.

### Cambios de networking
1. Documentar payload y validaciones server-side.
2. Mantener compatibilidad de eventos activos.
3. Loguear razon de rechazo en servidor.

## 6) Zonas sensibles
- `src/server/GW/CombatService.server.luau`
- `src/server/GW/AbilityService.server.luau`
- `src/server/GW/DeployableService.luau`
- `src/server/GW/PlantableService.server.luau`
- `src/shared/GW/Shared/EntityRelations.luau`
- `src/shared/GW/Shared/Logger.luau`

## 7) Deuda tecnica conocida
- Pathfinding avanzado / stuck recovery NPC: pendiente.
- `StatusService` y `ProjectileService`: stubs.
- Assets `ReplicatedStorage.GW.Assets` no versionados en `src`.
