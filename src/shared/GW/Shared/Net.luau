--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local Remotes = GW:WaitForChild("Remotes")

return {
	CombatRequest = Remotes:WaitForChild("CombatRequest") :: RemoteEvent,
	AbilityRequest = Remotes:WaitForChild("AbilityRequest") :: RemoteEvent,
	FXEvent = Remotes:WaitForChild("FXEvent") :: RemoteEvent,
}
