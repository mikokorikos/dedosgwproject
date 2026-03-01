--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local Remotes = GW:WaitForChild("Remotes")

export type CombatRequestPayload = {
	action: "Shoot" | "Reload" | "DryTrigger",
	weaponId: string?,
	shotId: string?,
	clientShotTime: number?,
	origin: Vector3?,
	direction: Vector3?,
	claimedHitPart: string?,
	claimedHitPosition: Vector3?,
}

return {
	CombatRequest = Remotes:WaitForChild("CombatRequest") :: RemoteEvent,
	AbilityRequest = Remotes:WaitForChild("AbilityRequest") :: RemoteEvent,
	FXEvent = Remotes:WaitForChild("FXEvent") :: RemoteEvent,
}
