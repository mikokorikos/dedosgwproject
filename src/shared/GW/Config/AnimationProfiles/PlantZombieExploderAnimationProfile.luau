--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type AnimationProfileConfig = Types.AnimationProfileConfig

local profile: AnimationProfileConfig = {
	id = "PlantZombieExploderAnimationProfile",
	defaults = {
		fadeTime = 0.12,
		speed = 1,
		weight = 1,
		runThresholdRatio = 0.65,
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
			referenceSpeed = 14,
		},
		Chase = {
			animationId = "rbxassetid://100477131302338",
			priority = "Movement",
			looped = true,
			referenceSpeed = 14,
		},
	},
	actions = {
		Deploy = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
		},
		Arm = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
		},
		Explode = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
		},
		Death = {
			animationId = "rbxassetid://81601740746075",
			priority = "Action",
			looped = false,
		},
	},
}

return profile
