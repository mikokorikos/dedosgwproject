# Remotes And Events

Contrato actual de networking y buses de eventos del proyecto.

## 1) Remotes declarados
Archivo fuente: `src/shared/GW/Shared/Net.luau`

- `CombatRequest` (`RemoteEvent`)
- `ReportHit` (`RemoteEvent`)
- `ReplicateShot` (`RemoteEvent`)
- `AbilityRequest` (`RemoteEvent`)
- `PlantableRequest` (`RemoteEvent`)
- `PlantableEvent` (`RemoteEvent`)
- `FXEvent` (`RemoteEvent`)

## 2) `CombatRequest`

### Emisor
- Cliente (`CombatController.client.luau`)

### Receptor
- Servidor (`CombatService.server.luau`)

### Acciones (`payload.action`)
- `Shoot`
- `Reload`
- `DryTrigger`

### Payload de `Shoot` (campos usados)
- `action: "Shoot"`
- `weaponId: string?`
- `shotId: string`
- `clientShotTime: number`
- `origin: Vector3`
- `direction: Vector3`
- `claimedHitPart: string?`
- `claimedHitPosition: Vector3?`
- `muzzlePos: Vector3?`
- `cameraOrigin: Vector3?`
- `aimPoint: Vector3?`

### Payload de `Reload`
- `action: "Reload"`
- `weaponId: string?`

### Payload de `DryTrigger`
- `action: "DryTrigger"`
- `weaponId: string?`
- `reason: string?`

### Validaciones server-side
- payload table
- player alive
- cadence/reload/ammo
- plausibilidad origen/direccion/hit claim
- friendly fire / target validity

## 3) `ReportHit`

### Emisor
- Cliente (`CombatController`), solo cuando cast local detecta hit.

### Receptor
- Servidor (`CombatService`)

### Payload real
- `shotSeq: number`
- `shotId: string`
- `clientShotTime: number`
- `weaponId: string`
- `origin: Vector3`
- `dir: Vector3`
- `hitInstance: Instance`
- `hitPos: Vector3`
- `hitNormal: Vector3`
- `cameraOrigin: Vector3?`
- `aimPoint: Vector3?`

### Reglas
- Debe existir `shotId` previamente aceptado en `Shoot`.
- Se rechaza si no hay accepted shoot (`report_without_shoot`).

## 4) `ReplicateShot`

### Emisor
- Servidor (`CombatService`)

### Receptores
- Clientes (`FXController`, `SoundController`)

### Proposito
- Replicar visual/audio de disparo a otros clientes.

### Payload tipico
- `shooterUserId: number`
- `weaponId: string`
- `startPos: Vector3`
- `hitPos: Vector3`
- `hitNormal: Vector3?`
- `didHit: boolean`
- `rejected: boolean?`

## 5) `AbilityRequest`

### Emisor
- Cliente (`AbilityController`)

### Receptor
- Servidor (`AbilityService`)

### Payload real
- `abilityId: string`
- `direction: Vector3`

### Validaciones
- payload table
- `abilityId` valido
- player alive
- cooldown server-side

## 6) `PlantableRequest`

### Emisor
- Cliente (`PlantableController`)

### Receptor
- Servidor (`PlantableService`)

### Acciones
- `Place`
- `Preview`

### Payload de `Place`
- `action: "Place"`
- `plantableId: string?`
- `spotId: string?`
- `position: Vector3?`
- `normal: Vector3?`

### Payload de `Preview`
- `action: "Preview"`
- campos opcionales de spot/position

## 7) `PlantableEvent`

### Emisor
- Servidor (`PlantableService`)

### Receptor
- Cliente (`PlantableController`)

### Tipos
- `Placed`
- `Rejected`
- `PreviewAck`

### Payload `Placed`
- `type: "Placed"`
- `plantableId: string`
- `deployableId: string`
- `spotId: string?`

### Payload `Rejected`
- `type: "Rejected"`
- `reason: string`
- `plantableId: string?`
- `spotId: string?`

### Payload `PreviewAck`
- `type: "PreviewAck"`

## 8) `FXEvent`

Bus multiproposito para UI/FX/SFX.

### Emisores
- `CombatService`
- `AbilityService`
- `DeployableService`
- `CharacterService` (Init)

### Receptores
- `CombatController`
- `CombatUIController`
- `FXController`
- `SoundController`

### Tipos usados actualmente
- `Init`
- `Ammo`
- `DryFire`
- `ReloadStart`
- `ReloadEnd`
- `Shot`
- `HitConfirm`
- `KillFeed`
- `Explosion`
- `DeployableFX`
- `SoundCue`

## 9) Contrato de `SoundCue`

### Emisor
- Principalmente `DeployableService`

### Receptor
- `SoundController`

### Payload
- `type: "SoundCue"`
- `soundPath: string` (ruta relativa dentro de `Assets/Sounds`)
- `mode: "2D" | "3D"`
- `position: Vector3?` (requerido para 3D)
- `volume: number?`
- `context: string?`

### Uso actual
- Kill bell owner-only
- Cues 3D/2D reutilizables sin hardcodear en multiples scripts

## 10) Eventos locales (no RemoteEvent)

### `LocalEffectsBus`
Archivo: `src/client/PlayerScripts/GW/LocalEffectsBus.luau`

API:
- `EmitShot(ev)`
- `OnShot(callback)`

Uso:
- `CombatController` publica shot local instantaneo.
- `FXController` y `SoundController` consumen para respuesta inmediata.

## 11) Reglas de evolucion
- Si agregas un nuevo `RemoteEvent`, actualiza:
  - `default.project.json`
  - `Net.luau`
  - este documento (`REMOTES_AND_EVENTS.md`)
- Si agregas nuevos `ev.type` en `FXEvent` o `PlantableEvent`, documenta payload minimo y consumidores.
- Mantener validaciones server-side para toda entrada de cliente.
