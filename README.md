# GW Project

Proyecto Roblox en LuaU con arquitectura modular para un shooter tipo Garden Warfare:
- arma primaria hitscan (click)
- habilidad de personaje (Q, actualmente `BackRocket`)
- pipeline cliente/servidor con validacion y replicacion de FX

## Stack
- Roblox Studio + LuaU
- Rojo (`default.project.json`)
- ReplicatedStorage para codigo compartido y `RemoteEvent`s

## Documentacion Interna
- [Estructura del proyecto](docs/PROJECT_STRUCTURE.md)
- [Guia de configuracion y animaciones](docs/CONFIG_GUIDE.md)
- [Flujos runtime (combat, habilidad, ammo, FX)](docs/FLOWS.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Guia para agentes/cambios](AGENTS.md)

## Quick Start
Compilar place:

```bash
rojo build -o "gwproject.rbxlx"
```

Levantar servidor Rojo:

```bash
rojo serve
```

Abrir `gwproject.rbxlx` en Roblox Studio y conectar Rojo.
