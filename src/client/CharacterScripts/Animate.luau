--!strict
local RS = game:GetService("ReplicatedStorage")

local ClientAnimationService = require(RS.GW.Shared.ClientAnimationService)

local character = script.Parent
if character and character:IsA("Model") then
	ClientAnimationService.bindCharacter(character)
else
	ClientAnimationService.ensureInitialized()
end
