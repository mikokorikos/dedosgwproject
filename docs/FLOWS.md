# Flows

Flujos runtime reales del proyecto (cliente -> servidor -> validacion -> resultado).

## 1) Flujo de disparo principal (click)

### 1. Inicio en cliente
- Script: `CombatController.client.luau`
- Trigger: `UIS.InputBegan` con `MouseButton1`.
- Guardas iniciales:
  - `gameProcessed`
  - `isTyping()` (`TextBox` activo)
  - arma equipada (`WeaponId`)

### 2. Validaciones cliente pre-envio
- Ammo local debe estar `initialized=true`.
- No estar en recarga local activa.
- `mag > 0`.
- Camara disponible para ray de apuntado.

Si `initialized=false`:
- Cliente envia `CombatRequest { action = "DryTrigger", reason = "AmmoUninitialized" }`.
- Espera `FXEvent { type = "Ammo" }` para bootstrap.

### 3. Construccion del tiro cliente
- Resuelve muzzle attachment desde `weapon.mount`.
- Construye:
  - `cameraOrigin`
  - `aimPoint`
  - `shotOrigin` (muzzle o fallback body)
  - `direction` (de muzzle hacia aim + spread)
- Hace raycast local para feedback instantaneo.
- Genera `shotId` (`<userId>-<seq>`).

### 4. Envio de red
- `CombatRequest` con `action="Shoot"` + payload de origen/direccion/plausibilidad.
- `ReportHit` se envia si cast local pego algo.
- `LocalEffectsBus.EmitShot(...)` para FX/SFX local inmediato.

### 5. Validacion servidor `CombatService`
- Entry: `Net.CombatRequest.OnServerEvent`.
- `processShoot` valida:
  - player alive
  - ammo/reload
  - cadencia (`rpm` + tolerancia)
  - origen valido relativo al cuerpo
  - distancia origen-muzzle (`muzzleMaxOffset`)
  - direccion valida
  - coherencia cono/LOS/recast cuando hay hit claim
  - target permitido por faccion (`DamageUtil.canDamage`)

### 6. Resultado servidor
- Si reject:
  - log razon
  - emite `FXEvent Shot` + `ReplicateShot` marcando `rejected` para feedback visual.
- Si accept:
  - consume ammo server-side
  - raycast autoritativo
  - aplica dano
  - emite `FXEvent Shot` + `ReplicateShot`
  - emite `FXEvent HitConfirm` al tirador si hubo dano
  - emite `FXEvent KillFeed` global si hubo kill

### 7. `ReportHit` path
- Entry: `Net.ReportHit.OnServerEvent`.
- Requiere `shotId` previamente aceptado.
- Revalida plausibilidad sin volver a forzar cadencia.
- Aplica dano solo si el shot no fue procesado antes.

## 2) Flujo de recarga + ammo sync

### 1. Recarga
- Cliente manda `CombatRequest { action = "Reload" }`.
- Servidor valida estado/municion.
- Si inicia:
  - `FXEvent ReloadStart`
  - estado server `reloading=true`
- Al terminar timer:
  - actualiza `mag/reserve`
  - `FXEvent ReloadEnd`
  - `FXEvent Ammo`

### 2. Sync de ammo
- Cliente solicita `DryTrigger` por `AmmoUninitialized` o `EmptyMag`.
- Servidor responde con `FXEvent Ammo`.
- Cliente marca `initialized=true` cuando coincide `weaponId`.

## 3) Flujo de habilidad (Q/E)

### 1. Inicio en cliente
- Script: `AbilityController.client.luau`
- Detecta bind desde `CharacterRegistry` (`abilities`).
- Guarda cooldown local por `abilityId`.

### 2. Accion de animacion
- Resuelve `actionKey`:
  - `slot.animationActionKey` o fallback por keybind (`Q/E/R`).
- Llama `ClientAnimationService.playActionWithTrigger(actionKey, callback)`.
- Callback dispara `AbilityRequest` al trigger adecuado (`instant/delay/marker`).
- Failsafe a 0.75s evita request perdido.

### 3. Validacion servidor
- Script: `AbilityService.server.luau`
- Valida payload, `abilityId`, player alive, cooldown.

### 4. Branches actuales
- `BackRocket`: gameplay de proyectil y explosion AOE.
- Ability con `deployableId`: delega a `DeployableAbilityRuntime.tryExecute`.

## 4) Flujo de BackRocket

### 1. Request
- `AbilityRequest { abilityId="BackRocket", direction }`

### 2. Server gameplay
- Esconde/regenera visual `characterRocketName`.
- Instancia proyectil desde `Assets.Projectiles`.
- Simula vuelo por `Heartbeat`.
- Al impactar/expirar:
  - `FXEvent Explosion`
  - aplica dano AOE con falloff y reglas friendly fire.

## 5) Flujo de deployable (ability summon)

### 1. Trigger
- Ability `PlantZombieDeploy` (`E`) define `deployableId`.

### 2. Spawn
- `DeployableAbilityRuntime` calcula `spawnCFrame`.
- `DeployableService.spawn(player, deployableId, cframe)`.

### 3. Validaciones de spawn
- Config deployable existe.
- `animationProfileId` requerido.
- `ModelAssetName/templateName` requerido.
- Template con `Humanoid` + `HumanoidRootPart`.

### 4. Inicializacion runtime
- Tagging via `EntityRelations.tagSummonModel`.
- Atributos: `DeployableId`, `DeployableDisplayName`, `DeployableKind`, `AnimationProfileId`.
- `ServerAnimationService.ensureRuntime` + action `Deploy`.
- Sonido deploy.
- `runPrototype` despacha runtime por `kind`.

## 6) Flujo deployable legendario (humanoid)

Script: `LegendaryExploderRuntime.luau`

### Estados
- `Patrol`
- `Chase`
- `Arming`
- `Detonated`
- `Finished`

### Ciclo
1. Patrol por waypoints aleatorios si no hay target.
2. Retarget cada `RetargetInterval`.
3. Chase del target enemigo mas cercano valido.
4. Trigger por proximidad (`TriggerRadius`) o touch.
5. Arming por `ArmDelay` con action `Arm` + FX/SFX.
6. Main explosion con dano/radio/knockback.
7. Chain explosions (runner desacoplado) con su propio dano/radio/FX/SFX.
8. Cleanup de modelo y runtime.

## 7) Flujo plantable por spot (F)

### 1. Cliente
- `PlantableController` detecta bind de `character.plantables`.
- Raycast al centro de pantalla.
- Resuelve `spotId` por `PlantSpotUtil`.
- Envia `PlantableRequest { action="Place", plantableId, spotId, position, normal }`.

### 2. Servidor
- `PlantableService.handlePlaceRequest` valida:
  - player alive
  - cooldown
  - `maxActive`
  - spot existente
  - spot enabled
  - spot type compatible
  - faccion permitida
  - rango de colocacion
  - spot libre
- Si pasa:
  - consume cooldown
  - spawnea deployable
  - marca ocupacion del spot
  - registra active model
  - inicia prototype runner
  - responde `PlantableEvent { type="Placed" }`
- Si falla:
  - `PlantableEvent { type="Rejected", reason=... }`

## 8) Flujo de dano y facciones
- Toda decision de aliado/enemigo pasa por `DamageUtil` -> `EntityRelations`.
- `CombatService` bloquea `target_friendly` cuando `allowFriendlyFire=false`.
- `DeployableService.applyExplosionAt` respeta:
  - `CanDamageAllies`
  - `CanDamageOwner`

## 9) Flujo kill credit / kill bell

### 1. Kill credit
- En explosiones de deployable se resuelve owner/summoner userId.
- Se emite `FXEvent KillFeed` con killer = owner del deployable.

### 2. Kill bell
- Si `KillBellEnabled=true`, servidor envia `FXEvent SoundCue` modo `2D` solo al owner.
- `SoundController` reproduce plantilla desde `soundPath`.

## 10) Flujo de animacion central

### 1. Binding
- `Animate.luau` llama `ClientAnimationService.bindCharacter`.
- Servicio resuelve profile desde character/player attrs o character config.

### 2. Locomotion
- `Heartbeat` evalua velocidad/estado humanoid.
- Cambia entre `Idle/Walk/Run/Jump/Fall/Death`.

### 3. Actions
- Controllers piden `playAction` o `playActionWithTrigger` por key logica.
- `AnimationRuntimeCore` carga/cacha tracks y ejecuta trigger (`instant|delay|marker`).

### 4. Server humanoids
- `ServerAnimationService` da misma semantica para deployables/NPCs.

## 11) Flujo de FX y SFX
- FX de disparo:
  - local instantaneo por `LocalEffectsBus`.
  - remoto por `ReplicateShot`.
- FX de explosion/deployable:
  - `FXEvent` tipo `Explosion`/`DeployableFX`.
- SFX:
  - disparo 3D local/remoto
  - `SoundCue` 2D/3D reusable desde servidor.
