--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local Remotes = GW:WaitForChild("Remotes")

export type CombatRequestPayload = {
	action: "Shoot" | "Reload" | "DryTrigger",
	weaponId: string?,
	reason: string?,
	shotId: string?,
	clientShotTime: number?,
	origin: Vector3?,
	direction: Vector3?,
	muzzlePos: Vector3?,
	cameraOrigin: Vector3?,
	aimPoint: Vector3?,
	claimedHitPart: string?,
	claimedHitPosition: Vector3?,
}

export type PlantableRequestPayload = {
	action: "Place" | "Preview",
	plantableId: string?,
	spotId: string?,
	position: Vector3?,
	normal: Vector3?,
}

return {
	CombatRequest = Remotes:WaitForChild("CombatRequest") :: RemoteEvent,
	ReportHit = Remotes:WaitForChild("ReportHit") :: RemoteEvent,
	ReplicateShot = Remotes:WaitForChild("ReplicateShot") :: RemoteEvent,
	AbilityRequest = Remotes:WaitForChild("AbilityRequest") :: RemoteEvent,
	PlantableRequest = Remotes:WaitForChild("PlantableRequest") :: RemoteEvent,
	PlantableEvent = Remotes:WaitForChild("PlantableEvent") :: RemoteEvent,
	FXEvent = Remotes:WaitForChild("FXEvent") :: RemoteEvent,
}
