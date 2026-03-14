--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type CharacterConfig = Types.CharacterConfig

local config: CharacterConfig = {
	id = "Soldier",
	isDefault = true,
	weaponId = "SoldierRifle",
	animationProfileId = "SoldierAnimationProfile",
	abilities = {
		{ id = "BackRocket", key = "Q", animationActionKey = "BackRocket" },
		{ id = "PlantZombieDeploy", key = "E", animationActionKey = "PlantZombieDeploy" },
	},
	plantables = {
		{ id = "PlantZombieSpotExploder", key = "F" },
	},
}

return config
