--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type PlantableConfig = Types.PlantableConfig

local config: PlantableConfig = {
	id = "PlantZombieSpotExploder",
	isDefault = true,
	displayName = "Plant Zombie Spot Exploder",

	deployableId = "PlantZombieExploder",
	spotType = "Zombie",
	allowEnemySpots = false,
	requiresFreeSpot = true,

	placeRange = 42,
	selectionRadius = 7,
	spawnForwardOffset = 0,
	spawnUpOffset = 1.2,

	cooldown = 7,
	maxActive = 3,
	usePrototypeRunner = true,
}

return config
