# GW Project

Shooter modular estilo Garden Warfare en Roblox/LuaU con separacion estricta `Client / Server / Shared`.

Estado actual del proyecto:
- Combate hitscan autoritativo (server-side validation + client feel inmediato).
- Habilidades de personaje por binds configurables.
- Sistema de animaciones character-driven por `AnimationProfiles`.
- Deployables humanoid con runtime autonomo modular.
- Plantables por spot en pipeline separado de abilities.
- Reglas de faccion/equipo centralizadas en `EntityRelations` + `DamageUtil`.

## Documentacion (manual interno)
- [Overview](docs/OVERVIEW.md)
- [Project Structure](docs/PROJECT_STRUCTURE.md)
- [Systems](docs/SYSTEMS.md)
- [Flows](docs/FLOWS.md)
- [Remotes And Events](docs/REMOTES_AND_EVENTS.md)
- [Config Guide](docs/CONFIG_GUIDE.md)
- [Animation Architecture](docs/ANIMATION_ARCHITECTURE.md)
- [Deployables And NPCs](docs/DEPLOYABLES_AND_NPCS.md)
- [Asset Guide](docs/ASSET_GUIDE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Extending The Game](docs/EXTENDING_THE_GAME.md)

Documentos de apoyo historicos/especificos:
- [Teams And Summons](docs/TEAMS_AND_SUMMONS.md)
- [Deployable Legendary Implementation](docs/DEPLOYABLE_LEGENDARY_IMPLEMENTATION.md)
- [NPC Deployables Plan](docs/NPC_DEPLOYABLES_PLAN.md)
- [Agent Guide](AGENTS.md)

## Build rapido
`rojo build -o "gwproject.rbxlx"`

`rojo serve`
