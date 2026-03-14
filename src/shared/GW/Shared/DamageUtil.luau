--!strict
local RS = game:GetService("ReplicatedStorage")

local DamageUtil = {}
local EntityRelations = require(RS.GW.Shared.EntityRelations)

function DamageUtil.isFriendly(shooter: Player, targetHum: Humanoid, allowFriendlyFire: boolean): boolean
	if allowFriendlyFire then return false end
	return EntityRelations.areAllies(shooter, targetHum)
end

function DamageUtil.getFactionId(entity: any): string?
	return EntityRelations.getFactionId(entity)
end

function DamageUtil.getTeamId(entity: any): string?
	return EntityRelations.getTeamId(entity)
end

function DamageUtil.areAllies(a: any, b: any): boolean
	return EntityRelations.areAllies(a, b)
end

function DamageUtil.areEnemies(a: any, b: any): boolean
	return EntityRelations.areEnemies(a, b)
end

function DamageUtil.computeFalloff(baseDamage: number, dist: number, falloff: any?): number
	if type(falloff) ~= "table" then
		return baseDamage
	end
	local startD = tonumber(falloff.start) or math.huge
	local finishD = tonumber(falloff.finish) or math.huge
	local minMult = tonumber(falloff.minMult) or 1

	if dist <= startD then return baseDamage end
	if dist >= finishD then return baseDamage * minMult end

	local t = (dist - startD) / math.max(0.001, finishD - startD)
	local mult = 1 + (minMult - 1) * t
	return baseDamage * mult
end

function DamageUtil.canDamage(attacker: any, targetHum: Humanoid, allowFriendlyFire: boolean): boolean
	return EntityRelations.canDamage(attacker, targetHum, allowFriendlyFire)
end

function DamageUtil.canTarget(attacker: any, targetHum: Humanoid, allowFriendlyFire: boolean): boolean
	return EntityRelations.canTarget(attacker, targetHum, allowFriendlyFire)
end

function DamageUtil.canHeal(source: any, targetHum: Humanoid, allowCrossTeam: boolean): boolean
	return EntityRelations.canHeal(source, targetHum, allowCrossTeam)
end

function DamageUtil.resolveOwnerUserId(entity: any): number?
	return EntityRelations.resolveOwnerUserId(entity)
end

function DamageUtil.resolveSummonerUserId(entity: any): number?
	return EntityRelations.resolveSummonerUserId(entity)
end

return DamageUtil
