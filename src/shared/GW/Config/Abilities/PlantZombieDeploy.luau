--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type AbilityConfig = Types.AbilityConfig

local config: AbilityConfig = {
	id = "PlantZombieDeploy",
	isDefault = false,
	cooldown = 12,

	-- Deployable path (handled by AbilityService -> DeployableService).
	deployableId = "PlantZombieExploder",
	deployableSpawnForwardOffset = 4.5,
	deployableSpawnUpOffset = 0.0,
	deployableUsePrototypeRunner = true,

	friendlyFire = false,
	selfDamage = false,
}

return config
