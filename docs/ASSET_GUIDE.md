# Asset Guide

Guia de rutas y tipos de instancia esperados en `ReplicatedStorage.GW.Assets`.

Importante:
- `Assets` no esta versionado en `src`; debe existir en Studio/place.
- Cuando falta un asset, muchos sistemas degradan con warning.
- Algunos contratos son estrictos (deployable humanoid requiere modelo valido).

## 1) Estructura base esperada
```text
ReplicatedStorage/
  GW/
    Assets/
      Deployables/
      FX/
      Sounds/
      Projectiles/
```

## 2) Weapons assets

### FX (arma)
Rutas tipicas (desde config):
- `FX/Weapons/<WeaponId>/MuzzleEmitters`
- `FX/Weapons/<WeaponId>/ImpactEmitters`
- `FX/Weapons/<WeaponId>/TracerBeamTemplate`

Tipos esperados:
- `MuzzleEmitters`: `Folder` con `ParticleEmitter` hijos/descendientes.
- `ImpactEmitters`: `Folder` con `ParticleEmitter`.
- `TracerBeamTemplate`: `Beam`.

### Sounds (arma)
Rutas tipicas:
- `Sounds/Weapons/<WeaponId>/ShotSoundTemplate`
- `Sounds/Weapons/<WeaponId>/HitConfirmSoundTemplate`
- `Sounds/Weapons/<WeaponId>/KillConfirmSoundTemplate`

Tipos esperados:
- `Sound` (template clonable).

## 3) Ability BackRocket assets

### Projectiles
Ruta:
- `Projectiles/<projectileTemplateName>` (ej. `BackRocketProjectile`)

Tipo esperado:
- `Model` (recomendado) con `PrimaryPart` o al menos un `BasePart`.

Campos relevantes del model:
- `projectileBodyName` (si existe ese part)
- attachment opcional `projectileFlightAttachmentName`

### Sounds
Nombres buscados en `Assets/Sounds`:
- `launchSoundName`
- `flightLoopSoundName`
- `sfx.explosionSoundName` (ability)

## 4) Deployable humanoid assets

### Modelo deployable
Ruta esperada:
- `Deployables/<ModelAssetName>`
- ejemplo: `Deployables/PlantZombieExploderModel`

Tipo obligatorio:
- `Model`

Contenido obligatorio:
- `Humanoid`
- `HumanoidRootPart` (`BasePart`)

Opcional recomendado:
- `PrimaryPart` apuntando al root.

Si falta `Humanoid` o `HumanoidRootPart`:
- `DeployableService.spawn` rechaza spawn con warning.

## 5) FX deployable legendario

Rutas esperadas (por config actual):
- `FX/Deployables/PlantZombieExploder/Arming`
- `FX/Deployables/PlantZombieExploder/Explosion`
- `FX/Deployables/PlantZombieExploder/ChainExplosion`

Tipos esperados:
- `Folder` con `ParticleEmitter` descendientes.

## 6) Sounds deployable legendario

Rutas esperadas (por config actual):
- `Sounds/Deployables/PlantZombieExploder/Deploy`
- `Sounds/Deployables/PlantZombieExploder/Arming`
- `Sounds/Deployables/PlantZombieExploder/Explosion`
- `Sounds/Combat/KillBell`

Notas:
- `ChainExplosionSoundName` hoy reusa `Deployables/PlantZombieExploder/Explosion`.
- `SoundCue` usa `soundPath` relativo a `Assets/Sounds`.

Tipo esperado:
- `Sound`.

## 7) Animation assets

Contrato principal actual:
- Los IDs viven en `Config/AnimationProfiles` como `animationId` string.
- No se referencian instancias `Animation` en assets como contrato primario.

Formato valido de `animationId`:
- `rbxassetid://<numero>`
- `<numero>`

## 8) AssetResolver behavior

`AssetResolver.resolve(root, path)`:
- acepta path relativo con `/`.
- tambien puede resolver nombre directo.

Ejemplos:
- `AssetResolver.resolve(SoundsRoot, "Combat/KillBell")`
- `AssetResolver.resolve(FXRoot, "Deployables/PlantZombieExploder/Explosion")`

## 9) Buenas practicas de assets
1. Mantener jerarquia por dominio (`Weapons`, `Deployables`, `Combat`, etc.).
2. Evitar nombres ambiguos repetidos.
3. Asegurar `SoundId` valido (`!= rbxassetid://0`).
4. Para FX, agrupar emitters en `Folder`.
5. Para deployables humanoid, validar root/humanoid antes de probar gameplay.

## 10) Checklist rapido al agregar assets nuevos
1. Crear ruta exacta esperada por config.
2. Verificar tipo de instancia correcto.
3. Verificar que config apunta a esa ruta.
4. Correr en juego y revisar logs:
   - warnings de missing template/path
   - `SoundCue` context
   - `Deployable FX folder missing`
5. Confirmar que gameplay sigue aunque falte un asset no critico.
