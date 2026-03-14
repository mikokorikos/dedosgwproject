--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local Net = require(RS.GW.Shared.Net)
local Characters = require(RS.GW.Shared.CharacterRegistry)
local Plantables = require(RS.GW.Shared.PlantableRegistry)
local PlantSpotUtil = require(RS.GW.Shared.PlantSpotUtil)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Plantable")

local function isTyping(): boolean
	return UIS:GetFocusedTextBox() ~= nil
end

local function getCenterRayHit(maxDistance: number): (Instance?, Vector3?, Vector3?)
	local cam = workspace.CurrentCamera
	if not cam then
		return nil, nil, nil
	end

	local viewport = cam.ViewportSize
	local ray = cam:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = player.Character and {player.Character} or {}

	local result = workspace:Raycast(ray.Origin, ray.Direction.Unit * maxDistance, params)
	if result then
		return result.Instance, result.Position, result.Normal
	end

	return nil, ray.Origin + ray.Direction.Unit * maxDistance, Vector3.new(0, 1, 0)
end

local function getPlantableBinds(): {{id: string, key: any}}
	local characterId = player:GetAttribute("CharacterId")
	local resolvedCharacterId = if typeof(characterId) == "string" then characterId else nil
	local characterCfg = Characters.Get(resolvedCharacterId)
	local slots = characterCfg.plantables
	if slots and #slots > 0 then
		return slots
	end
	return {
		{ id = Plantables.DefaultId, key = "F" },
	}
end

local function resolvePressedBind(inputKey: Enum.KeyCode): {id: string, key: any}?
	for _, bind in ipairs(getPlantableBinds()) do
		local keyCode: Enum.KeyCode? = nil
		if typeof(bind.key) == "EnumItem" then
			keyCode = bind.key
		elseif type(bind.key) == "string" then
			keyCode = Enum.KeyCode[bind.key]
		end
		if keyCode and keyCode == inputKey then
			return bind
		end
	end
	return nil
end

UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if isTyping() then
		return
	end

	local bind = resolvePressedBind(input.KeyCode)
	if not bind then
		return
	end

	local hitInst, hitPos, hitNormal = getCenterRayHit(300)
	local spot = PlantSpotUtil.findSpotFromInstance(hitInst)
	local spotId = if spot then PlantSpotUtil.getSpotId(spot) else nil

	log:info(string.format(
		"Place request -> key=%s plantableId=%s spotId=%s",
		tostring(bind.key),
		tostring(bind.id),
		tostring(spotId)
	))

	Net.PlantableRequest:FireServer({
		action = "Place",
		plantableId = bind.id,
		spotId = spotId,
		position = hitPos,
		normal = hitNormal,
	})
end)

Net.PlantableEvent.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local eventType = payload.type
	if eventType == "Placed" then
		log:info(string.format(
			"Placement confirmed -> plantableId=%s spotId=%s deployableId=%s",
			tostring(payload.plantableId),
			tostring(payload.spotId),
			tostring(payload.deployableId)
		))
	elseif eventType == "Rejected" then
		log:warn(string.format(
			"Placement rejected -> plantableId=%s reason=%s spotId=%s",
			tostring(payload.plantableId),
			tostring(payload.reason),
			tostring(payload.spotId)
		))
	end
end)

log:info("PlantableController ready (spot placement keybinds enabled)")
