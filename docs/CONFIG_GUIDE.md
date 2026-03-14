# Config Guide

Guia operativa de configuracion basada en el estado real de `src/shared/GW/Config` y su consumo en runtime.

## 1) Regla global
- Toda configuracion editable vive en `src/shared/GW/Config`.
- Servicios/controladores deben leer config desde registries, no hardcodear valores repetidos.

## 2) Dominios de config
- `Config/Weapons/*.luau`
- `Config/Abilities/*.luau`
- `Config/Characters/*.luau`
- `Config/AnimationProfiles/*.luau`
- `Config/Deployables/*.luau`
- `Config/Plantables/*.luau`

## 3) Weapons (`Config/Weapons/<WeaponId>.luau`)

### Campos principales
| Campo | Tipo | Default runtime si falta | Que hace | Si falta |
|---|---|---|---|---|
| `id` | `string` | n/a | ID estable del arma | validator error |
| `displayName` | `string` | n/a | Nombre UI/killfeed | validator error |
| `kind` | `string` | n/a | Tipo de arma (`Hitscan`) | validator error |
| `mount.gunModelName` | `string` | `SoldierGun` | gun model para buscar muzzle | fallback en busqueda |
| `mount.muzzleAttachmentName` | `string` | `Muzzle` | nombre attachment muzzle | fallback generico |
| `fire.rpm` | `number` | `420` | cadencia | validator requiere >0 |
| `fire.auto` | `boolean` | n/a | automatico o semiauto | validator requiere |
| `ammo.magSize` | `number` | `30` (server fallback) | tamano cargador | validator requiere >=1 |
| `ammo.reserve` | `number` | `90` (server fallback) | reserva inicial | validator requiere >=0 |
| `ammo.reloadTime` | `number` | `2.0` | tiempo recarga | validator requiere >0 |
| `hitscan.range` | `number` | `800` | distancia maxima | validator requiere >0 |
| `hitscan.damage` | `number` | `0` en server si falta | dano base | validator requiere >0 |
| `fx.*` | `table` | templates fallback por nombre | rutas FX | si falta, FX degrada |
| `sfx.*` | `table` | n/a | rutas sonido shot/hit/kill | si falta, warning |
| `net.allowFriendlyFire` | `boolean` | `false` | permite dano aliado | friendly fire bloqueado por default |
| `net.origin* / muzzleMaxOffset` | `number` | `20/14` aprox | tolerancias plausibilidad origen | defaults en `CombatService` |
| `net.rofTolerance` | `number` | `0` | tolerancia cadencia | default estricta |
| `net.maxConeAngle` | `number` | `6` grados | cono max entre direccion y hit claim | bloquea claims irreales |
| `net.losTolerance` | `number` | `12` | tolerancia LOS/recast | default `12` |

### Limites de seguridad (`ConfigValidator`)
- `net.rofTolerance`: `0..1`
- `net.maxConeAngle`: `>0` y `<=45`
- `net.losTolerance`: `>0` y `<=64`
- offsets origen: `>0` y `<=256`

### Ejemplo real
- `src/shared/GW/Config/Weapons/SoldierRifle.luau`

## 4) Abilities (`Config/Abilities/<AbilityId>.luau`)

### Contrato actual
- Abilities definen gameplay (cooldown, parametros), no `AnimationId`.
- Animacion se resuelve por `AnimationProfile` + `animationActionKey`.

### Campos comunes
| Campo | Tipo | Default runtime | Que hace | Si falta |
|---|---|---|---|---|
| `id` | `string` | n/a | ID habilidad | validator error |
| `cooldown` | `number` | `0` | cooldown server/local | sin cooldown si falta |
| `friendlyFire` | `boolean` | `false` de facto en checks | permite dano aliado | se bloquea aliado por default |
| `selfDamage` | `boolean` | `false` | autodanio | no se aplica autodanio |

### Campos BackRocket
| Campo | Tipo | Default runtime | Uso |
|---|---|---|---|
| `characterRocketName` | `string` | n/a | parte visual a ocultar/regenerar |
| `spawnForwardOffset` | `number` | `2.2` | offset spawn proyectil |
| `spawnUpOffset` | `number` | `0.35` | offset vertical |
| `projectileTemplateName` | `string` | n/a | template en `Assets.Projectiles` |
| `projectileBodyName` | `string` | fallback a PrimaryPart/primer BasePart | cuerpo del proyectil |
| `projectileSpeed` | `number` | `80` | velocidad |
| `maxDistance` | `number` | `220` | distancia maxima |
| `lifetime` | `number` | `2.8` | ttl proyectil |
| `launchSoundName` | `string` | optional | sonido lanzamiento |
| `flightLoopSoundName` | `string` | optional | loop vuelo |
| `explosionRadius` | `number` | `12` | radio explosion |
| `explosionMaxDamage` | `number` | `45` | dano max |
| `explosionMinDamage` | `number` | `10` | dano min |
| `explosionFalloffExponent` | `number` | `1.0` | curva falloff |
| `fx.explosionEmittersFolderName` | `string` | optional | FX explosion |
| `sfx.explosionSoundName` | `string` | optional | SFX explosion |

### Campos deployable ability
| Campo | Tipo | Default runtime | Uso |
|---|---|---|---|
| `deployableId` | `string` | n/a | ID deployable a invocar |
| `deployableSpawnForwardOffset` | `number` | `4.0` | offset frente al jugador |
| `deployableSpawnUpOffset` | `number` | `0.0` | offset vertical |
| `deployableUsePrototypeRunner` | `boolean` | `false` | iniciar `runPrototype` |

### Campos removidos del contrato viejo
Ya no se usan en runtime:
- `clientAnimId`
- `useMarker`
- `launchMarkerName`
- `fallbackLaunchDelay`

## 5) Characters (`Config/Characters/<CharacterId>.luau`)

### Campos
| Campo | Tipo | Default runtime | Que hace | Si falta |
|---|---|---|---|---|
| `id` | `string` | n/a | ID character | validator error |
| `weaponId` | `string` | n/a | arma primaria | validator error |
| `animationProfileId` | `string` | n/a | profile animacion character-driven | validator error |
| `abilities[]` | array | `{} / fallback controller` | binds de habilidades | opcional |
| `abilities[].id` | `string` | n/a | ability id | validator cruza registry |
| `abilities[].key` | `string?` | optional | tecla bind | fallback segun controller |
| `abilities[].animationActionKey` | `string?` | fallback por keybind (`Q/E/R`) | action key animacion | opcional |
| `plantables[]` | array | `{} / fallback default plantable` | binds plantables | opcional |
| `plantables[].id` | `string` | n/a | plantable id | validator cruza registry |
| `plantables[].key` | `string?` | optional | tecla bind | fallback controller |

### Ejemplo real
- `src/shared/GW/Config/Characters/Soldier.luau`

## 6) Animation Profiles (`Config/AnimationProfiles/<ProfileId>.luau`)

### Campos profile
| Campo | Tipo | Default runtime | Uso |
|---|---|---|---|
| `id` | `string` | n/a | ID profile |
| `isDefault` | `boolean?` | registry fallback | profile default |
| `defaults.fadeTime` | `number` | `0.12` | fade global |
| `defaults.speed` | `number` | `1` | speed global |
| `defaults.weight` | `number` | `1` | weight global |
| `defaults.triggerDelay` | `number` | `0.2` | delay trigger por default |
| `defaults.runThresholdRatio` | `number` | `0.75` aprox | switch walk/run |

### Entry (`locomotion.*` o `actions.*`)
| Campo | Tipo | Default runtime | Uso |
|---|---|---|---|
| `animationId` | `string` | n/a | id animacion (`rbxassetid://` o numerico) |
| `priority` | `string` | `Action` / segun contexto | prioridad track |
| `looped` | `boolean` | `false` salvo locomotion | loop |
| `fadeTime` | `number` | `defaults.fadeTime` | fade entry |
| `speed` | `number` | `defaults.speed` | speed entry |
| `weight` | `number` | `defaults.weight` | weight entry |
| `referenceSpeed` | `number` | fallback runtime | escalado locomotion |
| `triggerMode` | `string` | `instant` | `instant|delay|marker` |
| `triggerMarkerName` | `string` | `Launch` | marker de trigger |
| `triggerDelay` | `number` | `defaults.triggerDelay` | delay trigger |

### Si falta action/track/profile
- Se loguea warning.
- Gameplay continua (degradacion segura).

## 7) Deployables (`Config/Deployables/<DeployableId>.luau`)

`DeployableService.normalizeBehaviorConfig` aplica precedencia:
- campo canonico > alias legacy > default runtime.

### Campos canonicos (recomendados)
| Campo | Tipo | Default runtime | Si falta | Uso |
|---|---|---|---|---|
| `id` | `string` | n/a | validator error | ID deployable |
| `displayName` | `string?` | `id` | fallback | nombre UI/killfeed |
| `kind` | `string?` | `exploder` | fallback | selector runtime |
| `animationProfileId` | `string` | none | spawn bloqueado | profile animacion humanoid |
| `ModelAssetName` | `string` | none | spawn bloqueado | modelo en `Assets/Deployables` |
| `bodyPartName` | `string` | `HumanoidRootPart` | fallback | cuerpo principal |
| `MaxHealth` | `number?` | optional | sin override | vida humanoid |
| `Lifetime` | `number` | `12` | fallback | TTL deployable |
| `KillBellEnabled` | `boolean` | `true` | fallback | kill bell owner |
| `KillBellSoundName` | `string` | `Combat/KillBell` | fallback | ruta cue kill bell |
| `CanDamageAllies` | `boolean` | `false` | fallback | friendly fire deployable |
| `CanDamageOwner` | `boolean` | `false` | fallback | dano al owner |
| `DeploySoundName` | `string?` | optional | warning | sonido deploy |
| `MoveSpeed` | `number` | `10` | fallback | velocidad |
| `DetectionRadius` | `number` | `28` | fallback | radio deteccion |
| `RetargetInterval` | `number` | `0.25` | fallback | intervalo retarget |
| `PatrolEnabled` | `boolean` | `true` | fallback | activar patrol |
| `PatrolRadius` | `number` | `16` | fallback | radio patrol |
| `PatrolStepInterval` | `number` | `0.8` | fallback | paso patrol |
| `LoseTargetDistance` | `number` | `DetectionRadius*1.5` | fallback | distancia perdida target |
| `TriggerRadius` | `number` | `4.5` | fallback | trigger proximidad |
| `TriggerOnTouch` | `boolean` | `true` | fallback | trigger por touch |
| `ArmDelay` | `number` | `2.0` | fallback | delay arming |
| `StopOnArm` | `boolean` | `true` | fallback | detener movimiento en arm |
| `ArmingSoundName` | `string?` | optional | warning | sonido arm |
| `ArmingFxName` | `string?` | optional | warning | FX arm |
| `ExplosionDamage` | `number` | `40` | fallback | dano explosion principal |
| `ExplosionMinDamage` | `number` | `ExplosionDamage` | fallback | min dano falloff |
| `ExplosionRadius` | `number` | `11` | fallback | radio principal |
| `ExplosionFalloffExponent` | `number` | `1.0` | fallback | curva falloff |
| `ExplosionSoundName` | `string?` | optional | warning | SFX principal |
| `ExplosionFxName` | `string?` | optional | warning | FX principal |
| `ExplosionKnockback` | `number` | `0` | fallback | knockback principal |
| `ChainEnabled` | `boolean` | `false` | fallback | habilita chain |
| `ChainDuration` | `number` | `0` | fallback | duracion chain |
| `ChainInterval` | `number` | `0.35` | fallback | intervalo chain |
| `ChainAreaHalfSize` | `number` | `14` | fallback | semitamanio area chain |
| `ChainExplosionDamage` | `number` | `~45% main` | fallback | dano chain |
| `ChainExplosionRadius` | `number` | `8` | fallback | radio chain |
| `ChainExplosionSoundName` | `string?` | fallback a explosion si configurado | fallback | SFX chain |
| `ChainExplosionFxName` | `string?` | fallback a explosion si configurado | fallback | FX chain |
| `ChainExplosionKnockback` | `number` | `0` | fallback | knockback chain |
| `ChainExplosionCount` | `number` | `0` | fallback | 0 = ilimitado por count |

### Aliases legacy activos
| Canonico | Alias legacy aceptados |
|---|---|
| `ModelAssetName` | `templateName` |
| `Lifetime` | `lifetime` |
| `MaxHealth` | `maxHealth` |
| `MoveSpeed` | `moveSpeed` |
| `DetectionRadius` | `detectionRadius` |
| `TriggerRadius` | `triggerRadius` |
| `TriggerOnTouch` | `triggerOnTouch` |
| `ArmDelay` | `armDelay` |
| `CanDamageAllies` | `allowFriendlyFire` |
| `ExplosionRadius` | `explosionRadius` |
| `ExplosionDamage` | `explosionMaxDamage` |
| `ExplosionMinDamage` | `explosionMinDamage` |
| `ExplosionFalloffExponent` | `explosionFalloffExponent` |
| `ExplosionKnockback` | `explosionKnockback` |
| `ArmingFxName` | `fx.armingFxName`, `fx.armingEmittersPath`, `fx.spawnEmittersPath` |
| `ExplosionFxName` | `fx.explosionFxName`, `fx.explosionEmittersPath` |
| `ChainExplosionFxName` | `fx.chainExplosionFxName`, `fx.chainExplosionEmittersPath` |
| `DeploySoundName` | `sfx.deploySoundName`, `sfx.deploySoundPath`, `sfx.spawnSoundPath` |
| `ArmingSoundName` | `sfx.armingSoundName`, `sfx.explodeSequenceSoundPath` |
| `ExplosionSoundName` | `sfx.explosionSoundName`, `sfx.explosionSoundPath` |
| `ChainExplosionSoundName` | `sfx.chainExplosionSoundName`, `sfx.chainExplosionSoundPath`, fallback explosion |
| `KillBellSoundName` | `sfx.killBellSoundPath` |

### Ejemplo real
- `src/shared/GW/Config/Deployables/PlantZombieExploder.luau`

## 8) Plantables (`Config/Plantables/<PlantableId>.luau`)

| Campo | Tipo | Default runtime | Que hace | Si falta |
|---|---|---|---|---|
| `id` | `string` | n/a | ID plantable | validator error |
| `displayName` | `string?` | optional | nombre UI | optional |
| `deployableId` | `string` | n/a | deployable a spawnear | validator error |
| `spotType` | `string?` | optional | tipo de spot permitido | sin filtro tipo |
| `allowEnemySpots` | `boolean` | `false` | permite spot de faccion enemiga | bloquea enemy spots |
| `requiresFreeSpot` | `boolean` | `true` | exige spot libre | puede permitir sobreescritura si false |
| `placeRange` | `number` | `32` | rango max desde player | fallback |
| `selectionRadius` | `number` | `6` | radio para resolver spot por posicion | fallback |
| `spawnForwardOffset` | `number` | `0` | offset spawn frente spot | fallback |
| `spawnUpOffset` | `number` | `0` | offset vertical | fallback |
| `cooldown` | `number` | `0` | cooldown por player/plantable | sin cooldown |
| `maxActive` | `number` | infinito | max activos por player | sin limite |
| `usePrototypeRunner` | `boolean` | `true` de facto en flujo | ejecutar runtime | si false solo spawn |

### Ejemplo real
- `src/shared/GW/Config/Plantables/PlantZombieSpotExploder.luau`

## 9) Equipos/facciones (atributos runtime)

No hay `Config/Factions` formal hoy. La configuracion se hace por atributos/runtime:

### Atributos de entidad
- `FactionId`
- `TeamId`
- `OwnerUserId`
- `SummonerUserId`

### Donde se asignan
- Players/characters: `CharacterService`.
- Summons/deployables: `EntityRelations.tagSummonModel` desde `DeployableService`.
- Rig world NPC fijo: `WorldFactionService` (`Rig` -> `Plants`).
- Spot optional faction: `GWPlantSpotFactionId`.

### Regla de oro
- Logica de aliados/enemigos solo en `EntityRelations`/`DamageUtil`.

## 10) Ejemplos practicos de configuracion nueva

### A) Nuevo character con animation profile
1. Crear `Config/AnimationProfiles/MyCharacterProfile.luau`.
2. Crear/editar `Config/Characters/MyCharacter.luau`:
   - `animationProfileId = "MyCharacterProfile"`
   - `abilities` con `animationActionKey` por slot.

### B) Cambiar animacion de una ability sin tocar ability config
1. Abrir profile del character (`Config/AnimationProfiles/...`).
2. Cambiar `actions.<ActionKey>.animationId`.
3. Si quieres timing de request, ajustar `triggerMode/triggerDelay/triggerMarkerName`.

### C) Nuevo deployable humanoid
1. Crear `Config/Deployables/MyDeployable.luau` con:
   - `animationProfileId`
   - `ModelAssetName`
   - tunables de movimiento/explosion.
2. Crear profile de animacion para ese deployable.
3. Asegurar asset con `Humanoid` + `HumanoidRootPart`.
4. Integrar `kind` en `DeployableService.runPrototype`.

### D) Tuning rapido deployable legendario
- velocidad: `MoveSpeed`
- deteccion: `DetectionRadius`
- trigger: `TriggerRadius`
- arming: `ArmDelay`
- dano/radio principal: `ExplosionDamage`, `ExplosionRadius`
- chain: `ChainDuration`, `ChainInterval`, `ChainAreaHalfSize`, `ChainExplosionDamage`, `ChainExplosionRadius`
- audio/FX: `DeploySoundName`, `ArmingSoundName`, `ExplosionSoundName`, `ChainExplosionSoundName`, `ArmingFxName`, `ExplosionFxName`, `ChainExplosionFxName`

### E) Kill bell
- En deployable config:
  - `KillBellEnabled = true`
  - `KillBellSoundName = "Combat/KillBell"`

## 11) Como probar que la config quedo bien
1. Revisar output de registries al cargar (sin errores de `ConfigValidator`).
2. Verificar logs de spawn/ability/combat en runtime.
3. Confirmar que remotes reciben payload esperado.
4. Confirmar que faltantes de assets solo generan warning y no crash (excepto contratos estrictos como humanoid deployable).
