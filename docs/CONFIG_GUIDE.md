# Config Guide

## 1) Principio base
La configuracion debe vivir en registries/modulos de `src/shared/GW/Config`.
No hardcodear stats o IDs repetidos en controllers/services.

Estructura actual:
- `Config/Weapons/*.luau`
- `Config/Abilities/*.luau`
- `Config/Characters/*.luau`

## 2) Donde cambiar cada cosa

### Armas (`Config/Weapons/<WeaponId>.luau`)
- Danio base hitscan: `hitscan.damage`
- Rango: `hitscan.range`
- Cadencia: `fire.rpm`
- Auto/semi: `fire.auto`
- Spread validado server: `net.maxConeAngle`
- Cargador: `ammo.magSize`
- Reserva: `ammo.reserve`
- Tiempo de recarga: `ammo.reloadTime`
- Tolerancias de validacion:
  - `net.originOffsetTolerance`
  - `net.maxOriginOffsetFromHead`
  - `net.originMaxOffsetFromHead`
  - `net.muzzleMaxOffset`
  - `net.rofTolerance`
  - `net.losTolerance`
  - `net.allowFriendlyFire`
- Rutas FX/SFX:
  - `fx.muzzleEmittersPath`
  - `fx.impactEmittersPath`
  - `fx.beamTemplatePath`
  - `fx.tracer.*`
  - `sfx.shotPath`
  - `sfx.hitConfirmPath`
  - `sfx.killConfirmPath`

### Habilidades (`Config/Abilities/<AbilityId>.luau`)
- Cooldown: `cooldown`
- IDs de animacion local: `clientAnimId`
- Sincronizacion por marker:
  - `useMarker`
  - `launchMarkerName`
  - `fallbackLaunchDelay`
- Parametros de proyectil/explosion:
  - `projectile*`
  - `explosion*`
  - `friendlyFire`, `selfDamage`
- Rutas/nombres de FX/SFX de habilidad:
  - `fx.explosionEmittersFolderName`
  - `sfx.explosionSoundName`
  - `launchSoundName`, `flightLoopSoundName`

### Personajes (`Config/Characters/<CharacterId>.luau`)
- Nombre ID de personaje: `id`
- Arma por defecto: `weaponId`
- Binds de habilidades: `abilities = { { id = "...", key = "Q" } }`

## 3) Animaciones (recomendacion de arquitectura)

## Opcion recomendada
Usar IDs en config central (equivalente a la opcion B):
- habilidad define `clientAnimId` en `Config/Abilities`
- cliente (`AbilityController`) crea `Animation` y hace `LoadAnimation`/`Play`

Ventajas:
- no duplicar IDs en multiples scripts
- versionar cambios de gameplay junto con config
- escalar por personaje/habilidad sin tocar controller base

## Opcion no recomendada para este proyecto
Depender de `Animation` instances hardcodeadas por script o dispersas en UI/modelos sin ruta central.

## Estado actual
- Habilidades: ya usan `clientAnimId` desde config.
- Arma primaria: no tiene aun esquema formal de animacion de disparo en `WeaponConfig`.

## Donde cambiar una animacion existente
- Habilidad: editar `clientAnimId` en `Config/Abilities/<AbilityId>.luau`.
- Locomocion: hoy esta en `src/client/CharacterScripts/Animate.luau` (hardcodeado).

## Como agregar animacion para habilidad nueva
1. Crear/editar config en `Config/Abilities/<AbilityId>.luau`.
2. Definir `clientAnimId` y opcionalmente marker (`useMarker`, `launchMarkerName`).
3. Bindear habilidad en `Config/Characters/<CharacterId>.luau`.
4. Implementar ejecucion en `AbilityService` si es nueva logica.

## Como agregar animacion para arma (direccion recomendada)
1. Extender `Types.WeaponConfig` con bloque `anim` (ejemplo: `anim.fireId`, `anim.reloadId`).
2. Validar en `ConfigValidator`.
3. Consumir desde `CombatController`.
4. Mantener IDs solo en `Config/Weapons`.

## 4) Assets y rutas
El codigo espera assets en:
- `ReplicatedStorage.GW.Assets.FX`
- `ReplicatedStorage.GW.Assets.Sounds`
- `ReplicatedStorage.GW.Assets.Projectiles`

Nota actual:
- Esas carpetas no estan en `src/` del repo; se asumen en el place.
- Si se quiere versionar assets por Rojo, crear `src/shared/GW/Assets` y mapearlos.

## 5) Flags de red y seguridad
`CombatService` valida:
- cadencia (`rofTolerance`)
- offset de origen contra cuerpo/muzzle
- cono de direccion
- line-of-sight
- consistencia de recast

Regla:
- aumentar tolerancias solo lo necesario para corregir falsos rechazos.
- documentar en PR el motivo de cada cambio de tolerancia.

## 6) Checklist rapido para cambios de config
- Cambiaste `Config/*`: validar que el juego carga sin errores de registry.
- Cambiaste keys de `sfx` o `fx`: verificar consumidores (`FXController`, `SoundController`, `CombatUIController`).
- Cambiaste tolerancias `net.*`: probar disparo real, hits, misses y posibles rechazos.
- Cambiaste binds: confirmar input en cliente y cooldown en servidor.
