# Deployables And NPCs

Guia del estado actual para deployables, plantables y base de NPCs autonomos.

## 1) Arquitectura actual

### Servicios y modulos clave
- `src/server/GW/DeployableService.luau`
- `src/server/GW/DeployableRuntimes/LegendaryExploderRuntime.luau`
- `src/server/GW/AutonomousEntityService.luau`
- `src/server/GW/PlantableService.server.luau`
- `src/shared/GW/Shared/TargetingUtil.luau`
- `src/shared/GW/Shared/DamageUtil.luau`
- `src/shared/GW/Shared/EntityRelations.luau`

### Separacion de pipelines
- Summon por ability: `AbilityService` -> `DeployableAbilityRuntime` -> `DeployableService`.
- Placement por spot: `PlantableService` (pipeline dedicado) -> `DeployableService`.

No mezclar validaciones de spot en `AbilityService`.

## 2) Contrato de un deployable

### Config
- Vive en `Config/Deployables/<DeployableId>.luau`.
- Debe pasar `ConfigValidator.validateDeployableConfig`.

### Spawn
`DeployableService.spawn(ownerPlayer, deployableId, requestedSpawnCFrame)`:
- carga config del registry
- normaliza campos canon + alias legacy
- valida modelo humanoid:
  - template existe
  - `Humanoid` presente
  - `HumanoidRootPart` presente
- etiqueta ownership/faccion (`EntityRelations.tagSummonModel`)
- asigna atributos runtime:
  - `DeployableId`
  - `DeployableDisplayName`
  - `DeployableKind`
  - `AnimationProfileId`
  - `SpawnedAt`
  - `Exploded`

### Runtime
- `runPrototype(spawnResult)` despacha por `kind`.
- Hoy: `kind` exploder -> `LegendaryExploderRuntime`.

## 3) Deployable legendario actual (`PlantZombieExploder`)

Config real:
- Archivo: `src/shared/GW/Config/Deployables/PlantZombieExploder.luau`
- `kind = "ExploderLegendary"`
- `animationProfileId = "PlantZombieExploderAnimationProfile"`

Comportamiento:
1. `Deploy` action + sonido deploy.
2. Patrol (si no hay target).
3. Chase target enemigo valido mas cercano.
4. Trigger de arming por proximidad o touch.
5. Espera `ArmDelay`.
6. Main explosion (AOE + knockback + FX/SFX).
7. Chain explosions desacopladas por tiempo/intervalo.
8. Cleanup seguro.

## 4) Targeting y relaciones

### Targeting
- `TargetingUtil.findClosestEnemyHumanoid(...)` para acquisition.
- `TargetingUtil.collectHumanoidsInRadius(...)` para AOE.

### Reglas de dano
- `DamageUtil.canDamage(...)` y `DamageUtil.canTarget(...)` son obligatorios.
- Flags de config:
  - `CanDamageAllies`
  - `CanDamageOwner`

### Ownership/faccion inheritance
- Deployables heredan de owner player via `EntityRelations.tagSummonModel`.
- Atributos clave:
  - `FactionId`
  - `TeamId`
  - `OwnerUserId`
  - `SummonerUserId`

## 5) Kill credit y kill bell

Implementado en `DeployableService`:
- Kill feed global (`FXEvent KillFeed`) con killer owner.
- Kill bell owner-only por `FXEvent SoundCue` (`mode=2D`).

Campos de config:
- `KillBellEnabled`
- `KillBellSoundName` (default `Combat/KillBell`)

## 6) Plantables por spot

### Config
- `Config/Plantables/<PlantableId>.luau`
- Bind en `Config/Characters/<CharacterId>.luau` -> `plantables`.

### Runtime server
`PlantableService` valida:
- cooldown
- maxActive
- spot existente
- spot enabled
- spot type
- faccion de spot
- rango de colocacion
- spot libre

Si pasa:
- llama `DeployableService.spawn`
- marca ocupacion en spot attrs runtime
- libera spot cuando se destruye el modelo

## 7) Base para NPCs autonomos futuros

`AutonomousEntityService` ya da base reusable para:
- scheduler central
- `onStep` por entidad
- `onCleanup`
- control de conexiones y lifecycle

Pendiente para siguiente fase:
- pathfinding/stuck recovery
- behaviors por rol mas separados (chaser/healer/blocker/turret)

## 8) Donde va cada responsabilidad
- Config del deployable: `Config/Deployables/*`
- Config de plantable: `Config/Plantables/*`
- Spawn y efectos comunes: `DeployableService`
- Logica de comportamiento por tipo: `DeployableRuntimes/*`
- Loop autonomo central: `AutonomousEntityService`
- Validacion de spot placement: `PlantableService`
- Reglas de relaciones: `EntityRelations` + `DamageUtil`

## 9) Errores frecuentes
- `animationProfileId` faltante -> spawn bloqueado.
- Modelo sin `Humanoid`/`HumanoidRootPart` -> spawn bloqueado.
- Target aliado tomado por config mala de faccion -> revisar attrs y `DamageUtil`.
- Falta FX/SFX -> warning y degradacion (sin crash).

## 10) Checklist para agregar deployable/NPC nuevo
1. Crear `Config/Deployables/<Id>.luau`.
2. Crear profile en `Config/AnimationProfiles` si es humanoid animado.
3. Agregar assets esperados (modelo + FX + sounds).
4. Implementar runtime por `kind` en `DeployableRuntimes`.
5. Conectar `kind` en `DeployableService.runPrototype`.
6. Usar `TargetingUtil` + `DamageUtil`.
7. Verificar ownership/faccion inheritance.
8. Documentar en `CONFIG_GUIDE`, `FLOWS`, `ASSET_GUIDE`.
