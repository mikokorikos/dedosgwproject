# Extending The Game

Recetas practicas para extender el proyecto sin romper arquitectura.

## 1) Agregar un character nuevo
1. Crear `src/shared/GW/Config/Characters/<CharacterId>.luau`.
2. Definir:
   - `weaponId`
   - `animationProfileId`
   - `abilities` (con `animationActionKey` cuando convenga)
   - `plantables` (si aplica)
3. Crear profile en `Config/AnimationProfiles`.
4. Verificar referencias en `ConfigValidator` (sin ids desconocidos).

Prueba minima:
- spawn player con `CharacterId` nuevo y validar que carga arma, binds y profile.

## 2) Agregar un arma nueva
1. Crear `Config/Weapons/<WeaponId>.luau`.
2. Definir `fire`, `ammo`, `hitscan`, `mount`, `net`, `fx`, `sfx`.
3. Asignar `weaponId` en character.
4. Subir assets de arma a `Assets/FX` y `Assets/Sounds`.

Prueba minima:
- disparo, recarga, hitconfirm y killfeed con arma nueva.

## 3) Agregar una habilidad nueva
1. Crear `Config/Abilities/<AbilityId>.luau`.
2. Bindear en `Characters.<character>.abilities`.
3. Definir `animationActionKey` en slot de character.
4. Agregar action en profile del character.
5. Implementar branch gameplay en `AbilityService` (si no existe ya).

Regla:
- no poner `AnimationId` en ability config.

## 4) Agregar o cambiar animation profile
1. Crear/editar `Config/AnimationProfiles/<ProfileId>.luau`.
2. Mantener keys consistentes (`Shoot`, `Reload`, `BackRocket`, etc.).
3. Validar `animationId` formato correcto.
4. Asignar profile en character o deployable.

### Cambiar animacion de una habilidad sin tocar la ability
- Cambia `actions.<ActionKey>.animationId` en profile.
- Si necesitas timing, ajusta `triggerMode` y `triggerDelay`.

## 5) Agregar deployable nuevo (summon o plantable)

### A) Config
1. Crear `Config/Deployables/<DeployableId>.luau`.
2. Definir `kind`, `animationProfileId`, `ModelAssetName` y tunables.

### B) Runtime
3. Crear runtime en `src/server/GW/DeployableRuntimes/<Runtime>.luau` si es nuevo comportamiento.
4. Enlazar `kind` en `DeployableService.runPrototype`.
5. Reusar `TargetingUtil`, `DamageUtil`, `EntityRelations`.

### C) Entry point
- Summon por ability: ability con `deployableId`.
- Plantable por spot: config en `Config/Plantables`.

## 6) Agregar plantable por spot
1. Crear `Config/Plantables/<PlantableId>.luau`.
2. Setear `deployableId`, `spotType`, `cooldown`, `maxActive`, `placeRange`.
3. Bindear en `Characters.<id>.plantables`.
4. Verificar spots en mapa con attrs/tag de `PlantSpotUtil`.

Prueba minima:
- `Placed` y `Rejected` con razones esperadas.

## 7) Agregar NPC humanoid autonomo
1. Crear deployable/NPC config en `Config/Deployables`.
2. Asignar `animationProfileId`.
3. Proveer modelo humanoid valido en assets.
4. Implementar comportamiento como runtime que use `AutonomousEntityService`.
5. Mantener adquisicion de target en `TargetingUtil`.
6. Mantener dano/target checks en `DamageUtil`.

## 8) Agregar FX/SFX

### FX
- Ruta en `Assets/FX/...`.
- Usar `Folder` con `ParticleEmitter` descendientes.

### SFX
- Ruta en `Assets/Sounds/...`.
- Instancia `Sound` con `SoundId` valido.

### Integracion
- Configurar path en weapon/deployable/ability segun dominio.
- Para cues reutilizables server->cliente, usar `FXEvent type="SoundCue"`.

## 9) Agregar/editar reglas de equipo-faccion
1. Modificar logica central en `EntityRelations`.
2. Consumir desde `DamageUtil`.
3. No duplicar comparaciones en servicios.
4. Probar:
   - disparo
   - habilidad
   - deployable
   - plantable

## 10) Agregar un remote nuevo (solo si es necesario)
1. Declararlo en `default.project.json` dentro de `ReplicatedStorage.GW.Remotes`.
2. Exponerlo en `Net.luau`.
3. Implementar listener server/client segun corresponda.
4. Documentar contrato en `REMOTES_AND_EVENTS.md`.

## 11) Como agregar logs temporales sin ensuciar
1. Usar `Logger.scoped("<System>")`.
2. Loguear solo decisiones/rechazos/puntos de estado.
3. Prefijar razones concretas (`reason=...`).
4. Retirar o bajar nivel cuando cierre depuracion.

## 12) Checklist de entrega al terminar un cambio
1. Config valida (sin errores de registry/validator).
2. Sin hardcode duplicado.
3. Sin romper `Client / Server / Shared`.
4. Remotes/eventos documentados si cambiaron.
5. Docs actualizados al menos en:
   - `CONFIG_GUIDE.md`
   - `FLOWS.md`
   - `SYSTEMS.md`
   - `TROUBLESHOOTING.md` (si aplica)
