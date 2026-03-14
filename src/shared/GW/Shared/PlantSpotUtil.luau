--!strict
local CollectionService = game:GetService("CollectionService")

local PlantSpotUtil = {}

PlantSpotUtil.SPOT_TAG = "GWPlantSpot"
PlantSpotUtil.SPOT_ID_ATTRIBUTE = "GWPlantSpotId"
PlantSpotUtil.SPOT_TYPE_ATTRIBUTE = "GWPlantSpotType"
PlantSpotUtil.SPOT_ENABLED_ATTRIBUTE = "GWPlantSpotEnabled"
PlantSpotUtil.SPOT_FACTION_ATTRIBUTE = "GWPlantSpotFactionId"

local function readStringAttribute(inst: Instance, names: {string}): string?
	for _, name in ipairs(names) do
		local value = inst:GetAttribute(name)
		if type(value) == "string" and value ~= "" then
			return value
		end
	end
	return nil
end

function PlantSpotUtil.isSpot(inst: Instance?): boolean
	if not inst or not inst:IsA("BasePart") then
		return false
	end
	if CollectionService:HasTag(inst, PlantSpotUtil.SPOT_TAG) then
		return true
	end
	local spotId = readStringAttribute(inst, {PlantSpotUtil.SPOT_ID_ATTRIBUTE})
	return spotId ~= nil
end

function PlantSpotUtil.findSpotFromInstance(inst: Instance?): BasePart?
	local current = inst
	while current do
		if current:IsA("BasePart") and PlantSpotUtil.isSpot(current) then
			return current
		end
		current = current.Parent
	end
	return nil
end

function PlantSpotUtil.getSpotId(spot: BasePart): string?
	local spotId = readStringAttribute(spot, {PlantSpotUtil.SPOT_ID_ATTRIBUTE})
	if spotId then
		return spotId
	end
	if CollectionService:HasTag(spot, PlantSpotUtil.SPOT_TAG) then
		return spot.Name
	end
	return nil
end

function PlantSpotUtil.getSpotType(spot: BasePart): string?
	return readStringAttribute(spot, {PlantSpotUtil.SPOT_TYPE_ATTRIBUTE, "SpotType"})
end

function PlantSpotUtil.getSpotFactionId(spot: BasePart): string?
	return readStringAttribute(spot, {
		PlantSpotUtil.SPOT_FACTION_ATTRIBUTE,
		"FactionId",
		"TeamId",
	})
end

function PlantSpotUtil.isSpotEnabled(spot: BasePart): boolean
	local enabled = spot:GetAttribute(PlantSpotUtil.SPOT_ENABLED_ATTRIBUTE)
	if enabled == nil then
		return true
	end
	return enabled == true
end

function PlantSpotUtil.collectSpots(root: Instance?): {BasePart}
	local source = root or workspace
	local spots: {BasePart} = {}
	for _, inst in ipairs(source:GetDescendants()) do
		if inst:IsA("BasePart") and PlantSpotUtil.isSpot(inst) then
			table.insert(spots, inst)
		end
	end
	return spots
end

return PlantSpotUtil
