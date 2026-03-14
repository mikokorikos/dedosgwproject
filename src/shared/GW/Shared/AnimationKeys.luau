--!strict

local AnimationKeys = {
	Locomotion = {
		Idle = "Idle",
		Walk = "Walk",
		Run = "Run",
		Jump = "Jump",
		Fall = "Fall",
		Death = "Death",
		Chase = "Chase",
	},
	Actions = {
		Shoot = "Shoot",
		Reload = "Reload",
		AbilityQ = "AbilityQ",
		AbilityE = "AbilityE",
		AbilityR = "AbilityR",
		AbilityGeneric = "AbilityGeneric",
		Deploy = "Deploy",
		Arm = "Arm",
		Explode = "Explode",
		Death = "Death",
	},
}

function AnimationKeys.actionFromBindKey(bindKey: string?): string
	if type(bindKey) ~= "string" then
		return AnimationKeys.Actions.AbilityGeneric
	end
	local key = string.upper(bindKey)
	if key == "Q" then
		return AnimationKeys.Actions.AbilityQ
	elseif key == "E" then
		return AnimationKeys.Actions.AbilityE
	elseif key == "R" then
		return AnimationKeys.Actions.AbilityR
	end
	return AnimationKeys.Actions.AbilityGeneric
end

return AnimationKeys