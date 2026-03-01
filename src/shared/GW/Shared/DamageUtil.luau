--!strict
local Players = game:GetService("Players")

local DamageUtil = {}

function DamageUtil.isFriendly(shooter: Player, targetHum: Humanoid, allowFriendlyFire: boolean): boolean
	if allowFriendlyFire then return false end
	local targetModel = targetHum.Parent
	if not targetModel then return false end

	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	if not targetPlayer then return false end -- NPC

	if targetPlayer == shooter then return true end
	if shooter.Team and targetPlayer.Team and shooter.Team == targetPlayer.Team then
		return true
	end
	return false
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

return DamageUtil
