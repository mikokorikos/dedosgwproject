--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type CharacterConfig = Types.CharacterConfig

local config: CharacterConfig = {
	id = "Soldier",
	isDefault = true,
	weaponId = "SoldierRifle",
	abilities = {
		{ id = "BackRocket", key = "Q" },
	},
}

return config
