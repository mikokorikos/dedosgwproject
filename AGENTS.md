# AGENTS

## 1) Proyecto
- Tipo: shooter modular estilo Garden Warfare.
- Stack: Roblox + LuaU + Rojo.
- Arquitectura: separacion estricta `Client / Server / Shared`.
- Enfoque actual:
  - arma principal hitscan
  - habilidad `BackRocket`
  - validaciones server-side con feedback inmediato local

## 2) Reglas de trabajo
1. No mover archivos/carpeta sin motivo tecnico claro.
2. No romper separacion:
   - `src/client`: input, UI, FX/SFX, animacion local
   - `src/server`: autoridad de gameplay y validaciones
   - `src/shared`: config, tipos, registries, utilidades, net
3. No hardcodear valores repetidos en varios scripts.
4. Centralizar config en `src/shared/GW/Config`.
5. Preferir cambios minimos, compatibles y reversibles.
6. Primero identificar causa raiz; despues refactorizar.
7. Agregar logs antes de asumir causas.
8. Evitar require circular entre registries/services.
9. Evitar returns silenciosos en pipelines criticos; loguear razon antes de retornar.
10. Conservar compatibilidad cliente/servidor.

## 3) Convenciones

### Naming
- IDs de config estables y legibles: `SoldierRifle`, `BackRocket`, `Soldier`.
- Archivos de config por ID: `Config/<Domain>/<Id>.luau`.
- Scripts cliente: `*.client.luau`
- Scripts servidor: `*.server.luau`

### Config
- Armas: `Config/Weapons`
- Habilidades: `Config/Abilities`
- Personajes: `Config/Characters`
- Tipos y validaciones: `Shared/Types.luau` + `Shared/ConfigValidator.luau`

### Assets
- Runtime espera assets en `ReplicatedStorage.GW.Assets`.
- Si se agregan rutas nuevas de assets, reflejarlas en config (`fx.*`, `sfx.*`) y consumidores.

### Logging
- Usar `Logger.scoped("<System>")`.
- Formato esperado:
  - `[GW][Combat][Client] ...`
  - `[GW][Ability][Server] ...`
- Para debug temporal:
  - agregar logs `trace/info/warn/error` en puntos de decision
  - remover o bajar verbosidad al cerrar incidente

### Documentacion de features
- Si agregas/ajustas gameplay, actualizar:
  - `docs/PROJECT_STRUCTURE.md` (responsabilidades/rutas)
  - `docs/FLOWS.md` (pipeline runtime)
  - `docs/CONFIG_GUIDE.md` (nuevos campos de config)
  - `docs/TROUBLESHOOTING.md` (fallas conocidas)

## 4) Checklist por tipo de cambio

### Nueva arma
1. Crear `Config/Weapons/<WeaponId>.luau`.
2. Validar campos con `ConfigValidator`.
3. Asignar arma en `Config/Characters/<CharacterId>.luau`.
4. Verificar impacto en `CombatController` y `CombatService`.
5. Configurar rutas FX/SFX y assets reales.
6. Actualizar docs.

### Nueva habilidad
1. Crear `Config/Abilities/<AbilityId>.luau`.
2. Bindear en `Config/Characters/<CharacterId>.luau`.
3. Implementar ejecucion en `AbilityService` (o modulo dedicado).
4. Definir `clientAnimId` y timing (marker/fallback).
5. Verificar cooldown local + server.
6. Actualizar docs.

### Cambio de sonido/VFX
1. Ajustar ruta en config.
2. Confirmar consumidor (`FXController`/`SoundController`/`CombatUIController`).
3. Probar local y remoto.
4. Documentar origen espacial del sonido (muzzle/impact/explosion).

### Cambio de networking/validaciones
1. Documentar origen de datos (cliente vs servidor).
2. Mantener validaciones server-side.
3. Registrar razon exacta de rechazos.
4. Evitar abrir exploit al aumentar tolerancias.
5. Actualizar `docs/FLOWS.md` y `docs/CONFIG_GUIDE.md`.

## 5) Zonas sensibles
- `CombatService.server.luau`:
  - cadencia, origen/muzzle, LoS, recast, damage
  - no introducir bypass de validacion
- `CombatController.client.luau`:
  - estado local de ammo y sync
  - origen/direccion de disparo
- `AbilityService.server.luau`:
  - cooldown server y ejecucion autoritativa
- `Logger.luau`:
  - nunca debe romper carga de modulos

## 6) Stubs y deuda tecnica actual
- `ProjectileService.server.luau`: stub.
- `StatusService.server.luau`: stub.
- `Animate.luau`: IDs hardcodeados (deuda para migrar a config central).
- `CombatUIController`: inconsistencia de keys de sonido vs `WeaponConfig`.

Cuando se toque una deuda:
1. Documentar estado previo.
2. Hacer cambio incremental.
3. Verificar compatibilidad y actualizar docs.
