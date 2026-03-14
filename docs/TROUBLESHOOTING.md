# Troubleshooting

Diagnostico rapido para fallas comunes del proyecto.

## 1) Arma no dispara
Sintoma:
- click detectado, sin dano/impacto.

Checklist:
1. Cliente (`CombatController`) logs:
   - `MouseButton1 detected`
   - `gameProcessed` / `isTyping`
   - `weapon equipped = true`
   - `Shoot request sent to server`
2. Cliente ammo state:
   - `initialized=true`
   - `mag > 0`
   - `reloading=false`
3. Servidor (`CombatService`) logs:
   - `Shoot request received`
   - `Shoot validation ...`
   - reject reason exacta si falla.

## 2) Ammo no inicializa (`initialized=false`)
Sintoma:
- `Shoot blocked: local ammo state not initialized`.

Checklist:
1. Cliente envia `DryTrigger` (`reason=AmmoUninitialized`).
2. Servidor recibe `DryTrigger` y ejecuta `forceAmmoSync`.
3. Cliente recibe `FXEvent Ammo` con `weaponId` correcto.
4. Verifica mismatch `event.weaponId` vs `localAmmo.weaponId`.

## 3) Reject `origin_muzzle_offset`
Sintoma:
- server rechaza disparo por offset origen/muzzle.

Checklist:
1. Confirmar `shotOrigin` se construye desde muzzle (no camara).
2. Verificar `mount.gunModelName` y `mount.muzzleAttachmentName`.
3. Revisar logs:
   - `Muzzle found ...`
   - `Muzzle world position ...`
   - `Origin vs muzzle distance validated ...`
4. Ajustar `net.muzzleMaxOffset` solo con evidencia de falso positivo.

## 4) `ReportHit rejected: no accepted shoot request`
Causa tipica:
- `shotId` no fue aceptado previamente por `Shoot`.

Checklist:
1. Confirmar `shotId` consistente entre `Shoot` y `ReportHit`.
2. Revisar si `Shoot` fue rechazado antes (ej. `target_friendly`, `origin_muzzle_offset`).
3. Verificar ventana TTL de accepted shots (2.5s).

## 5) Friendly fire inesperado
### Caso A: no deberia danar aliado y si dana
1. Confirmar `net.allowFriendlyFire=false` en arma.
2. Revisar atributos de ambas entidades:
   - `FactionId`
   - `TeamId`
3. Revisar tagging correcto en characters/deployables/NPCs.
4. Confirmar que dano pasa por `DamageUtil.canDamage`.

### Caso B: marca enemigo como aliado por error
1. Revisar `WorldFactionService` (ej. modelo `Rig` se marca `Plants`).
2. Revisar atributos stale en `Humanoid` vs `Model`.
3. Ver logs `Friendly target detected -> attackerFaction/targetFaction`.

## 6) Ability funciona pero no reproduce animacion
Checklist:
1. `CharacterConfig.animationProfileId` existe y es valido.
2. Slot ability tiene `animationActionKey` correcto o fallback por bind.
3. Profile contiene `actions.<ActionKey>`.
4. `animationId` valido (`rbxassetid://...` o numerico).
5. `ClientAnimationService` log de runtime bound/profile.

## 7) Animation profile no carga
Sintoma:
- error de registry/validator al arrancar.

Checklist:
1. Archivo profile retorna una tabla unica.
2. `id` no duplicado.
3. `animationId` formato valido.
4. `Character.animationProfileId` o `Deployable.animationProfileId` referencia existente.

## 8) Deployable no spawnea
Checklist:
1. `deployableId` valido en ability/plantable config.
2. Config en `Config/Deployables` existe.
3. `animationProfileId` configurado.
4. Asset `Deployables/<ModelAssetName>` existe.
5. Modelo tiene `Humanoid` + `HumanoidRootPart`.
6. Revisar error de `DeployableService.spawn` (`template_missing`, `humanoid_missing`, etc.).

## 9) Deployable spawnea pero no detecta target
Checklist:
1. `DetectionRadius` suficiente.
2. `CanDamageAllies` acorde al caso.
3. Targets vivos (`Humanoid.Health > 0`).
4. Atributos de faccion correctos en target y deployable.
5. `TargetingUtil` no filtrando por `excludeInstances` incorrecto.

## 10) Deployable no explota o explota doble
Checklist:
1. `TriggerRadius` y `TriggerOnTouch`.
2. `ArmDelay` > 0 y estado `Arming`.
3. Guardas `isArming` / `isDetonated` en runtime.
4. Revisar que no haya multiple touch triggers sin guard.

## 11) Chain explosions no salen
Checklist:
1. `ChainEnabled=true`.
2. `ChainDuration > 0`.
3. `ChainInterval` razonable.
4. `ChainExplosionFxName` y `ChainExplosionSoundName` validos.
5. `ChainExplosionCount`: si `>0`, puede terminar antes de `duration`.

## 12) Sonidos no reproducen
Checklist:
1. Ruta config correcta en `Assets/Sounds`.
2. Instancia es `Sound`.
3. `SoundId` valido (no `rbxassetid://0`).
4. Para `SoundCue` 3D, `position` presente.
5. Revisar logs de `SoundController` (`template not found`, `invalid SoundId`).

## 13) FX no reproducen
Checklist:
1. Ruta `FX/...` existe.
2. Instancia en ruta es `Folder`.
3. Folder contiene `ParticleEmitter` descendientes.
4. Revisar warning `Deployable FX folder missing`.

## 14) Plantable siempre rechazado
Causas frecuentes:
- `spot_not_found`
- `spot_type_mismatch`
- `spot_enemy_faction`
- `spot_occupied`
- `spot_out_of_range`
- `cooldown`
- `max_active`

Checklist:
1. Spot con `GWPlantSpotId` o tag `GWPlantSpot`.
2. `GWPlantSpotType` coincide con `Plantable.spotType`.
3. `GWPlantSpotFactionId` compatible con player.
4. Rango de colocacion correcto.
5. Spot libre.

## 15) Registry / require errors al iniciar
Sintomas:
- `Module code did not return exactly one value`
- `Requested module experienced an error while loading`

Checklist:
1. Cada config module retorna solo una tabla.
2. No retornar valores multiples.
3. Sin errores previos al `return`.
4. No require circular entre registries/services.
5. Hijos no `ModuleScript` en carpeta config no deben romper (registries ya los ignoran).

## 16) Logger rompe carga
Sintoma:
- crash en `Logger.emit`.

Estado actual esperado:
- logger nil-safe y protegido con `pcall`.

Checklist:
1. No concatenar valores sin `tostring`.
2. Wrappers vararg correctos (`...`).
3. Mantener `Logger` sin dependencias pesadas.

## 17) Runtime autonomo se detiene inesperadamente
Checklist:
1. Revisar `Autonomous step error` (error en `onStep`).
2. Verificar `model.Parent` (si se removio, se detiene).
3. Verificar `AutonomousEntityService.stop` reason.
4. Confirmar registro de entidad (`register`) realmente ejecutado.
