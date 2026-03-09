# Troubleshooting

## 1) El arma no dispara
Sintomas:
- click detectado pero no hay disparo ni FX

Revisar:
1. `CombatController` logs de input:
   - `MouseButton1 detected`
   - `gameProcessed`
   - `isTyping`
2. Estado de arma:
   - `weapon equipped = true`
   - `weaponId resolved`
3. Estado ammo:
   - `initialized`
   - `mag`
   - `reloading`
4. Request:
   - `Shoot request sent to server`
5. Servidor:
   - `Shoot request received`
   - `Shoot rejected by validation reason=...`

## 2) Ammo no inicializa (`initialized=false`)
Sintomas:
- bloqueos con `Shoot blocked: local ammo state not initialized`

Revisar:
1. Cliente envia `DryTrigger`.
2. Servidor recibe `DryTrigger` y hace `forceAmmoSync`.
3. Cliente recibe `FXEvent` tipo `Ammo` con `weaponId` correcto.
4. No exista mismatch de `weaponId` al procesar el sync.

## 3) Animacion de habilidad no se reproduce
Sintomas:
- habilidad funciona en gameplay pero sin animacion local

Revisar:
1. `clientAnimId` en `Config/Abilities`.
2. `AbilityController`:
   - `Animator resolved`
   - `LoadAnimation succeeded`
   - `Track Play() succeeded`
3. Si falla, revisar formato de ID:
   - numerico o `rbxassetid://<id>`
4. Confirmar que la animacion corresponda al rig actual.

## 4) Sonido de disparo sale del lugar incorrecto
Sintomas:
- sonido desde proyectil, impacto o centro de camara

Revisar:
1. `SoundController`:
   - `Shot sound source position = ...`
   - `Shot sound parent = ...`
2. Evento de disparo tenga `startPos`/`muzzlePos`.
3. `CombatController` y `CombatService` envien start/muzzle correctos.

## 5) Disparo sale del centro de pantalla y no del muzzle
Sintomas:
- tracer visual inicia en centro de pantalla
- rechazos `origin_muzzle_offset`

Revisar:
1. `CombatController`:
   - `Muzzle found ...`
   - `Muzzle world position = ...`
   - `Shot origin final = ...`
2. `CombatService`:
   - `Muzzle found on server ...`
   - `Origin vs muzzle distance validated -> ...`
3. Config de arma:
   - `mount.gunModelName`
   - `mount.muzzleAttachmentName`

## 6) Rechazo `origin_muzzle_offset`
Causas comunes:
- cliente construye origen desde camara
- nombre de muzzle no coincide entre config y modelo
- attachment no existe en el rig/modelo equipado
- tolerancia de red demasiado estricta

Acciones:
1. Verificar muzzle en cliente y servidor.
2. Confirmar que `origin` enviado sea muzzle-based.
3. Ajustar `net.muzzleMaxOffset` solo si hay falso positivo medido.

## 7) `ReportHit validation failed reason=cadence_rpm`
Causa tipica:
- validacion de cadencia aplicada dos veces (Shoot + ReportHit).

Estado actual:
- `ReportHit` usa validacion sin enforcement de cadencia.
- ademas exige `shotId` previamente aceptado en `Shoot`.

Si reaparece:
1. Verificar que `shotId` se genere y propague.
2. Verificar TTL de `acceptedShots`.

## 8) Cooldowns desincronizados
Sintomas:
- cliente deja usar habilidad/disparo pero servidor rechaza.

Revisar:
1. cooldown local (cliente) vs cooldown server-side.
2. reloj `os.clock()` y ramas de retorno temprano.
3. logs `cooldown blocked` en ambos lados.

## 9) Registry mal cargado o require circular
Sintomas:
- `Module code did not return exactly one value`
- `Requested module experienced an error while loading`

Revisar:
1. Cada modulo de `Config/*` debe retornar exactamente una tabla.
2. No retornar multiples valores.
3. No meter `require` circular entre registries/configs.
4. Registries ya ignoran no-`ModuleScript`; confirmar hijos invalidos.

## 10) Modulo no retorna correctamente
Checklist:
1. El archivo termina con `return config` (o `return { ... }`).
2. No hay errores antes del return.
3. `pcall(require, mod)` del registry muestra modulo exacto que fallo.

## 11) Logging rompe runtime
Sintomas:
- errores dentro de `Logger.emit`

Estado actual:
- `Logger` es nil-safe y protegido con `pcall`.

Si falla:
1. Verificar que wrappers `trace/info/warn/error` mantengan varargs correctos.
2. No concatenar valores directos fuera de `tostring`.
3. Mantener `Logger` sin dependencias externas.
