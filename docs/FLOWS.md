# Runtime Flows

## 1) Flujo de disparo (arma principal, click)

### Cliente (`CombatController`)
1. `InputBegan` detecta `MouseButton1`.
2. Guards de input:
   - `gameProcessed`
   - `isTyping` (`TextBox` activo)
3. Resuelve `weaponId` desde atributo de jugador.
4. Verifica estado local de ammo:
   - `initialized`
   - `reloading`
   - `mag > 0`
5. Calcula:
   - `cameraOrigin` y direccion de camara
   - `aimPoint` por raycast al centro de pantalla
   - `shotOrigin` en muzzle (fallback si no existe)
   - `shotDirection` desde muzzle hacia `aimPoint` + spread
6. Hace raycast local para feedback inmediato.
7. Emite disparo local por `LocalEffectsBus` (FX/SFX instantaneos).
8. Envia `CombatRequest` (`action = "Shoot"`).
9. Envia `ReportHit` solo si hubo hit local.

### Servidor (`CombatService`)
1. Recibe `CombatRequest`.
2. Valida estado jugador vivo + ammo + reload.
3. Valida disparo (`validateClaimedHit`):
   - cadencia
   - origen valido
   - distancia origen/muzzle (`origin_muzzle_offset`)
   - direccion valida
   - cono/LoS/recast
4. Si pasa:
   - marca `shotId` aceptado
   - consume ammo
   - raycast autoritativo
   - aplica dano (hitscan)
   - replica shot FX a clientes
5. Si falla:
   - registra rechazo y razon
   - replica shot rechazado para consistencia visual

### `ReportHit` (servidor)
1. Requiere `shotId` aceptado previamente por `Shoot`.
2. Evita doble procesamiento por `shotId`.
3. Revalida hit sin aplicar validacion de cadencia duplicada.
4. Aplica dano/hit-confirm si corresponde.

## 2) Flujo de habilidad Q (`BackRocket`)

### Cliente (`AbilityController`)
1. Detecta `Q`.
2. Aplica guards (`gameProcessed`, `isTyping`).
3. Resuelve `CharacterId` y binds desde `CharacterRegistry`.
4. Resuelve `abilityId` y config desde `AbilityRegistry`.
5. Aplica cooldown local.
6. Reproduce animacion local (`clientAnimId`):
   - obtiene `Humanoid`/`Animator`
   - `LoadAnimation` + `Play`
   - dispara request por marker o fallback delay
7. Envia `AbilityRequest` al servidor.

### Servidor (`AbilityService`)
1. Recibe `AbilityRequest`.
2. Valida payload + `abilityId`.
3. Valida estado vivo y cooldown server-side.
4. Ejecuta logica (actualmente solo `BackRocket`):
   - oculta/regrow visual de cohete en personaje
   - instancia proyectil
   - simula vuelo por `Heartbeat`
   - al impacto/fin de vida, explota y aplica dano AoE
5. Emite `FXEvent` de explosion.

## 3) Flujo de inicializacion y sync de ammo

### Bootstrap
- Cliente:
  - al `CharacterAdded` y al cambiar `WeaponId` resetea estado local de ammo a `initialized=false`
  - solicita sync (`DryTrigger`) con razon
- Servidor:
  - `CharacterAdded` / `WeaponId` changed / `DryTrigger`
  - envia `FXEvent` tipo `Ammo` con estado autoritativo

### Sync event (`FXEvent.type == "Ammo"`)
- Cliente actualiza:
  - `initialized = true`
  - `mag`
  - `reserve`
  - `reloading`
  - `reloadEnd`

## 4) Flujo de VFX/SFX

### Disparo
- Inmediato local:
  - `CombatController` -> `LocalEffectsBus`
  - `FXController` render shot local
  - `SoundController` reproduce shot 3D desde `startPos/muzzlePos`
- Replicado:
  - servidor envia `ReplicateShot`
  - clientes remotos renderizan FX/SFX

### Explosion de habilidad
- Servidor envia `FXEvent` tipo `Explosion`.
- `FXController` renderiza emitters y sonido 3D de explosion.

## 5) Networking resumido
- `CombatRequest`: `Shoot`, `Reload`, `DryTrigger`
- `ReportHit`: reclamo de impacto (con `shotId`)
- `ReplicateShot`: replay visual/sonoro de disparo para otros clientes
- `AbilityRequest`: activacion de habilidades
- `FXEvent`: bus multiproposito (ammo, shot, hit confirm, killfeed, explosion, reload)

## 6) Seguridad y sensacion de juego
- Sensacion instantanea: prediccion local de disparo y animacion de habilidad.
- Seguridad: dano y validaciones criticas siguen en servidor.
- Regla de extension:
  - no sacrificar validaciones server-side por ocultar lag.
  - no mover dano al cliente.
