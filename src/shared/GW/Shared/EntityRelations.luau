--!strict
local Players = game:GetService("Players")

export type RelationContext = {
	player: Player?,
	instance: Instance?,
	model: Model?,
	humanoid: Humanoid?,
	factionId: string?,
	teamId: string?,
	ownerUserId: number?,
	summonerUserId: number?,
}

export type RelationTagOptions = {
	factionId: string?,
	teamId: string?,
	ownerUserId: number?,
	summonerUserId: number?,
	isSummonedEntity: boolean?,
	entityKind: string?,
}

local EntityRelations = {}

local function normalizeId(value: any): string?
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function parseUserId(value: any): number?
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		local parsed = tonumber(value)
		if parsed then
			return parsed
		end
	end
	return nil
end

local function readStringAttribute(inst: Instance?, names: {string}): string?
	if not inst then
		return nil
	end
	for _, name in ipairs(names) do
		local value = normalizeId(inst:GetAttribute(name))
		if value then
			return value
		end
	end
	return nil
end

local function readNumberAttribute(inst: Instance?, names: {string}): number?
	if not inst then
		return nil
	end
	for _, name in ipairs(names) do
		local parsed = parseUserId(inst:GetAttribute(name))
		if parsed then
			return parsed
		end
	end
	return nil
end

local function getPlayerByUserId(userId: number?): Player?
	if type(userId) ~= "number" then
		return nil
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

local function getPlayerFactionId(player: Player?): string?
	if not player then
		return nil
	end

	local attrFaction = normalizeId(player:GetAttribute("FactionId"))
	if attrFaction then
		return attrFaction
	end

	local attrTeam = normalizeId(player:GetAttribute("TeamId"))
	if attrTeam then
		return attrTeam
	end

	local team = player.Team
	if team and team.Name ~= "" then
		return team.Name
	end

	return nil
end

local function getPlayerTeamId(player: Player?): string?
	if not player then
		return nil
	end

	local attrTeam = normalizeId(player:GetAttribute("TeamId"))
	if attrTeam then
		return attrTeam
	end

	local attrFaction = normalizeId(player:GetAttribute("FactionId"))
	if attrFaction then
		return attrFaction
	end

	local team = player.Team
	if team and team.Name ~= "" then
		return team.Name
	end

	return nil
end

local function findModelFromInstance(inst: Instance?): Model?
	if not inst then
		return nil
	end
	if inst:IsA("Model") then
		return inst
	end
	return inst:FindFirstAncestorOfClass("Model")
end

local function resolveContext(entity: any): RelationContext?
	if entity == nil then
		return nil
	end

	local context: RelationContext = {
		player = nil,
		instance = nil,
		model = nil,
		humanoid = nil,
		factionId = nil,
		teamId = nil,
		ownerUserId = nil,
		summonerUserId = nil,
	}

	if typeof(entity) == "Instance" and entity:IsA("Player") then
		context.player = entity
	elseif typeof(entity) == "Instance" and entity:IsA("Humanoid") then
		context.humanoid = entity
		context.model = entity.Parent :: Model?
		context.instance = entity
	elseif typeof(entity) == "Instance" then
		context.instance = entity
		context.model = findModelFromInstance(entity)
	else
		return nil
	end

	if context.model and not context.humanoid then
		context.humanoid = context.model:FindFirstChildOfClass("Humanoid")
	end

	if context.model and not context.player then
		context.player = Players:GetPlayerFromCharacter(context.model)
	end

	if context.player then
		context.ownerUserId = context.player.UserId
		context.summonerUserId = context.player.UserId
	end

	-- 1) Direct instance attributes (plant spots, loose parts, etc.)
	-- Important: Humanoid attributes are often stale in tests. We avoid using
	-- humanoid-level faction/team as source-of-truth and rely on model/player.
	if not (context.instance and context.instance:IsA("Humanoid")) then
		local directFaction = readStringAttribute(context.instance, {"FactionId", "TeamId", "GWFactionId", "GWTeamId", "GWPlantSpotFactionId"})
		local directTeam = readStringAttribute(context.instance, {"TeamId", "FactionId", "GWTeamId", "GWFactionId"})
		local directOwner = readNumberAttribute(context.instance, {"OwnerUserId", "GWOwnerUserId"})
		local directSummoner = readNumberAttribute(context.instance, {"SummonerUserId", "GWSummonerUserId", "OwnerUserId", "GWOwnerUserId"})

		if directFaction then
			context.factionId = directFaction
		end
		if directTeam then
			context.teamId = directTeam
		end
		if directOwner then
			context.ownerUserId = directOwner
		end
		if directSummoner then
			context.summonerUserId = directSummoner
		end
	end

	-- 2) Model attributes (characters, NPCs, deployables).
	if context.model then
		local modelFaction = readStringAttribute(context.model, {"FactionId", "TeamId", "GWFactionId", "GWTeamId"})
		local modelTeam = readStringAttribute(context.model, {"TeamId", "FactionId", "GWTeamId", "GWFactionId"})
		local modelOwner = readNumberAttribute(context.model, {"OwnerUserId", "GWOwnerUserId"})
		local modelSummoner = readNumberAttribute(context.model, {"SummonerUserId", "GWSummonerUserId", "OwnerUserId", "GWOwnerUserId"})

		-- For humanoid contexts we prefer the model as source of truth to avoid stale
		-- humanoid-level attributes forcing wrong faction/team resolution.
		if context.instance and context.instance:IsA("Humanoid") then
			context.factionId = modelFaction or context.factionId
			context.teamId = modelTeam or context.teamId
			context.ownerUserId = modelOwner or context.ownerUserId
			context.summonerUserId = modelSummoner or context.summonerUserId
		else
			context.factionId = context.factionId or modelFaction
			context.teamId = context.teamId or modelTeam
			context.ownerUserId = context.ownerUserId or modelOwner
			context.summonerUserId = context.summonerUserId or modelSummoner
		end
	end

	-- 3) Player attributes / Team object.
	if context.player then
		context.factionId = context.factionId or getPlayerFactionId(context.player)
		context.teamId = context.teamId or getPlayerTeamId(context.player)
	end

	-- 4) Owner fallback.
	local ownerPlayer = getPlayerByUserId(context.ownerUserId)
	if ownerPlayer then
		context.factionId = context.factionId or getPlayerFactionId(ownerPlayer)
		context.teamId = context.teamId or getPlayerTeamId(ownerPlayer)
	end

	-- 5) Summoner fallback.
	local summonerPlayer = getPlayerByUserId(context.summonerUserId)
	if summonerPlayer then
		context.factionId = context.factionId or getPlayerFactionId(summonerPlayer)
		context.teamId = context.teamId or getPlayerTeamId(summonerPlayer)
	end

	return context
end

function EntityRelations.getContext(entity: any): RelationContext?
	return resolveContext(entity)
end

function EntityRelations.getFactionId(entity: any): string?
	local context = resolveContext(entity)
	return context and context.factionId or nil
end

function EntityRelations.getTeamId(entity: any): string?
	local context = resolveContext(entity)
	return context and context.teamId or nil
end

function EntityRelations.resolveOwnerUserId(entity: any): number?
	local context = resolveContext(entity)
	return context and context.ownerUserId or nil
end

function EntityRelations.resolveSummonerUserId(entity: any): number?
	local context = resolveContext(entity)
	return context and context.summonerUserId or nil
end

function EntityRelations.getOwnerUserId(entity: any): number?
	return EntityRelations.resolveOwnerUserId(entity)
end

function EntityRelations.areAllies(a: any, b: any): boolean
	local contextA = resolveContext(a)
	local contextB = resolveContext(b)
	if not contextA or not contextB then
		return false
	end

	if contextA.player and contextB.player and contextA.player.Team and contextB.player.Team then
		if contextA.player.Team == contextB.player.Team then
			return true
		end
	end

	if contextA.factionId and contextB.factionId then
		return contextA.factionId == contextB.factionId
	end

	if contextA.teamId and contextB.teamId then
		return contextA.teamId == contextB.teamId
	end

	if contextA.ownerUserId and contextB.ownerUserId then
		return contextA.ownerUserId == contextB.ownerUserId
	end

	if contextA.summonerUserId and contextB.summonerUserId then
		return contextA.summonerUserId == contextB.summonerUserId
	end

	if contextA.ownerUserId and contextB.player and contextA.ownerUserId == contextB.player.UserId then
		return true
	end
	if contextB.ownerUserId and contextA.player and contextB.ownerUserId == contextA.player.UserId then
		return true
	end

	return false
end

function EntityRelations.areEnemies(a: any, b: any): boolean
	local contextA = resolveContext(a)
	local contextB = resolveContext(b)
	if not contextA or not contextB then
		return false
	end
	return not EntityRelations.areAllies(a, b)
end

function EntityRelations.isSameTeam(a: any, b: any): boolean
	return EntityRelations.areAllies(a, b)
end

function EntityRelations.isEnemyTeam(a: any, b: any): boolean
	return EntityRelations.areEnemies(a, b)
end

function EntityRelations.canDamage(attacker: any, targetHumanoid: Humanoid, allowFriendlyFire: boolean): boolean
	if targetHumanoid.Health <= 0 then
		return false
	end
	local attackerContext = resolveContext(attacker)
	if attackerContext and attackerContext.humanoid and attackerContext.humanoid == targetHumanoid then
		return false
	end
	if allowFriendlyFire then
		return true
	end
	return EntityRelations.areEnemies(attacker, targetHumanoid)
end

function EntityRelations.canTarget(seeker: any, targetHumanoid: Humanoid, allowFriendlyFire: boolean): boolean
	return EntityRelations.canDamage(seeker, targetHumanoid, allowFriendlyFire)
end

function EntityRelations.canHeal(source: any, targetHumanoid: Humanoid, allowCrossTeam: boolean): boolean
	if targetHumanoid.Health <= 0 then
		return false
	end
	if allowCrossTeam then
		return true
	end
	return EntityRelations.areAllies(source, targetHumanoid)
end

function EntityRelations.getCollisionResponse(a: any, b: any, allowFriendlyCollision: boolean): "collide" | "ignore"
	if allowFriendlyCollision then
		return "collide"
	end
	if EntityRelations.areAllies(a, b) then
		return "ignore"
	end
	return "collide"
end

function EntityRelations.tagEntity(instance: Instance, options: RelationTagOptions?)
	local opts = options or {}
	local teamId = opts.teamId or opts.factionId
	local factionId = opts.factionId or opts.teamId
	local ownerUserId = opts.ownerUserId
	local summonerUserId = opts.summonerUserId or ownerUserId

	if factionId then
		instance:SetAttribute("FactionId", factionId)
	end
	if teamId then
		instance:SetAttribute("TeamId", teamId)
	end
	if ownerUserId then
		instance:SetAttribute("OwnerUserId", ownerUserId)
	end
	if summonerUserId then
		instance:SetAttribute("SummonerUserId", summonerUserId)
	end
	if opts.isSummonedEntity ~= nil then
		instance:SetAttribute("IsSummonedEntity", opts.isSummonedEntity == true)
	end
	if type(opts.entityKind) == "string" and opts.entityKind ~= "" then
		instance:SetAttribute("EntityKind", opts.entityKind)
	end
end

function EntityRelations.tagSummonModel(model: Model, ownerPlayer: Player, factionIdOverride: string?)
	local factionId = factionIdOverride or getPlayerFactionId(ownerPlayer) or "Neutral"
	local teamId = getPlayerTeamId(ownerPlayer) or factionId
	EntityRelations.tagEntity(model, {
		factionId = factionId,
		teamId = teamId,
		ownerUserId = ownerPlayer.UserId,
		summonerUserId = ownerPlayer.UserId,
		isSummonedEntity = true,
		entityKind = "Summon",
	})
end

return EntityRelations
