--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Net = require(RS.GW.Shared.Net)
local Plantables = require(RS.GW.Shared.PlantableRegistry)
local PlantSpotUtil = require(RS.GW.Shared.PlantSpotUtil)
local EntityRelations = require(RS.GW.Shared.EntityRelations)
local DeployableService = require(script.Parent.DeployableService)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Plantable")

type SpotOccupancy = {
	model: Model,
	ownerUserId: number,
	plantableId: string,
}

local cooldownByPlayer: {[Player]: {[string]: number}} = {}
local activeByPlayer: {[Player]: {[string]: {[Model]: number}}} = {}
local occupancyBySpot: {[BasePart]: SpotOccupancy} = {}
local spotById: {[string]: BasePart} = {}

local function playerLabel(player: Player): string
	return string.format("%s(%d)", player.Name, player.UserId)
end

local function getAlive(player: Player): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp or hum.Health <= 0 then
		return nil, nil, nil
	end
	return char, hum, hrp
end

local function pruneActiveModels(player: Player, plantableId: string)
	local byPlantable = activeByPlayer[player]
	if not byPlantable then
		return
	end
	local byModel = byPlantable[plantableId]
	if not byModel then
		return
	end
	for model in pairs(byModel) do
		if not model.Parent then
			byModel[model] = nil
		end
	end
end

local function getActiveCount(player: Player, plantableId: string): number
	pruneActiveModels(player, plantableId)
	local byPlantable = activeByPlayer[player]
	if not byPlantable or not byPlantable[plantableId] then
		return 0
	end
	local total = 0
	for _ in pairs(byPlantable[plantableId]) do
		total += 1
	end
	return total
end

local function registerActiveModel(player: Player, plantableId: string, model: Model)
	activeByPlayer[player] = activeByPlayer[player] or {}
	activeByPlayer[player][plantableId] = activeByPlayer[player][plantableId] or {}
	activeByPlayer[player][plantableId][model] = os.clock()
end

local function isSpotOccupied(spot: BasePart): boolean
	local occupancy = occupancyBySpot[spot]
	if not occupancy then
		return false
	end
	if not occupancy.model.Parent then
		occupancyBySpot[spot] = nil
		return false
	end
	return true
end

local function releaseSpot(spot: BasePart, reason: string)
	local occupancy = occupancyBySpot[spot]
	if not occupancy then
		return
	end
	occupancyBySpot[spot] = nil
	spot:SetAttribute("GWPlantSpotOccupied", false)
	spot:SetAttribute("GWPlantSpotOccupantUserId", nil)
	spot:SetAttribute("GWPlantSpotOccupantPlantableId", nil)
	log:trace(string.format(
		"Spot released -> spotId=%s reason=%s",
		tostring(PlantSpotUtil.getSpotId(spot)),
		reason
	))
end

local function trackSpotInstance(inst: Instance)
	if not inst:IsA("BasePart") or not PlantSpotUtil.isSpot(inst) then
		return
	end
	local spotId = PlantSpotUtil.getSpotId(inst)
	if not spotId then
		return
	end
	local existing = spotById[spotId]
	if existing and existing ~= inst and existing.Parent then
		log:warn(string.format(
			"Duplicate spot id detected (runtime update) -> spotId=%s old=%s new=%s",
			spotId,
			existing:GetFullName(),
			inst:GetFullName()
		))
	end
	spotById[spotId] = inst
end

local function untrackSpotInstance(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local spot = PlantSpotUtil.findSpotFromInstance(inst)
	if not spot then
		return
	end
	local spotId = PlantSpotUtil.getSpotId(spot)
	if spotId and spotById[spotId] == spot then
		spotById[spotId] = nil
	end
	releaseSpot(spot, "spot_removed")
end

local function rebuildSpotCache()
	table.clear(spotById)
	local spots = PlantSpotUtil.collectSpots(workspace)
	for _, spot in ipairs(spots) do
		local spotId = PlantSpotUtil.getSpotId(spot)
		if spotId then
			local existing = spotById[spotId]
			if existing and existing ~= spot and existing.Parent then
				log:warn(string.format(
					"Duplicate spot id detected during cache rebuild -> spotId=%s first=%s duplicate=%s",
					spotId,
					existing:GetFullName(),
					spot:GetFullName()
				))
			end
			spotById[spotId] = spot
		end
	end
	log:trace("Plantable spot cache rebuilt count=" .. tostring(#spots))
end

local function getSpotById(spotId: string?): BasePart?
	if type(spotId) ~= "string" or spotId == "" then
		return nil
	end
	local spot = spotById[spotId]
	if spot and spot.Parent and PlantSpotUtil.isSpot(spot) then
		return spot
	end
	rebuildSpotCache()
	spot = spotById[spotId]
	if spot and spot.Parent and PlantSpotUtil.isSpot(spot) then
		return spot
	end
	return nil
end

local function findNearestSpot(position: Vector3, radius: number): BasePart?
	local bestSpot: BasePart? = nil
	local bestDist: number? = nil
	for _, spot in pairs(spotById) do
		if spot.Parent and PlantSpotUtil.isSpot(spot) then
			local dist = (spot.Position - position).Magnitude
			if dist <= radius then
				if not bestDist or dist < bestDist then
					bestDist = dist
					bestSpot = spot
				end
			end
		end
	end
	return bestSpot
end

local function consumeCooldown(player: Player, plantableId: string, cooldown: number): boolean
	cooldownByPlayer[player] = cooldownByPlayer[player] or {}
	local now = os.clock()
	local nextAllowedAt = cooldownByPlayer[player][plantableId] or 0
	if now < nextAllowedAt then
		return false
	end
	cooldownByPlayer[player][plantableId] = now + cooldown
	return true
end

local function isOnCooldown(player: Player, plantableId: string): boolean
	local now = os.clock()
	local byPlantable = cooldownByPlayer[player]
	if not byPlantable then
		return false
	end
	local nextAllowedAt = byPlantable[plantableId] or 0
	return now < nextAllowedAt
end

local function rejectPlacement(player: Player, payload: any, plantableId: string?, reason: string)
	log:warn(string.format(
		"Plantable place rejected -> player=%s plantableId=%s reason=%s",
		playerLabel(player),
		tostring(plantableId),
		reason
	))
	Net.PlantableEvent:FireClient(player, {
		type = "Rejected",
		reason = reason,
		plantableId = plantableId,
		spotId = if type(payload) == "table" then payload.spotId else nil,
	})
end

local function resolvePlacementSpot(payload: any, cfg: any): BasePart?
	local spot = getSpotById(payload.spotId)
	if spot then
		return spot
	end

	local position = payload.position
	if typeof(position) ~= "Vector3" then
		return nil
	end

	local selectionRadius = tonumber(cfg.selectionRadius) or 6
	return findNearestSpot(position, selectionRadius)
end

local function validateSpotForPlayer(player: Player, hrp: BasePart, cfg: any, spot: BasePart): (boolean, string?)
	if not PlantSpotUtil.isSpotEnabled(spot) then
		return false, "spot_disabled"
	end

	if cfg.requiresFreeSpot ~= false and isSpotOccupied(spot) then
		return false, "spot_occupied"
	end

	local configuredSpotType = cfg.spotType
	local runtimeSpotType = PlantSpotUtil.getSpotType(spot)
	if type(configuredSpotType) == "string" and configuredSpotType ~= "" then
		if type(runtimeSpotType) ~= "string" or runtimeSpotType == "" then
			return false, "spot_type_missing"
		end
		if runtimeSpotType ~= configuredSpotType then
			return false, "spot_type_mismatch"
		end
	end

	if cfg.allowEnemySpots ~= true then
		local playerFaction = EntityRelations.getFactionId(player)
		local spotFaction = EntityRelations.getFactionId(spot) or PlantSpotUtil.getSpotFactionId(spot)
		if playerFaction and spotFaction and playerFaction ~= spotFaction then
			return false, "spot_enemy_faction"
		end
	end

	local placeRange = tonumber(cfg.placeRange) or 32
	local dist = (spot.Position - hrp.Position).Magnitude
	if dist > placeRange then
		return false, "spot_out_of_range"
	end

	return true, nil
end

local function makeSpawnCFrame(spot: BasePart, hrp: BasePart, cfg: any): CFrame
	local look = spot.CFrame.LookVector
	if look.Magnitude < 0.001 then
		look = hrp.CFrame.LookVector
	end
	local forwardOffset = tonumber(cfg.spawnForwardOffset) or 0
	local upOffset = tonumber(cfg.spawnUpOffset) or 0
	local pos = spot.Position + look.Unit * forwardOffset + Vector3.new(0, (spot.Size.Y * 0.5) + upOffset, 0)
	return CFrame.lookAt(pos, pos + look.Unit)
end

local function markSpotOccupied(spot: BasePart, model: Model, player: Player, plantableId: string)
	occupancyBySpot[spot] = {
		model = model,
		ownerUserId = player.UserId,
		plantableId = plantableId,
	}
	spot:SetAttribute("GWPlantSpotOccupied", true)
	spot:SetAttribute("GWPlantSpotOccupantUserId", player.UserId)
	spot:SetAttribute("GWPlantSpotOccupantPlantableId", plantableId)
	model:SetAttribute("PlantSpotId", PlantSpotUtil.getSpotId(spot))
	model:SetAttribute("PlantableId", plantableId)
	model:SetAttribute("EntityKind", "Plantable")

	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			releaseSpot(spot, "deployable_removed")
		end
	end)
end

local function handlePlaceRequest(player: Player, payload: any)
	local requestedPlantableId = if type(payload.plantableId) == "string" and payload.plantableId ~= "" then payload.plantableId else nil
	local plantableId = requestedPlantableId or (player:GetAttribute("PlantableId") :: string?) or Plantables.DefaultId
	local cfg = Plantables.Get(plantableId)

	local char, _hum, hrp = getAlive(player)
	if not char or not hrp then
		rejectPlacement(player, payload, plantableId, "player_not_alive")
		return
	end

	local cooldown = tonumber(cfg.cooldown) or 0
	if isOnCooldown(player, cfg.id) then
		rejectPlacement(player, payload, cfg.id, "cooldown")
		return
	end

	local maxActive = tonumber(cfg.maxActive) or math.huge
	if getActiveCount(player, cfg.id) >= maxActive then
		rejectPlacement(player, payload, cfg.id, "max_active")
		return
	end

	local spot = resolvePlacementSpot(payload, cfg)
	if not spot then
		rejectPlacement(player, payload, cfg.id, "spot_not_found")
		return
	end

	local isValidSpot, invalidReason = validateSpotForPlayer(player, hrp, cfg, spot)
	if not isValidSpot then
		rejectPlacement(player, payload, cfg.id, tostring(invalidReason))
		return
	end

	local spotId = PlantSpotUtil.getSpotId(spot)
	local spawnCFrame = makeSpawnCFrame(spot, hrp, cfg)
	if not consumeCooldown(player, cfg.id, cooldown) then
		rejectPlacement(player, payload, cfg.id, "cooldown")
		return
	end

	local spawnResult, spawnErr = DeployableService.spawn(player, cfg.deployableId, spawnCFrame)
	if not spawnResult then
		rejectPlacement(player, payload, cfg.id, "spawn_failed_" .. tostring(spawnErr))
		return
	end

	markSpotOccupied(spot, spawnResult.model, player, cfg.id)
	registerActiveModel(player, cfg.id, spawnResult.model)

	if cfg.usePrototypeRunner ~= false then
		DeployableService.runPrototype(spawnResult)
	end

	log:info(string.format(
		"Plantable placed -> player=%s plantableId=%s deployableId=%s spotId=%s faction=%s",
		playerLabel(player),
		cfg.id,
		tostring(cfg.deployableId),
		tostring(spotId),
		tostring(EntityRelations.getFactionId(spawnResult.model))
	))
	Net.PlantableEvent:FireClient(player, {
		type = "Placed",
		plantableId = cfg.id,
		deployableId = cfg.deployableId,
		spotId = spotId,
	})
end

Net.PlantableRequest.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" then
		rejectPlacement(player, {}, nil, "payload_not_table")
		return
	end

	local action = payload.action
	if action == "Place" then
		handlePlaceRequest(player, payload)
		return
	end

	if action == "Preview" then
		-- Hook reservado para preview cliente->servidor de spots en fase siguiente.
		Net.PlantableEvent:FireClient(player, { type = "PreviewAck" })
		return
	end

	rejectPlacement(player, payload, payload.plantableId, "unknown_action")
end)

Players.PlayerRemoving:Connect(function(player)
	cooldownByPlayer[player] = nil
	activeByPlayer[player] = nil
end)

rebuildSpotCache()
workspace.DescendantAdded:Connect(trackSpotInstance)
workspace.DescendantRemoving:Connect(untrackSpotInstance)

for _, tagged in ipairs(CollectionService:GetTagged(PlantSpotUtil.SPOT_TAG)) do
	trackSpotInstance(tagged)
end

log:info("PlantableService active (spot pipeline enabled)")
