# Project Structure

## 1) Vision general
Este proyecto implementa una base modular de shooter tipo Garden Warfare en LuaU:
- combate principal con arma hitscan (`click`)
- habilidad de personaje (`Q`)
- validaciones de servidor para seguridad
- feedback inmediato en cliente (FX/SFX y sensacion de respuesta)

Arquitectura actual:
- `Shared`: tipos, registries, networking, utilidades y validaciones de config.
- `Server`: servicios autoritativos de combate, habilidades y estado global.
- `Client`: controladores de input, UI, FX/SFX y animaciones locales.

## 2) Mapeo Rojo -> Roblox
Definido en `default.project.json`:
- `src/shared/GW` -> `ReplicatedStorage.GW`
- `src/server` -> `ServerScriptService`
- `src/client/PlayerScripts` -> `StarterPlayer.StarterPlayerScripts`
- `src/client/CharacterScripts` -> `StarterPlayer.StarterCharacterScripts`

Remotes creados por Rojo en `ReplicatedStorage.GW.Remotes`:
- `CombatRequest`
- `ReportHit`
- `ReplicateShot`
- `AbilityRequest`
- `FXEvent`

## 3) Estructura de carpetas (repo)
```text
src/
  client/
    CharacterScripts/
      Animate.luau
    PlayerScripts/GW/
      AbilityController.client.luau
      CombatController.client.luau
      CombatUIController.client.luau
      FXController.client.luau
      LocalEffectsBus.luau
      SoundController.client.luau
  server/GW/
    AbilityService.server.luau
    CharacterService.server.luau
    CombatService.server.luau
    ProjectileService.server.luau   (stub)
    StatusService.server.luau       (stub)
  shared/GW/
    Config/
      Abilities/BackRocket.luau
      Characters/Soldier.luau
      Weapons/SoldierRifle.luau
    Shared/
      AbilityRegistry.luau
      AssetResolver.luau
      CharacterRegistry.luau
      ConfigValidator.luau
      DamageUtil.luau
      Logger.luau
      Net.luau
      RaycastUtil.luau
      RegistryLinker.luau
      Types.luau
      WeaponRegistry.luau
```

## 4) Responsabilidad de archivos clave

### Cliente (`src/client/PlayerScripts/GW`)
- `AbilityController.client.luau`
  - Detecta input de habilidades (actualmente binds desde `CharacterRegistry`).
  - Aplica cooldown local.
  - Reproduce animacion local de habilidad usando `clientAnimId` desde config.
  - Envia `AbilityRequest` al servidor.

- `CombatController.client.luau`
  - Detecta `MouseButton1` y `R`.
  - Lleva estado local de ammo (`initialized`, `mag`, `reserve`, `reloading`).
  - Construye disparo con origen en muzzle y direccion hacia el punto de mira.
  - Predice disparo local (raycast cliente + efectos locales).
  - Envia `CombatRequest` (`Shoot`, `Reload`, `DryTrigger`) y `ReportHit`.

- `FXController.client.luau`
  - Renderiza muzzle flash, tracer e impactos.
  - Renderiza explosiones (`FXEvent` tipo `Explosion`).
  - Consume disparos locales (bus) y remotos (`ReplicateShot`).

- `SoundController.client.luau`
  - Reproduce audio de disparo en 3D.
  - Usa `startPos/muzzlePos/origin` como fuente espacial.
  - Evita duplicado para el tirador local en eventos remotos.

- `CombatUIController.client.luau`
  - Muestra hitmarker y killfeed con `FXEvent`.
  - Reproduce audio de hit/kill confirm.
  - Nota: hoy existe inconsistencia de nombres (`hitConfirmTemplate`/`killConfirmTemplate` vs `hitConfirmPath`/`killConfirmPath` en config).

- `LocalEffectsBus.luau`
  - `BindableEvent` local para desacoplar emision de disparo (controller -> FX/SFX).

### Cliente personaje (`src/client/CharacterScripts`)
- `Animate.luau`
  - Controlador de locomocion/estado con tracks custom.
  - Config de animaciones hardcodeada en el propio script.
  - Recomendacion: migrar IDs a config compartida para no duplicar valores.

### Servidor (`src/server/GW`)
- `CharacterService.server.luau`
  - Aplica `CharacterId` y `WeaponId` por defecto en spawn.
  - Envia evento `FXEvent` tipo `Init` (actualmente no hay consumidor directo de `Init` en cliente).

- `CombatService.server.luau`
  - Autoridad de disparo, ammo, reload y dano hitscan.
  - Handshake/sync de ammo con cliente.
  - Validaciones de cadencia, origen, direccion, cono, LoS y recast.
  - Replicacion de FX (`FXEvent` + `ReplicateShot`).
  - Pipeline de `ReportHit` separado con guardas anti-duplicado.

- `AbilityService.server.luau`
  - Autoridad para activacion de habilidades.
  - Hoy implementa solo `BackRocket`.
  - Ejecuta cooldown server-side, proyectil y explosion AoE.
  - No reproduce animacion server-side por diseno (se prioriza respuesta local).

- `ProjectileService.server.luau`
  - Stub (pendiente sistema generico de proyectiles).

- `StatusService.server.luau`
  - Stub (pendiente estados: burn/slow/shock, etc).

### Shared (`src/shared/GW/Shared`)
- `AbilityRegistry.luau`
  - Carga modulos de `Config/Abilities`.
  - Ignora no-`ModuleScript`.
  - Valida shape y unicidad de IDs.

- `CharacterRegistry.luau`
  - Carga `Config/Characters`.
  - Valida referencias cruzadas con ability/weapon registries.
  - Expone `AbilityToCharacterIds`.

- `WeaponRegistry.luau`
  - Carga `Config/Weapons`.
  - Valida shape y unicidad de IDs.

- `ConfigValidator.luau`
  - Validaciones estructurales y de rangos para Weapon/Ability/Character.

- `RegistryLinker.luau`
  - Construye indices derivados entre registries (actualmente `abilityToCharacterIds`).

- `Types.luau`
  - Tipos de config (weapon/character/ability).

- `Net.luau`
  - Acceso tipado a remotes compartidos.

- `Logger.luau`
  - Logger nil-safe con niveles (`TRACE/INFO/WARN/ERROR`), scope y lado (`Client/Server`).
  - No debe romper runtime aunque reciba argumentos invalidos.

- `RaycastUtil.luau`
  - Hitscan y deteccion de humanoid desde impacto.

- `DamageUtil.luau`
  - Friendly-fire y falloff de dano.

- `AssetResolver.luau`
  - Resolucion de rutas de assets estilo `"Weapons/SoldierRifle/..."`.

## 5) Donde va cada cosa
- Habilidad nueva:
  - Config: `src/shared/GW/Config/Abilities/<AbilityId>.luau`
  - Bind a personaje: `src/shared/GW/Config/Characters/<CharacterId>.luau`
  - Ejecucion servidor: `src/server/GW/AbilityService.server.luau` (o modulo dedicado en futuro)
  - Input/anim local: `src/client/PlayerScripts/GW/AbilityController.client.luau`

- Arma nueva:
  - Config: `src/shared/GW/Config/Weapons/<WeaponId>.luau`
  - Asignacion a personaje: `Config/Characters/...`
  - Pipeline principal: `CombatController` + `CombatService`
  - FX/SFX: rutas en config (`fx.*`, `sfx.*`) consumidas por `FXController`/`SoundController`

- Config de personajes:
  - `src/shared/GW/Config/Characters`

- Animaciones:
  - Habilidades: `clientAnimId` en `Config/Abilities/*`
  - Armas: hoy no hay esquema formal en `WeaponConfig`; si se agrega, debe quedar en config central, no hardcodeado en controllers.

- Sonidos:
  - Rutas en config (`sfx.*`) y assets reales en `ReplicatedStorage.GW.Assets.Sounds`.

- VFX:
  - Rutas en config (`fx.*`) y assets reales en `ReplicatedStorage.GW.Assets.FX`.

- Networking/remotes:
  - Declaracion en `default.project.json`
  - Consumo tipado en `src/shared/GW/Shared/Net.luau`

- Logica shared:
  - `src/shared/GW/Shared`

- Logica solo cliente:
  - `src/client/PlayerScripts/GW` y `src/client/CharacterScripts`

- Logica solo servidor:
  - `src/server/GW`

- Utilidades generales:
  - `Shared/*Util*.luau`, `Logger.luau`, `AssetResolver.luau`

- Debug temporal:
  - Preferir logger con scope y `TRACE` en archivos existentes.
  - Evitar crear scripts sueltos permanentes; si se crean, documentar y remover al cerrar incidente.

- Stubs:
  - `ProjectileService` y `StatusService` estan marcados como stub.
  - Reemplazo futuro: migrar comportamiento desde `CombatService/AbilityService` hacia servicios dedicados.

## 6) Estado actual y notas de mantenimiento
- Sistema de combate y habilidad operativos para `Soldier + SoldierRifle + BackRocket`.
- El repo no incluye carpetas de assets (`GW.Assets`) en `src`; se asume que existen en el place y se preservan por `$ignoreUnknownInstances`.
- `CombatUIController` usa claves de sonido distintas a las del `WeaponConfig` actual (inconsistencia conocida).
- `CharacterService` emite `FXEvent` tipo `Init`, actualmente sin consumidor explicito en cliente.
- Hay dos pipelines de dano para disparo (`processShoot` y `ReportHit`); hoy coexisten con guardas por `shotId`.
