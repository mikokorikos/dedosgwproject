# Teams And Summons

Estado consolidado del sistema de equipos/facciones y entidades invocadas.

## 1) Fuente de verdad
- `src/shared/GW/Shared/EntityRelations.luau`
- `src/shared/GW/Shared/DamageUtil.luau` (facade gameplay)

## 2) Atributos canonicos usados
- `FactionId`
- `TeamId`
- `OwnerUserId`
- `SummonerUserId`

Aliases leidos por resolver:
- `GWFactionId`, `GWTeamId`, `GWOwnerUserId`, `GWSummonerUserId`
- `GWPlantSpotFactionId` (spots)

## 3) Como se asignan hoy
- `CharacterService`: player + character reciben `FactionId/TeamId`.
- `DeployableService`: deployables reciben owner/summoner/faccion via `tagSummonModel`.
- `PlantableService`: spawn por spot usa `DeployableService` (hereda la misma capa).
- `WorldFactionService`: `Workspace.Rig` no-player se marca como `Plants`.

## 4) Como se determina aliado/enemigo
`EntityRelations.areAllies(a, b)` evalua, en orden:
1. Team object de player (si ambos son players con Team).
2. `FactionId`.
3. `TeamId`.
4. `OwnerUserId`.
5. `SummonerUserId`.
6. owner-player cross checks.

Si no cumple aliados, se considera enemigo (`areEnemies`).

## 5) Reglas de gameplay derivadas
- Dano: `DamageUtil.canDamage(attacker, target, allowFriendlyFire)`
- Targeting: `DamageUtil.canTarget(...)`
- Curacion: `DamageUtil.canHeal(source, target, allowCrossTeam)`

Regla de proyecto:
- No duplicar comparaciones de faccion en servicios.

## 6) Integracion real en pipelines
- `CombatService` bloquea friendly targets cuando `allowFriendlyFire=false`.
- `AbilityService` usa `DamageUtil` en explosions de habilidad.
- `DeployableService.applyExplosionAt` filtra aliados y owner por flags.
- `TargetingUtil` siempre filtra via `DamageUtil.canTarget`.

## 7) Conceptos utiles
- `FactionId`: alineacion gameplay principal.
- `TeamId`: id operativo de equipo (hoy normalmente igual a `FactionId`).
- `OwnerUserId`: duenio de la entidad.
- `SummonerUserId`: invocador (puede divergir en futuras mecanicas).

## 8) Estado actual y limites
Funcional:
- player vs player
- player vs world rig
- player vs deployable
- deployable vs player/deployable con reglas de equipo

Pendiente:
- collision groups por faccion
- reglas avanzadas de neutralidad configurable por dominio
