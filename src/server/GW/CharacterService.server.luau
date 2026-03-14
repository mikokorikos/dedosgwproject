--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local CharacterRegistry = require(RS.GW.Shared.CharacterRegistry)
local WeaponRegistry = require(RS.GW.Shared.WeaponRegistry)
local PlantableRegistry = require(RS.GW.Shared.PlantableRegistry)
local EntityRelations = require(RS.GW.Shared.EntityRelations)
local Net = require(RS.GW.Shared.Net)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Character")

local function resolveFactionId(player: Player): string
	local existing = player:GetAttribute("FactionId")
	if type(existing) == "string" and existing ~= "" then
		return existing
	end

	local team = player.Team
	if team and team.Name ~= "" then
		return team.Name
	end

	return "Zombie"
end

local function applyDefaults(player: Player)
	local charCfg = CharacterRegistry.Get(nil)
	local firstPlantableSlot = if charCfg.plantables and #charCfg.plantables > 0 then charCfg.plantables[1] else nil
	local defaultPlantableId = if firstPlantableSlot and type(firstPlantableSlot.id) == "string" then firstPlantableSlot.id else PlantableRegistry.DefaultId
	player:SetAttribute("CharacterId", charCfg.id)
	player:SetAttribute("WeaponId", charCfg.weaponId or WeaponRegistry.DefaultId)
	player:SetAttribute("AnimationProfileId", charCfg.animationProfileId)
	player:SetAttribute("PlantableId", defaultPlantableId)
	local factionId = resolveFactionId(player)
	player:SetAttribute("FactionId", factionId)
	player:SetAttribute("TeamId", factionId)
	log:trace(string.format(
		"Defaults applied -> player=%s(%d) character=%s weapon=%s plantable=%s faction=%s",
		player.Name,
		player.UserId,
		tostring(player:GetAttribute("CharacterId")),
		tostring(player:GetAttribute("WeaponId")),
		tostring(player:GetAttribute("PlantableId")),
		factionId
	))
end

local function applyCharacterAlignment(player: Player, character: Model)
	local factionId = resolveFactionId(player)
	local profileId = player:GetAttribute("AnimationProfileId")
	EntityRelations.tagEntity(character, {
		factionId = factionId,
		teamId = factionId,
		ownerUserId = player.UserId,
		summonerUserId = player.UserId,
		isSummonedEntity = false,
		entityKind = "PlayerCharacter",
	})
	if type(profileId) == "string" and profileId ~= "" then
		character:SetAttribute("AnimationProfileId", profileId)
	end
end

Players.PlayerAdded:Connect(function(player)
	applyDefaults(player)
	player.CharacterAdded:Connect(function()
		-- Reapply defaults on respawn.
		applyDefaults(player)
		if player.Character then
			applyCharacterAlignment(player, player.Character)
		end

		-- Send initial ammo bootstrap (CombatService also does this).
		Net.FXEvent:FireClient(player, { type = "Init", weaponId = player:GetAttribute("WeaponId") })
	end)

	player:GetPropertyChangedSignal("Team"):Connect(function()
		applyDefaults(player)
		if player.Character then
			applyCharacterAlignment(player, player.Character)
		end
	end)
end)

for _, p in ipairs(Players:GetPlayers()) do
	applyDefaults(p)
	if p.Character then
		applyCharacterAlignment(p, p.Character)
	end
end

log:info("CharacterService active")
