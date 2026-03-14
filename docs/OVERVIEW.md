# Overview

## 1) Que es este proyecto
`gwproject` es un shooter modular estilo Garden Warfare en Roblox/LuaU.

Objetivo de arquitectura:
- mantener gameplay autoritativo en servidor
- preservar respuesta inmediata en cliente
- escalar con sistemas desacoplados para armas, habilidades, animaciones, deployables y plantables

## 2) Arquitectura general
### Capas
- `Shared` (`ReplicatedStorage.GW.Shared`): tipos, config, registries, utilidades, reglas de relaciones, runtime de animacion reutilizable.
- `Server` (`ServerScriptService`): autoridad de combate/habilidades/deployables/plantables y runtime autonomo.
- `Client` (`StarterPlayerScripts` + `StarterCharacterScripts`): input, UI, FX/SFX locales, animacion del jugador local.

### Principios clave
- Config centralizada en `src/shared/GW/Config`.
- Reglas de aliado/enemigo centralizadas en `EntityRelations`/`DamageUtil`.
- Animaciones centralizadas por profile (character-driven).
- Plantables por spot en pipeline separado de abilities.
- Deployables con runtime modular orientado a reuso.

## 3) Sistemas principales activos
- Combate hitscan autoritativo (`CombatController` + `CombatService`).
- Habilidades (`AbilityController` + `AbilityService`).
- Deployables humanoid (`DeployableService` + `LegendaryExploderRuntime`).
- Plantables por spot (`PlantableController` + `PlantableService`).
- Equipos/facciones (`EntityRelations` + `DamageUtil` + `WorldFactionService`).
- Animaciones character-driven (`AnimationProfiles`, `ClientAnimationService`, `ServerAnimationService`).

## 4) Estado de implementacion real
### Funcional
- Disparo principal con validaciones anti-cheat en servidor.
- Ability BackRocket y ability de deployable (`PlantZombieDeploy`).
- Plantable por spot (`PlantZombieSpotExploder`).
- Deployable legendario explosivo con patrol/chase/arming/main explosion/chain.
- Kill credit + kill feed + kill bell via `FXEvent` (`SoundCue`).

### Parcial / pendiente
- Pathfinding avanzado y stuck recovery para NPCs: pendiente.
- `StatusService.server.luau`: stub.
- `ProjectileService.server.luau`: stub.
- Assets de `GW.Assets` no viven en `src` (deben existir en place/Studio).

## 5) Nuevos cambios recientes y forma correcta de uso
### Cambio 1: Animaciones character-driven
Antes (viejo): animaciones definidas por ability.
Ahora (nuevo): animaciones definidas en `Config/AnimationProfiles` y resueltas por profile.

No hacer:
- poner `AnimationId` dentro de `Config/Abilities`.
- disparar animaciones hardcodeadas en ability runtime.

Hacer:
- asignar `animationProfileId` en `Config/Characters` o `Config/Deployables`.
- mapear `animationActionKey` por slot de ability en character.
- reproducir action keys (`BackRocket`, `Shoot`, `Arm`, etc.).

### Cambio 2: Deployables humanoid estrictos
Antes: podia haber fallback visual simple.
Ahora: `DeployableService.spawn` exige modelo valido con `Humanoid` + `HumanoidRootPart`.

No hacer:
- confiar en fallback de caja para deployables humanoid.

Hacer:
- proveer asset correcto en `ReplicatedStorage/GW/Assets/Deployables/<ModelAssetName>`.

### Cambio 3: Faccion/equipo centralizados
Antes: comparaciones dispersas.
Ahora: todas las reglas pasan por `EntityRelations` y `DamageUtil`.

No hacer:
- comparar `FactionId` manualmente en cada servicio.

Hacer:
- usar `DamageUtil.canDamage/canTarget/canHeal`.

### Cambio 4: Plantables separados de abilities
Antes: tendencia a mezclar placement en ability pipeline.
Ahora: `PlantableService` y `PlantableRequest` son el contrato de spot placement.

No hacer:
- meter validaciones de spot en `AbilityService`.

Hacer:
- mantener plantables en `Config/Plantables` y binds en `Characters.plantables`.

## 6) Donde seguir
- Mapa de carpetas real: `docs/PROJECT_STRUCTURE.md`
- Detalle por sistema y APIs: `docs/SYSTEMS.md`
- Contratos de config: `docs/CONFIG_GUIDE.md`
- Flujos runtime: `docs/FLOWS.md`
- Remotes/eventos: `docs/REMOTES_AND_EVENTS.md`
