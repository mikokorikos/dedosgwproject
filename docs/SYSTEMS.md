# Systems

Este documento resume los sistemas reales del repo y sus contratos operativos.

## 0) Matriz rapida (modulo -> responsabilidad -> dependencias -> remotes/eventos -> config)
| Modulo | Responsabilidad | Dependencias clave | Remotes/Eventos | Config que lee |
|---|---|---|---|---|
| `CombatController.client` | Input disparo/recarga + ammo local + envio shoot/report | `WeaponRegistry`, `ClientAnimationService`, `Net` | Emite `CombatRequest`, `ReportHit`; recibe `FXEvent` | `Weapons` |
| `CombatService.server` | Validacion autoritativa + dano + ammo sync | `WeaponRegistry`, `DamageUtil`, `RaycastUtil`, `Net` | Recibe `CombatRequest`, `ReportHit`; emite `FXEvent`, `ReplicateShot` | `Weapons` |
| `AbilityController.client` | Input ability + trigger animacion + envio request | `CharacterRegistry`, `AbilityRegistry`, `ClientAnimationService`, `Net` | Emite `AbilityRequest` | `Characters`, `Abilities`, `AnimationProfiles` |
| `AbilityService.server` | Cooldown/validacion + ejecucion gameplay de ability | `AbilityRegistry`, `DeployableAbilityRuntime`, `DamageUtil`, `Net` | Recibe `AbilityRequest`; emite `FXEvent` (`Explosion`) | `Abilities` |
| `DeployableService` | Spawn/normalizacion/FX-SFX/AOE/kill credit | `DeployableRegistry`, `DamageUtil`, `EntityRelations`, `TargetingUtil`, `ServerAnimationService`, `Net` | Emite `FXEvent` (`DeployableFX`, `SoundCue`, `KillFeed`) | `Deployables` |
| `LegendaryExploderRuntime` | FSM patrol/chase/arm/explode/chain | `AutonomousEntityService`, `DamageUtil`, deps de `DeployableService` | no remote directo (usa deps que emiten FX) | `Deployables` (normalizado) |
| `PlantableController.client` | Input plantable + raycast spot + request | `CharacterRegistry`, `PlantableRegistry`, `PlantSpotUtil`, `Net` | Emite `PlantableRequest`; recibe `PlantableEvent` | `Characters`, `Plantables` |
| `PlantableService.server` | Validacion spot/cooldown/maxActive + spawn + ocupacion | `PlantableRegistry`, `PlantSpotUtil`, `EntityRelations`, `DeployableService`, `Net` | Recibe `PlantableRequest`; emite `PlantableEvent` | `Plantables` |
| `ClientAnimationService` | Runtime local profile-driven + locomotion/action trigger | `CharacterRegistry`, `AnimationProfileRegistry`, `AnimationRuntimeCore`, `AnimationKeys` | No remote directo | `Characters`, `AnimationProfiles` |
| `ServerAnimationService` | Runtime server para humanoid NPC/deployables | `AnimationProfileRegistry`, `AnimationRuntimeCore` | No remote directo | `AnimationProfiles` |
| `EntityRelations` / `DamageUtil` | Reglas de aliado/enemigo y decisiones canDamage/canTarget/canHeal | `Players` | Consumido por servicios gameplay | attrs runtime (`FactionId`, `TeamId`, etc.) |

## 1) Shared core (fuente de verdad)

### EntityRelations
Archivo: `src/shared/GW/Shared/EntityRelations.luau`

Responsabilidad:
- Resolver contexto de una entidad (`Player`, `Model`, `Humanoid`, `BasePart`).
- Determinar aliados/enemigos.
- Resolver ownership (`OwnerUserId`, `SummonerUserId`).
- Etiquetar entidades runtime con atributos de relacion.

Dependencias:
- `Players`

Consume:
- Atributos: `FactionId`, `TeamId`, `OwnerUserId`, `SummonerUserId`, aliases `GW*`.

Produce:
- API de relacion consumida por combate, habilidades, deployables, plantables.

Funciones publicas:
- `getContext(entity): RelationContext?`
- `getFactionId(entity): string?`
- `getTeamId(entity): string?`
- `resolveOwnerUserId(entity): number?`
- `resolveSummonerUserId(entity): number?`
- `getOwnerUserId(entity): number?`
- `areAllies(a, b): boolean`
- `areEnemies(a, b): boolean`
- `isSameTeam(a, b): boolean`
- `isEnemyTeam(a, b): boolean`
- `canDamage(attacker, targetHumanoid, allowFriendlyFire): boolean`
- `canTarget(seeker, targetHumanoid, allowFriendlyFire): boolean`
- `canHeal(source, targetHumanoid, allowCrossTeam): boolean`
- `getCollisionResponse(a, b, allowFriendlyCollision): "collide" | "ignore"`
- `tagEntity(instance, options): ()`
- `tagSummonModel(model, ownerPlayer, factionIdOverride): ()`

Efectos secundarios:
- `tagEntity`/`tagSummonModel` escriben atributos en instancias.

### DamageUtil
Archivo: `src/shared/GW/Shared/DamageUtil.luau`

Responsabilidad:
- Facade gameplay sobre `EntityRelations`.
- Calculo de falloff de dano.

Funciones publicas:
- `isFriendly(shooter, targetHum, allowFriendlyFire): boolean`
- `getFactionId(entity): string?`
- `getTeamId(entity): string?`
- `areAllies(a, b): boolean`
- `areEnemies(a, b): boolean`
- `computeFalloff(baseDamage, dist, falloff?): number`
- `canDamage(attacker, targetHum, allowFriendlyFire): boolean`
- `canTarget(attacker, targetHum, allowFriendlyFire): boolean`
- `canHeal(source, targetHum, allowCrossTeam): boolean`
- `resolveOwnerUserId(entity): number?`
- `resolveSummonerUserId(entity): number?`

### TargetingUtil
Archivo: `src/shared/GW/Shared/TargetingUtil.luau`

Responsabilidad:
- Adquisicion reusable de targets por radio + filtro de faccion.

Funciones publicas:
- `collectHumanoidsInRadius(sourceEntity, origin, radius, options?): {TargetEntry}`
- `findClosestEnemyHumanoid(sourceEntity, origin, radius, allowFriendlyFire, excludeInstances?): (Humanoid?, number?, BasePart?)`

### PlantSpotUtil
Archivo: `src/shared/GW/Shared/PlantSpotUtil.luau`

Responsabilidad:
- Contrato de spot plantable y utilidades de busqueda.

Constantes:
- `SPOT_TAG = "GWPlantSpot"`
- `SPOT_ID_ATTRIBUTE = "GWPlantSpotId"`
- `SPOT_TYPE_ATTRIBUTE = "GWPlantSpotType"`
- `SPOT_ENABLED_ATTRIBUTE = "GWPlantSpotEnabled"`
- `SPOT_FACTION_ATTRIBUTE = "GWPlantSpotFactionId"`

Funciones publicas:
- `isSpot(inst): boolean`
- `findSpotFromInstance(inst): BasePart?`
- `getSpotId(spot): string?`
- `getSpotType(spot): string?`
- `getSpotFactionId(spot): string?`
- `isSpotEnabled(spot): boolean`
- `collectSpots(root?): {BasePart}`

### Logger
Archivo: `src/shared/GW/Shared/Logger.luau`

Responsabilidad:
- Logging nil-safe con niveles y scope.
- No debe romper runtime aunque reciba argumentos invalidos.

API publica:
- `setEnabled(enabled)`
- `setMinLevel(level)`
- `scoped(scope): ScopedLogger`
- `trace(...)`
- `info(...)`
- `warn(...)`
- `error(...)`

Niveles:
- `TRACE`, `INFO`, `WARN`, `ERROR`

Formato real:
- `[GW][<Scope>][Client|Server] ...`
- WARN/ERROR agregan `[WARN]` / `[ERROR]`.

### Net
Archivo: `src/shared/GW/Shared/Net.luau`

Responsabilidad:
- Exponer referencias centralizadas a remotes.

Remotes:
- `CombatRequest`
- `ReportHit`
- `ReplicateShot`
- `AbilityRequest`
- `PlantableRequest`
- `PlantableEvent`
- `FXEvent`

### Animation system shared
Archivos:
- `AnimationKeys.luau`
- `AnimationProfileRegistry.luau`
- `AnimationRuntimeCore.luau`
- `ClientAnimationService.luau`

Responsabilidad:
- Resolver y reproducir animaciones por profile.
- Mantener locomotion y acciones por key logica.

APIs publicas principales:
- `AnimationKeys.actionFromBindKey(bindKey): string`
- `AnimationRuntimeCore.create(model, profile): Runtime`
- `ClientAnimationService.ensureInitialized()`
- `ClientAnimationService.bindCharacter(character)`
- `ClientAnimationService.getCurrentProfileId(): string?`
- `ClientAnimationService.resolveAbilityActionKey(bindKey, explicitActionKey): string`
- `ClientAnimationService.playAction(actionKey): boolean`
- `ClientAnimationService.playActionWithTrigger(actionKey, onTrigger?): boolean`
- `ClientAnimationService.shutdown()`

### Config + registries
Archivos:
- `ConfigValidator.luau`
- `AbilityRegistry.luau`
- `WeaponRegistry.luau`
- `AnimationProfileRegistry.luau`
- `DeployableRegistry.luau`
- `PlantableRegistry.luau`
- `CharacterRegistry.luau`
- `RegistryLinker.luau`

Responsabilidad:
- Cargar config por dominio.
- Validar shape/tipos/rangos y referencias cruzadas.
- Exponer `ById`, `DefaultId`, `Get(...)`.

Notas:
- Registries ignoran hijos que no sean `ModuleScript`.
- Si un modulo no retorna tabla, se levanta error claro.

## 2) Server systems

### CharacterService
Archivo: `src/server/GW/CharacterService.server.luau`

Responsabilidad:
- Inicializar atributos base de jugador.
- Propagar character/weapon/profile/plantable/faccion.
- Etiquetar character con ownership + relation attrs.

Depende de:
- `CharacterRegistry`, `WeaponRegistry`, `PlantableRegistry`, `EntityRelations`, `Net`.

Lee config:
- `Config/Characters/*`.

Escribe atributos:
- En player: `CharacterId`, `WeaponId`, `AnimationProfileId`, `PlantableId`, `FactionId`, `TeamId`.
- En character model: relation attrs + `AnimationProfileId`.

Eventos:
- `Players.PlayerAdded`
- `player.CharacterAdded`
- `player.Team changed`

### CombatService
Archivo: `src/server/GW/CombatService.server.luau`

Responsabilidad:
- Autoridad de disparo hitscan y recarga.
- Validaciones anti-cheat (cadencia, origen/direccion/plausibilidad, LOS, relaciones).
- Aplicar dano y emitir FX/hitconfirm/killfeed.
- Gestion de ammo server-authoritative + handshake.

Depende de:
- `Net`, `WeaponRegistry`, `RaycastUtil`, `DamageUtil`, `Logger`.

Consume config:
- `Weapons.<id>.fire/ammo/hitscan/net/sfx/fx`.

Eventos de entrada:
- `CombatRequest` (`Shoot|Reload|DryTrigger`)
- `ReportHit`

Eventos de salida:
- `FXEvent` (`Ammo`, `DryFire`, `Shot`, `HitConfirm`, `KillFeed`, `ReloadStart`, `ReloadEnd`)
- `ReplicateShot`

### AbilityService
Archivo: `src/server/GW/AbilityService.server.luau`

Responsabilidad:
- Validar `AbilityRequest` y cooldown server-side.
- Ejecutar gameplay de abilities.
- Branch de deployable via `DeployableAbilityRuntime`.
- BackRocket (projectile visual server-side + explosion AOE).

Depende de:
- `AbilityRegistry`, `DamageUtil`, `DeployableAbilityRuntime`, `Net`.

Consume config:
- `Config/Abilities/*`.

Salida:
- `FXEvent` `Explosion` (BackRocket) y spawn de deployable por servicio dedicado.

### DeployableService
Archivo: `src/server/GW/DeployableService.luau`

Responsabilidad:
- Resolver config normalizada (canon + aliases legacy).
- Spawn de deployables humanoid (validaciones estrictas de asset).
- Tagging de relation attrs.
- Integrar runtime animacion servidor.
- Aplicar explosiones AOE y kill credit/kill bell.
- Despachar runtime por `kind` (`runPrototype`).

Depende de:
- `Net`, `AssetResolver`, `DamageUtil`, `DeployableRegistry`, `EntityRelations`, `TargetingUtil`, `ServerAnimationService`, `LegendaryExploderRuntime`.

Funciones publicas:
- `findClosestEnemyHumanoid(sourceModel, radius, allowFriendlyFire)`
- `createDetachedChainRuntimeAnchor(sourceEntity, position)`
- `applyExplosionAt(sourceEntity, centerPos, spec, meta?)`
- `explode(sourceModel, cfg, reason?)`
- `spawn(ownerPlayer, deployableId, requestedSpawnCFrame)`
- `runExploderPrototype(spawnResult)`
- `runPrototype(spawnResult)`

Salida de red:
- `FXEvent` `DeployableFX`, `SoundCue`, `KillFeed`.

### LegendaryExploderRuntime
Archivo: `src/server/GW/DeployableRuntimes/LegendaryExploderRuntime.luau`

Responsabilidad:
- Estado runtime del deployable legendario.

Estados:
- `Patrol`, `Chase`, `Arming`, `Detonated`, `Finished`.

Comportamientos:
- Patrol waypoint aleatorio.
- Chase target enemigo mas cercano.
- Trigger por proximidad/touch.
- Arming delay + action/FX/SFX.
- Main explosion + chain explosions con runner desacoplado.

API publica:
- `run(spawnResult, deps)`

### AutonomousEntityService
Archivo: `src/server/GW/AutonomousEntityService.luau`

Responsabilidad:
- Scheduler central de entidades autonomas.
- Registro, step loop, cleanup, lifecycle.

API publica:
- `register(model, options?): RuntimeEntry`
- `bindConnection(model, connection)`
- `getEntry(model): RuntimeEntry?`
- `isRegistered(model): boolean`
- `stop(model, reason?)`
- `count(): number`

### PlantableService
Archivo: `src/server/GW/PlantableService.server.luau`

Responsabilidad:
- Pipeline separado de plantables por spot.
- Validar cooldown, maxActive, tipo/faccion/ocupacion/rango de spot.
- Spawn via `DeployableService`.
- Marcar y liberar ocupacion de spot.

Depende de:
- `Net`, `PlantableRegistry`, `PlantSpotUtil`, `EntityRelations`, `DeployableService`.

Entrada:
- `PlantableRequest` (`Place` | `Preview`)

Salida:
- `PlantableEvent` (`Placed`, `Rejected`, `PreviewAck`)

### ServerAnimationService
Archivo: `src/server/GW/ServerAnimationService.luau`

Responsabilidad:
- Runtime de animacion server-side para humanoid NPC/deployables.

API publica:
- `ensureRuntime(model, profileId?): Runtime?`
- `playAction(model, actionKey): boolean`
- `setLocomotionState(model, locomotionKey, speedScale?): boolean`
- `stopLocomotion(model, fadeTime?)`
- `cleanupModel(model)`

### WorldFactionService
Archivo: `src/server/GW/WorldFactionService.server.luau`

Responsabilidad:
- Aplicar faccion fija a rigs world no-player.

Estado actual:
- Busca modelos llamados `Rig` en Workspace y los marca como `Plants`.

### StatusService / ProjectileService
Archivos:
- `src/server/GW/StatusService.server.luau`
- `src/server/GW/ProjectileService.server.luau`

Estado:
- `stub` (solo print inicial).

## 3) Client systems

### AbilityController
Archivo: `src/client/PlayerScripts/GW/AbilityController.client.luau`

Responsabilidad:
- Detectar input de abilities.
- Resolver bind por character config.
- Resolver `actionKey` de animacion.
- Reproducir accion local con trigger callback.
- Enviar `AbilityRequest`.

Depende de:
- `CharacterRegistry`, `AbilityRegistry`, `ClientAnimationService`, `Net`, `Logger`.

### CombatController
Archivo: `src/client/PlayerScripts/GW/CombatController.client.luau`

Responsabilidad:
- Input disparo/recarga.
- Estado local de ammo + sincronizacion por `DryTrigger`/`Ammo`.
- Construccion de origen/direccion de disparo desde muzzle + aim.
- Envio de `CombatRequest` y `ReportHit`.
- FX local instantaneo y animaciones `Shoot/Reload`.

Depende de:
- `WeaponRegistry`, `AnimationKeys`, `ClientAnimationService`, `LocalEffectsBus`, `Net`.

### PlantableController
Archivo: `src/client/PlayerScripts/GW/PlantableController.client.luau`

Responsabilidad:
- Input de plantables.
- Raycast centro pantalla para spot.
- Envio de `PlantableRequest`.
- Manejo de `PlantableEvent`.

### FXController
Archivo: `src/client/PlayerScripts/GW/FXController.client.luau`

Responsabilidad:
- Render de muzzle/tracer/impact/explosion usando templates de `Assets.FX`.
- Reacciona a `ReplicateShot`, `FXEvent` y `LocalEffectsBus`.

### SoundController
Archivo: `src/client/PlayerScripts/GW/SoundController.client.luau`

Responsabilidad:
- Sonido 3D de disparo.
- Consumo de `FXEvent` `SoundCue` (2D/3D) para cues reutilizables.

### CombatUIController
Archivo: `src/client/PlayerScripts/GW/CombatUIController.client.luau`

Responsabilidad:
- Hitmarker, killfeed local y sonidos de confirmacion.
- Consume `FXEvent` (`HitConfirm`, `KillFeed`).

### LocalEffectsBus
Archivo: `src/client/PlayerScripts/GW/LocalEffectsBus.luau`

Responsabilidad:
- Event bus local para shot prediction.

API publica:
- `EmitShot(ev)`
- `OnShot(callback)`

### Animate bootstrap
Archivo: `src/client/CharacterScripts/Animate.luau`

Responsabilidad:
- Bootstrap del nuevo runtime de animacion (`ClientAnimationService`).

## 4) Dependencias criticas entre sistemas
- `CombatService` depende de `DamageUtil` para friendly fire/target rules.
- `DeployableService` depende de `ServerAnimationService` para acciones/locomotion humanoid.
- `LegendaryExploderRuntime` depende de `AutonomousEntityService` para su loop.
- `AbilityController` depende de `ClientAnimationService` para trigger timing.
- `PlantableService` usa `DeployableService` para spawn real.
- `CharacterRegistry` depende de `Ability/Weapon/Plantable/AnimationProfile` registries para integridad cruzada.

## 5) Sistemas con deuda/limitaciones
- Pathfinding avanzado no implementado (movimiento simple directo).
- `StatusService` y `ProjectileService` no tienen gameplay real.
- Config/asset pipelines dependen de assets en Studio fuera de `src`.
