# Animation Architecture

Arquitectura actual: animacion character-driven por profile.

## 1) Objetivo
Separar gameplay de animacion.

- Abilities definen gameplay, no `AnimationId`.
- Characters y deployables apuntan a un `animationProfileId`.
- Controllers/services piden action keys logicas (`Shoot`, `BackRocket`, `Arm`, etc.).
- Resolucion final de `AnimationId` ocurre en runtime central.

## 2) Componentes

### Config
- `src/shared/GW/Config/AnimationProfiles/*.luau`

### Shared runtime
- `src/shared/GW/Shared/AnimationKeys.luau`
- `src/shared/GW/Shared/AnimationProfileRegistry.luau`
- `src/shared/GW/Shared/AnimationRuntimeCore.luau`
- `src/shared/GW/Shared/ClientAnimationService.luau`

### Server runtime
- `src/server/GW/ServerAnimationService.luau`

### Bootstrap local
- `src/client/CharacterScripts/Animate.luau`

## 3) Fuente de verdad
`AnimationProfiles` es la fuente unica de `AnimationId` por profile.

Profile contract:
- `id`
- `defaults`
- `locomotion` map
- `actions` map

Cada entry soporta:
- `animationId`
- `priority`
- `looped`
- `fadeTime`
- `speed`
- `weight`
- `referenceSpeed`
- `triggerMode`
- `triggerMarkerName`
- `triggerDelay`

## 4) Keys canonicas

### Locomotion keys
- `Idle`
- `Walk`
- `Run`
- `Jump`
- `Fall`
- `Death`
- `Chase`

### Action keys
- `Shoot`
- `Reload`
- `AbilityQ`
- `AbilityE`
- `AbilityR`
- `AbilityGeneric`
- `Deploy`
- `Arm`
- `Explode`
- `Death`

Notas:
- Puedes agregar actions especificas por character (`BackRocket`, `PlantZombieDeploy`, etc.).
- La key debe existir en el profile correspondiente para evitar warning/fallback.

## 5) Mapeo ability -> action key

Orden de precedencia real (`ClientAnimationService.resolveAbilityActionKey`):
1. `slot.animationActionKey` (en `Config/Characters`)
2. Fallback por key bind (`Q->AbilityQ`, `E->AbilityE`, `R->AbilityR`)
3. `AbilityGeneric`

## 6) Trigger contract para abilities

`playActionWithTrigger(actionKey, onTrigger)` usa `triggerMode` del action entry:
- `instant`: callback inmediato
- `delay`: callback tras `triggerDelay`
- `marker`: callback al marker `triggerMarkerName`; si falla marker, fallback delay

Uso real:
- `AbilityController` envia `AbilityRequest` cuando llega el trigger.
- Si no hay accion/track/runtime, aplica fallback seguro y no bloquea gameplay.

## 7) Locomotion centralizada

`ClientAnimationService`:
- se inicializa una vez.
- se rebindea cuando cambia character/profile.
- en cada `Heartbeat` decide locomotion por:
  - estado humanoid
  - velocidad horizontal
  - `runThresholdRatio`

`ServerAnimationService`:
- misma semantica para humanoid NPC/deployables.
- usado por runtimes server (ej. deployable legendario).

## 8) Soporte para rigs diferentes
El sistema no asume un rig unico.

- Cada profile define su propio set de animaciones.
- Si una key no existe en un profile:
  - warning once-per-key/model
  - degradacion sin crash
- Si falta `Humanoid`/`Animator`:
  - runtime degrada y loguea warning

## 9) Integracion actual con gameplay

### Abilities
- `Config/Abilities` no contiene `AnimationId`.
- `AbilityController` dispara action key, no ids directos.

### Combate
- `CombatController` usa actions `Shoot` y `Reload` via `ClientAnimationService`.

### Deployable humanoid
- `DeployableService` exige `animationProfileId`.
- `LegendaryExploderRuntime` dispara actions logicas:
  - `Deploy`
  - `Arm`
  - `Explode`
- y locomotion:
  - `Walk` (patrol)
  - `Chase`

## 10) Como configurar un character nuevo
1. Crear `Config/AnimationProfiles/MyProfile.luau`.
2. En `Config/Characters/MyCharacter.luau` asignar `animationProfileId = "MyProfile"`.
3. En cada slot ability, opcional `animationActionKey` explicita.
4. Probar logs de `ClientAnimationService` y ausencia de warnings de key faltante.

## 11) Como cambiar animacion de BackRocket
1. Abrir profile usado por el character (ej. `SoldierAnimationProfile`).
2. Editar `actions.BackRocket.animationId`.
3. Opcional: ajustar `triggerMode` y `triggerDelay`.
4. No tocar `Config/Abilities/BackRocket.luau` para este cambio.

## 12) Como configurar deployable humanoid animado
1. Crear profile para deployable (ej. `PlantZombieExploderAnimationProfile`).
2. En deployable config poner `animationProfileId`.
3. Confirmar modelo con `Humanoid` + `HumanoidRootPart`.
4. En runtime, solo pedir action keys/locomotion keys.

## 13) Problemas comunes
- `animationProfileId` faltante: spawn/animacion bloqueada o fallback.
- action key inexistente: warning + no track.
- `animationId` mal formado: validator error.
- assets no compatibles con rig: track carga pero no se aprecia movimiento.

## 14) Reglas de mantenimiento
- No reintroducir `AnimationId` en abilities.
- No duplicar playback logic en multiples scripts.
- Mantener `AnimationProfiles` como unica fuente de ids.
- Documentar nuevas keys en este archivo y en `CONFIG_GUIDE.md`.
