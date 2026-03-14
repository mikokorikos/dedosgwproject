# Deployable Legendary Implementation

Guia especifica del deployable `PlantZombieExploder` en la arquitectura actual.

## 1) Config real
Archivo:
- `src/shared/GW/Config/Deployables/PlantZombieExploder.luau`

Puntos clave:
- `kind = "ExploderLegendary"`
- `animationProfileId = "PlantZombieExploderAnimationProfile"`
- `ModelAssetName = "PlantZombieExploderModel"`
- Main explosion + chain explosion configurables.

## 2) Contrato de assets esperados

### Modelo
- `ReplicatedStorage/GW/Assets/Deployables/PlantZombieExploderModel`
- Tipo: `Model`
- Requerido: `Humanoid` y `HumanoidRootPart`

No hay fallback de caja para deployables humanoid. Si el modelo no cumple contrato, spawn se rechaza.

### FX
- `ReplicatedStorage/GW/Assets/FX/Deployables/PlantZombieExploder/Arming`
- `ReplicatedStorage/GW/Assets/FX/Deployables/PlantZombieExploder/Explosion`
- `ReplicatedStorage/GW/Assets/FX/Deployables/PlantZombieExploder/ChainExplosion`

Tipo esperado:
- `Folder` con `ParticleEmitter` descendientes.

### Sounds
- `ReplicatedStorage/GW/Assets/Sounds/Deployables/PlantZombieExploder/Deploy`
- `ReplicatedStorage/GW/Assets/Sounds/Deployables/PlantZombieExploder/Arming`
- `ReplicatedStorage/GW/Assets/Sounds/Deployables/PlantZombieExploder/Explosion`
- `ReplicatedStorage/GW/Assets/Sounds/Combat/KillBell`

Nota actual:
- `ChainExplosionSoundName` reusa la ruta de `Explosion` por configuracion.

## 3) Runtime real
- Spawn en `DeployableService.spawn`
- Estado en `LegendaryExploderRuntime`:
  - `Patrol`
  - `Chase`
  - `Arming`
  - `Detonated`
  - `Finished`

Pipeline:
1. Deploy action + deploy sound.
2. Patrol/chase por target valido.
3. Trigger de arming (proximidad o touch).
4. Delay `ArmDelay`.
5. Main explosion (AOE + knockback + FX/SFX + kill credit).
6. Chain explosions desacopladas por `AutonomousEntityService`.
7. Cleanup final.

## 4) Tuning principal
- velocidad: `MoveSpeed`
- deteccion: `DetectionRadius`
- perdida target: `LoseTargetDistance`
- trigger: `TriggerRadius` / `TriggerOnTouch`
- arming: `ArmDelay`, `StopOnArm`
- explosion principal: `ExplosionDamage`, `ExplosionRadius`, `ExplosionKnockback`
- cadena: `ChainDuration`, `ChainInterval`, `ChainAreaHalfSize`, `ChainExplosionDamage`, `ChainExplosionRadius`, `ChainExplosionKnockback`, `ChainExplosionCount`

## 5) Kill credit / kill bell
Configuracion:
- `KillBellEnabled`
- `KillBellSoundName`

Ejecucion:
- `DeployableService.emitKillEvents` emite `FXEvent KillFeed` global.
- si kill bell activo, emite `FXEvent SoundCue` solo al owner.

## 6) Validacion de robustez
Cobertura actual:
- doble trigger evitado (`isArming`/`isDetonated`).
- chain runner con cleanup propio.
- bloqueos por aliado/owner respetados en AOE.
- warnings claros cuando falta FX/SFX.

## 7) Checklist de prueba
1. Ability/plantable spawnea el modelo correcto.
2. Hereda `FactionId/TeamId/OwnerUserId/SummonerUserId`.
3. Persigue target enemigo valido.
4. Entra en arming con delay.
5. Main explosion aplica dano correcto.
6. Chain explosions ejecutan durante duracion configurada.
7. Killfeed y kill bell funcionan al matar.
8. Cleanup no deja entidades huerfanas.
