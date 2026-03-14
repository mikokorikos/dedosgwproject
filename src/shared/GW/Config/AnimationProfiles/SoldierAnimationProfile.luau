--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type AnimationProfileConfig = Types.AnimationProfileConfig

local profile: AnimationProfileConfig = {
	id = "SoldierAnimationProfile",
	defaults = {
		fadeTime = 0.10,
		speed = 1,
		weight = 1,
		triggerDelay = 0.20,
		runThresholdRatio = 0.75,
	},
	locomotion = {
		Idle = {
			animationId = "rbxassetid://76906466107364",
			priority = "Idle",
			looped = true,
		},
		Walk = {
			animationId = "rbxassetid://100477131302338",
			priority = "Movement",
			looped = true,
			referenceSpeed = 8,
		},
		Run = {
			animationId = "rbxassetid://100477131302338",
			priority = "Movement",
			looped = true,
			referenceSpeed = 16,
		},
		Jump = {
			animationId = "rbxassetid://81601740746075",
			priority = "Movement",
			looped = false,
		},
		Fall = {
			animationId = "rbxassetid://81601740746075",
			priority = "Movement",
			looped = true,
		},
	},
	actions = {
		Shoot = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
		},
		Reload = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
		},
		BackRocket = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
			triggerMode = "delay",
			triggerDelay = 0.35,
		},
		PlantZombieDeploy = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
			triggerMode = "delay",
			triggerDelay = 0.10,
		},
		AbilityQ = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
			triggerMode = "delay",
			triggerDelay = 0.35,
		},
		AbilityE = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
			triggerMode = "delay",
			triggerDelay = 0.10,
		},
		AbilityR = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
			triggerMode = "delay",
			triggerDelay = 0.20,
		},
		AbilityGeneric = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
			triggerMode = "instant",
		},
	},
}

return profile
