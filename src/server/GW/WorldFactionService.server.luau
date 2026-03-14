--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")

local EntityRelations = require(RS.GW.Shared.EntityRelations)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("WorldFaction")

local RIG_NAME = "Rig"
local RIG_FACTION_ID = "Plants"

local function isPlayerCharacter(model: Model): boolean
	return Players:GetPlayerFromCharacter(model) ~= nil
end

local function tryTagRig(model: Model)
	if string.lower(model.Name) ~= string.lower(RIG_NAME) then
		return
	end
	if isPlayerCharacter(model) then
		return
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		log:warn("Rig found without Humanoid, skipped: " .. model:GetFullName())
		return
	end

	EntityRelations.tagEntity(model, {
		factionId = RIG_FACTION_ID,
		teamId = RIG_FACTION_ID,
		isSummonedEntity = false,
		entityKind = "WorldNPC",
	})

	-- Keep humanoid/root attributes aligned as well to avoid stale per-instance
	-- values overriding model faction resolution during combat checks.
	EntityRelations.tagEntity(hum, {
		factionId = RIG_FACTION_ID,
		teamId = RIG_FACTION_ID,
		isSummonedEntity = false,
		entityKind = "WorldNPC",
	})

	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		EntityRelations.tagEntity(hrp, {
			factionId = RIG_FACTION_ID,
			teamId = RIG_FACTION_ID,
			isSummonedEntity = false,
			entityKind = "WorldNPC",
		})
	end

	log:info(string.format(
		"World rig faction applied -> model=%s modelFaction=%s humanoidFaction=%s expected=%s",
		model:GetFullName(),
		tostring(model:GetAttribute("FactionId")),
		tostring(hum:GetAttribute("FactionId")),
		RIG_FACTION_ID
	))
end

for _, inst in ipairs(Workspace:GetDescendants()) do
	if inst:IsA("Model") then
		tryTagRig(inst)
	end
end

Workspace.DescendantAdded:Connect(function(inst: Instance)
	if inst:IsA("Model") then
		task.defer(function()
			if inst.Parent then
				tryTagRig(inst)
			end
		end)
	end
end)

log:info("WorldFactionService active (Rig -> Plant)")
