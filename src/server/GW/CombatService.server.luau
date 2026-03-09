--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)
local RaycastUtil = require(RS.GW.Shared.RaycastUtil)
local DamageUtil = require(RS.GW.Shared.DamageUtil)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Combat")

type AmmoState = {
	mag: number,
	reserve: number,
	reloading: boolean,
	reloadEnd: number,
}

local lastShotAt: {[Player]: {[string]: number}} = {}
local ammoByPlayer: {[Player]: {[string]: AmmoState}} = {}
local ammoHandshakeByPlayer: {[Player]: {[string]: boolean}} = {}
local deathLock = setmetatable({}, {__mode="k"}) :: {[Humanoid]: number}
local rejectionCountByReason: {[string]: {count: number, lastLogAt: number}} = {}
local processedDamageShotByPlayer: {[Player]: {[string]: boolean}} = {}

local function playerLabel(player: Player): string
	return string.format("%s(%d)", player.Name, player.UserId)
end

local function getAlive(player: Player): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char then return nil, nil, nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp or hum.Health <= 0 then return nil, nil, nil end
	return char, hum, hrp
end

local function getWeaponId(player: Player): string
	local id = player:GetAttribute("WeaponId")
	if typeof(id) == "string" then return id end
	return Weapons.DefaultId
end

local function getAmmoState(player: Player, weaponId: string, weaponCfg: any): AmmoState
	ammoByPlayer[player] = ammoByPlayer[player] or {}
	local st = ammoByPlayer[player][weaponId]
	if st then return st end

	local magSize = tonumber(weaponCfg.ammo and weaponCfg.ammo.magSize) or 30
	local reserve = tonumber(weaponCfg.ammo and weaponCfg.ammo.reserve) or 90

	st = {
		mag = magSize,
		reserve = reserve,
		reloading = false,
		reloadEnd = 0,
	}
	ammoByPlayer[player][weaponId] = st
	log:info(string.format(
		"Ammo state created -> player=%s weaponId=%s mag=%d reserve=%d",
		playerLabel(player),
		tostring(weaponId),
		st.mag,
		st.reserve
	))
	return st
end

local function fireAmmoUpdate(player: Player, weaponId: string, st: AmmoState)
	ammoHandshakeByPlayer[player] = ammoHandshakeByPlayer[player] or {}
	ammoHandshakeByPlayer[player][weaponId] = true
	log:trace(string.format(
		"Ammo update -> player=%s weaponId=%s mag=%d reserve=%d reloading=%s",
		playerLabel(player),
		tostring(weaponId),
		st.mag,
		st.reserve,
		tostring(st.reloading)
	))

	Net.FXEvent:FireClient(player, {
		type = "Ammo",
		weaponId = weaponId,
		mag = st.mag,
		reserve = st.reserve,
		reloading = st.reloading,
		reloadEnd = st.reloadEnd,
	})
end

local function ensureAmmoHandshake(player: Player, weaponId: string, weaponCfg: any)
	ammoHandshakeByPlayer[player] = ammoHandshakeByPlayer[player] or {}
	if ammoHandshakeByPlayer[player][weaponId] then
		return
	end
	log:trace(string.format("Sending ammo handshake -> player=%s weaponId=%s", playerLabel(player), tostring(weaponId)))
	local st = getAmmoState(player, weaponId, weaponCfg)
	fireAmmoUpdate(player, weaponId, st)
end

local function forceAmmoSync(player: Player, weaponId: string, weaponCfg: any, reason: string)
	log:info(string.format(
		"Force ammo sync -> player=%s weaponId=%s reason=%s",
		playerLabel(player),
		tostring(weaponId),
		tostring(reason)
	))
	local st = getAmmoState(player, weaponId, weaponCfg)
	fireAmmoUpdate(player, weaponId, st)
end

local function canShoot(player: Player, weaponId: string, rpm: number, rofTolerance: number?): boolean
	lastShotAt[player] = lastShotAt[player] or {}
	local now = os.clock()
	local last = lastShotAt[player][weaponId] or 0
	local interval = 60 / math.max(rpm, 1)
	local jitterAllowance = interval * math.clamp(tonumber(rofTolerance) or 0, 0, 0.5)
	if now - last < (interval - jitterAllowance) then
		return false
	end
	lastShotAt[player][weaponId] = now
	return true
end

local function sanitizeOrigin(origin: any, char: Model, hrp: BasePart, maxOffset: number): Vector3?
	if typeof(origin) ~= "Vector3" then return nil end
	local head = char:FindFirstChild("Head") :: BasePart?
	local ref = (head and head.Position) or hrp.Position
	if (origin - ref).Magnitude > maxOffset then
		return ref
	end
	return origin
end

local function sanitizeDir(dir: any): Vector3?
	if typeof(dir) ~= "Vector3" then return nil end
	if dir.Magnitude < 0.001 then return nil end
	return dir.Unit
end

local function findMuzzle(char: Model, weaponCfg: any): Attachment?
	local mount = weaponCfg.mount or {}
	local gunName = mount.gunModelName or "SoldierGun"
	local muzzleName = mount.muzzleAttachmentName or "Muzzle"

	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("Model") and inst.Name == gunName then
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("Attachment") and d.Name == muzzleName then
					return d
				end
			end
		end
	end
	return nil
end

local function logRejection(player: Player, reason: string, payload: any)
	local now = os.clock()
	local state = rejectionCountByReason[reason]
	if not state then
		state = {count = 0, lastLogAt = 0}
		rejectionCountByReason[reason] = state
	end
	state.count += 1

	local shouldLog = state.count == 1 or (now - state.lastLogAt) >= 5 or (state.count % 25) == 0
	if not shouldLog then
		return
	end
	state.lastLogAt = now

	local shotId = if type(payload) == "table" and type(payload.shotId) == "string" then payload.shotId else "n/a"
	log:warn(string.format(
		"Shoot rejected -> player=%s shotId=%s reason=%s count=%d",
		playerLabel(player),
		tostring(shotId),
		tostring(reason),
		state.count
	))
	warn(string.format(
		"[GW][CombatReject] player=%s userId=%d shotId=%s reason=%s count=%d",
		player.Name,
		player.UserId,
		shotId,
		reason,
		state.count
	))
end


local function getShotId(payload: any): string?
	if type(payload) ~= "table" then return nil end
	if type(payload.shotId) == "string" and payload.shotId ~= "" then
		return payload.shotId
	end
	return nil
end

local function hasProcessedDamageShot(player: Player, shotId: string?): boolean
	if not shotId then return false end
	local byShot = processedDamageShotByPlayer[player]
	return byShot ~= nil and byShot[shotId] == true
end

local function markProcessedDamageShot(player: Player, shotId: string?)
	if not shotId then return end
	processedDamageShotByPlayer[player] = processedDamageShotByPlayer[player] or {}
	processedDamageShotByPlayer[player][shotId] = true
end
local function validateClaimedHit(player: Player, payload: any, char: Model, hrp: BasePart, weaponId: string, weaponCfg: any): (boolean, string?, Vector3?, Vector3?, Vector3?, RaycastResult?)
	local fire = weaponCfg.fire or {}
	local netCfg = weaponCfg.net or {}
	local rpm = tonumber(fire.rpm) or 420
	if not canShoot(player, weaponId, rpm, netCfg.rofTolerance) then
		return false, "cadence_rpm"
	end

	local range = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.range) or 800
	local originMax = tonumber(netCfg.originMaxOffsetFromHead) or 20
	local origin = sanitizeOrigin(payload.origin, char, hrp, originMax)
	if not origin then
		return false, "origin_invalid", nil, nil, nil, nil
	end

	local muzzle = findMuzzle(char, weaponCfg)
	local muzzlePos = muzzle and muzzle.WorldPosition or hrp.Position
	local muzzleMaxOffset = tonumber(netCfg.muzzleMaxOffset) or 14
	if (origin - muzzlePos).Magnitude > muzzleMaxOffset then
		return false, "origin_muzzle_offset", nil, nil, nil, nil
	end

	local rawDir = payload.direction or payload.dir
	if typeof(rawDir) ~= "Vector3" then
		return false, "dir_invalid_type", nil, nil, nil, nil
	end
	local rawMagnitude = rawDir.Magnitude
	if rawMagnitude < 0.001 or rawMagnitude > 10_000 then
		return false, "dir_invalid_magnitude", nil, nil, nil, nil
	end

	local dir = sanitizeDir(rawDir)
	if not dir then
		return false, "dir_invalid", nil, nil, nil, nil
	end

	local claimedHitPosition = payload.hitPos or payload.claimedHitPosition
	local clampedHitPos: Vector3? = nil
	if claimedHitPosition ~= nil then
		if typeof(claimedHitPosition) ~= "Vector3" then
			return false, "claimed_hit_invalid_type", nil, nil, nil, nil
		end
		local toHit = claimedHitPosition - origin
		local hitDist = toHit.Magnitude
		if hitDist < 0.001 then
			return false, "claimed_hit_too_close", nil, nil, nil, nil
		end
		if hitDist > (range + 16) then
			return false, "claimed_hit_too_far", nil, nil, nil, nil
		end

		local maxConeAngle = math.rad(tonumber(netCfg.maxConeAngle) or 6)
		local expectedDir = toHit.Unit
		local coneDot = math.clamp(dir:Dot(expectedDir), -1, 1)
		local coneAngle = math.acos(coneDot)
		if coneAngle > maxConeAngle then
			return false, "direction_cone", nil, nil, nil, nil
		end

		local clampedDist = math.min(hitDist, range)
		clampedHitPos = origin + expectedDir * clampedDist

		local losTolerance = tonumber(netCfg.losTolerance) or tonumber(netCfg.recastHitPosTolerance) or 12
		local function hasClearLine(lineStart: Vector3): boolean
			local losDir = clampedHitPos - lineStart
			local losDist = losDir.Magnitude
			if losDist < 0.001 then
				return true
			end
			local losResult = RaycastUtil.hitscan({char}, lineStart, losDir.Unit, losDist)
			if not losResult then
				return true
			end
			return (losResult.Position - clampedHitPos).Magnitude <= losTolerance
		end

		if not hasClearLine(muzzlePos) then
			return false, "los_muzzle_blocked", nil, nil, nil, nil
		end
		if not hasClearLine(origin) then
			return false, "los_origin_blocked", nil, nil, nil, nil
		end
	end

	local result = RaycastUtil.hitscan({char}, origin, dir, range)
	if claimedHitPosition and result then
		local reconTolerance = tonumber(netCfg.recastHitPosTolerance) or 12
		local reconPos = clampedHitPos or claimedHitPosition
		if (reconPos - result.Position).Magnitude > reconTolerance then
			return false, "recast_mismatch", nil, nil, nil, nil
		end
	end

	if claimedHitPosition and not result then
		return false, "claimed_hit_without_geometry", nil, nil, nil, nil
	end

	if result and result.Instance then
		local hum = RaycastUtil.findHumanoidFromHit(result.Instance)
		if hum then
			if hum == char:FindFirstChildOfClass("Humanoid") then
				return false, "target_self", nil, nil, nil, nil
			end
			if DamageUtil.isFriendly(player, hum, (netCfg.allowFriendlyFire == true)) then
				return false, "target_friendly", nil, nil, nil, nil
			end
		end
	end

	return true, nil, origin, dir, clampedHitPos, result
end

local function processShoot(player: Player, payload: any)
	local weaponId = getWeaponId(player)
	local weaponCfg = Weapons.Get(weaponId)
	local shotId = getShotId(payload)
	log:info(string.format(
		"Shoot request received -> player=%s weaponId=%s shotId=%s",
		playerLabel(player),
		tostring(weaponId),
		tostring(shotId)
	))
	ensureAmmoHandshake(player, weaponId, weaponCfg)

	local char, shooterHum, hrp = getAlive(player)
	if not char then
		log:warn("Shoot blocked: player not alive/valid character")
		return
	end

	local st = getAmmoState(player, weaponId, weaponCfg)
	if st.reloading and os.clock() < st.reloadEnd then
		log:trace(string.format("Shoot blocked: reloading=true reloadEnd=%.3f", st.reloadEnd))
		return
	end
	st.reloading = false

	if st.mag <= 0 then
		log:warn("Shoot blocked: no ammo in magazine")
		fireAmmoUpdate(player, weaponId, st)
		Net.FXEvent:FireClient(player, { type="DryFire", weaponId = weaponId })
		return
	end

	local muzzle = findMuzzle(char, weaponCfg)
	local muzzlePos = muzzle and muzzle.WorldPosition or hrp.Position

	local netCfg = weaponCfg.net or {}
	log:trace("Shoot validation: cadence/state/plausibility started")
	local ok, reason, origin, dir, _clampedHitPos, validatedResult = validateClaimedHit(player, payload, char, hrp, weaponId, weaponCfg)
	if not ok or not origin or not dir then
		log:warn(string.format("Shoot rejected by validation reason=%s shotId=%s", tostring(reason), tostring(shotId)))
		logRejection(player, reason or "validation_unknown", payload)
		local range = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.range) or 800
		local fallbackOrigin = hrp.Position
		local fallbackDir = Vector3.new(0, 0, -1)
		if typeof(payload.origin) == "Vector3" then
			local originMax = tonumber(netCfg.originMaxOffsetFromHead) or 20
			local sanitized = sanitizeOrigin(payload.origin, char, hrp, originMax)
			if sanitized then
				fallbackOrigin = sanitized
			end
		end
		if typeof(payload.direction) == "Vector3" and payload.direction.Magnitude >= 0.001 then
			fallbackDir = payload.direction.Unit
		end
		Net.FXEvent:FireAllClients({
			type = "Shot",
			weaponId = weaponId,
			shooterUserId = player.UserId,
			startPos = muzzlePos,
			hitPos = fallbackOrigin + fallbackDir * range,
			hitNormal = Vector3.new(0, 1, 0),
			didHit = false,
			shotId = shotId,
			rejected = true,
			reason = reason,
		})
		Net.ReplicateShot:FireAllClients({
			shooterUserId = player.UserId,
			weaponId = weaponId,
			startPos = muzzlePos,
			hitPos = fallbackOrigin + fallbackDir * range,
			didHit = false,
			rejected = true,
		})
		return
	end
	log:info(string.format("Shoot validation passed shotId=%s", tostring(shotId)))

	-- gastar bala (server-authoritative)
	st.mag -= 1
	log:trace(string.format("Ammo consumed -> mag=%d reserve=%d", st.mag, st.reserve))
	fireAmmoUpdate(player, weaponId, st)

	if weaponCfg.kind == "Hitscan" then
		local range = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.range) or 800
		local result = validatedResult or RaycastUtil.hitscan({char}, origin, dir, range)
		local hitPos = result and result.Position or (origin + dir * range)
		local hitNormal = result and result.Normal or Vector3.new(0,1,0)
		local didHit = (result ~= nil)
		if didHit then
			log:info(string.format("Raycast result=hit shotId=%s", tostring(shotId)))
		else
			log:info(string.format("Raycast result=miss shotId=%s", tostring(shotId)))
		end

		local didDamage = false
		local didKill = false
		local targetHum: Humanoid? = nil
		local damageApplied = 0

		if result and result.Instance and not hasProcessedDamageShot(player, shotId) then
			local hum, _model = RaycastUtil.findHumanoidFromHit(result.Instance)
			if hum and hum ~= shooterHum and hum.Health > 0 then
				if not DamageUtil.isFriendly(player, hum, (netCfg.allowFriendlyFire == true)) then
					local baseDamage = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.damage) or 0
					local dist = (hitPos - muzzlePos).Magnitude
					local dmg = DamageUtil.computeFalloff(baseDamage, dist, weaponCfg.hitscan and weaponCfg.hitscan.falloff)
					dmg = math.max(0, math.floor(dmg + 0.5))

					if dmg > 0 then
						local pre = hum.Health
						hum:TakeDamage(dmg)
						local post = hum.Health
						damageApplied = math.max(0, pre - post)
						didDamage = damageApplied > 0
						targetHum = hum

						markProcessedDamageShot(player, shotId)

						if pre > 0 and post <= 0 then
							local now = os.clock()
							local last = deathLock[hum] or 0
							if now - last > 0.25 then
								deathLock[hum] = now
								didKill = true
							end
						end
					end
				end
			end
		end

		-- FX para TODOS
		Net.FXEvent:FireAllClients({
			type = "Shot",
			weaponId = weaponId,
			shooterUserId = player.UserId,
			startPos = muzzlePos,
			hitPos = hitPos,
			hitNormal = hitNormal,
			didHit = didHit,
			shotId = shotId,
			clientShotTime = payload.clientShotTime,
			claimedHitPart = payload.claimedHitPart,
			claimedHitPosition = payload.claimedHitPosition,
		})
		Net.ReplicateShot:FireAllClients({
			shooterUserId = player.UserId,
			weaponId = weaponId,
			startPos = muzzlePos,
			hitPos = hitPos,
			hitNormal = hitNormal,
			didHit = didHit,
		})

		-- HitConfirm al tirador
		if didDamage then
			log:info(string.format("Damage applied -> shotId=%s damage=%d kill=%s", tostring(shotId), damageApplied, tostring(didKill)))
			Net.FXEvent:FireClient(player, {
				type = "HitConfirm",
				weaponId = weaponId,
				kill = didKill,
				damage = damageApplied,
				targetName = targetHum and (targetHum.Parent and targetHum.Parent.Name) or "Target",
			})
		end

		-- KillFeed global
		if didKill and targetHum then
			Net.FXEvent:FireAllClients({
				type = "KillFeed",
				killerUserId = player.UserId,
				killerName = player.DisplayName ~= "" and player.DisplayName or player.Name,
				victimName = targetHum.Parent and targetHum.Parent.Name or "Victim",
				weaponId = weaponId,
				weaponDisplayName = weaponCfg.displayName or weaponId,
				timestamp = os.time(),
			})
		end
	else
		log:warn(string.format("Weapon kind not handled by processShoot: %s", tostring(weaponCfg.kind)))
	end
end

Net.ReportHit.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" then
		log:warn("ReportHit ignored: payload is not table")
		return
	end

	local weaponId = getWeaponId(player)
	local weaponCfg = Weapons.Get(weaponId)
	local shotId = getShotId(payload)
	log:trace(string.format("ReportHit received -> player=%s weaponId=%s shotId=%s", playerLabel(player), tostring(weaponId), tostring(shotId)))

	local char, shooterHum, hrp = getAlive(player)
	if not char then
		log:trace("ReportHit ignored: player not alive")
		return
	end

	if hasProcessedDamageShot(player, shotId) then
		log:trace(string.format("ReportHit ignored: shot already processed shotId=%s", tostring(shotId)))
		return
	end

	local ok, reason, _, _, _, validatedResult = validateClaimedHit(player, payload, char, hrp, weaponId, weaponCfg)
	if not ok then
		log:warn(string.format("ReportHit validation failed reason=%s shotId=%s", tostring(reason), tostring(shotId)))
		logRejection(player, reason or "validation_unknown", payload)
		return
	end

	if not validatedResult or not validatedResult.Instance then
		log:trace(string.format("ReportHit had no validated hit instance shotId=%s", tostring(shotId)))
		return
	end

	local netCfg = weaponCfg.net or {}
	local hum = RaycastUtil.findHumanoidFromHit(validatedResult.Instance)
	if not hum or hum == shooterHum or hum.Health <= 0 then
		log:warn(string.format("ReportHit target invalid shotId=%s", tostring(shotId)))
		logRejection(player, "target_invalid", payload)
		return
	end

	if DamageUtil.isFriendly(player, hum, (netCfg.allowFriendlyFire == true)) then
		log:warn(string.format("ReportHit target rejected friendly shotId=%s", tostring(shotId)))
		logRejection(player, "target_friendly", payload)
		return
	end

	local muzzle = findMuzzle(char, weaponCfg)
	local muzzlePos = muzzle and muzzle.WorldPosition or hrp.Position
	local baseDamage = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.damage) or 0
	local dist = (validatedResult.Position - muzzlePos).Magnitude
	local dmg = DamageUtil.computeFalloff(baseDamage, dist, weaponCfg.hitscan and weaponCfg.hitscan.falloff)
	dmg = math.max(0, math.floor(dmg + 0.5))
	if dmg <= 0 then
		log:trace(string.format("ReportHit damage resolved to 0 shotId=%s", tostring(shotId)))
		return
	end

	local pre = hum.Health
	hum:TakeDamage(dmg)
	local post = hum.Health
	local damageApplied = math.max(0, pre - post)
	if damageApplied <= 0 then
		log:trace(string.format("ReportHit applied no health delta shotId=%s", tostring(shotId)))
		return
	end
	markProcessedDamageShot(player, shotId)
	log:info(string.format("ReportHit damage applied -> shotId=%s damage=%d", tostring(shotId), damageApplied))

	local didKill = false
	if pre > 0 and post <= 0 then
		local now = os.clock()
		local last = deathLock[hum] or 0
		if now - last > 0.25 then
			deathLock[hum] = now
			didKill = true
		end
	end

	Net.FXEvent:FireClient(player, {
		type = "HitConfirm",
		weaponId = weaponId,
		kill = didKill,
		damage = damageApplied,
		targetName = hum.Parent and hum.Parent.Name or "Target",
	})

	if didKill then
		Net.FXEvent:FireAllClients({
			type = "KillFeed",
			killerUserId = player.UserId,
			killerName = player.DisplayName ~= "" and player.DisplayName or player.Name,
			victimName = hum.Parent and hum.Parent.Name or "Victim",
			weaponId = weaponId,
			weaponDisplayName = weaponCfg.displayName or weaponId,
			timestamp = os.time(),
		})
	end
end)

local function processReload(player: Player, payload: any)
	local weaponId = getWeaponId(player)
	local weaponCfg = Weapons.Get(weaponId)
	log:trace(string.format("Reload request received -> player=%s weaponId=%s", playerLabel(player), tostring(weaponId)))
	ensureAmmoHandshake(player, weaponId, weaponCfg)
	local char, hum, hrp = getAlive(player)
	if not char then
		log:warn("Reload blocked: player not alive")
		return
	end

	local st = getAmmoState(player, weaponId, weaponCfg)

	local magSize = tonumber(weaponCfg.ammo and weaponCfg.ammo.magSize) or 30
	local reloadTime = tonumber(weaponCfg.ammo and weaponCfg.ammo.reloadTime) or 2.0

	if st.reloading and os.clock() < st.reloadEnd then
		log:trace("Reload blocked: already reloading")
		return
	end
	if st.mag >= magSize then
		log:trace("Reload blocked: mag already full")
		return
	end
	if st.reserve <= 0 then
		log:trace("Reload blocked: reserve empty")
		return
	end

	st.reloading = true
	st.reloadEnd = os.clock() + reloadTime
	log:info(string.format("Reload started -> player=%s weaponId=%s reloadTime=%.2f", playerLabel(player), tostring(weaponId), reloadTime))
	fireAmmoUpdate(player, weaponId, st)

	Net.FXEvent:FireClient(player, { type="ReloadStart", weaponId = weaponId, reloadTime = reloadTime })

	task.delay(reloadTime, function()
		if not player.Parent then
			log:trace("Reload finalize skipped: player no longer valid")
			return
		end
		local char2, hum2 = getAlive(player)
		if not char2 then
			st.reloading = false
			fireAmmoUpdate(player, weaponId, st)
			log:trace("Reload canceled: player dead/invalid at finalize")
			return
		end

		-- aplica reload
		local need = magSize - st.mag
		local take = math.min(need, st.reserve)
		st.mag += take
		st.reserve -= take
		st.reloading = false
		st.reloadEnd = 0
		fireAmmoUpdate(player, weaponId, st)
		Net.FXEvent:FireClient(player, { type="ReloadEnd", weaponId = weaponId })
		log:info(string.format("Reload completed -> player=%s weaponId=%s mag=%d reserve=%d", playerLabel(player), tostring(weaponId), st.mag, st.reserve))
	end)
end

Net.CombatRequest.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" then
		log:warn("CombatRequest ignored: payload is not table")
		return
	end

	local weaponId = getWeaponId(player)
	local weaponCfg = Weapons.Get(weaponId)
	ensureAmmoHandshake(player, weaponId, weaponCfg)

	local action = payload.action
	local shotId = getShotId(payload)
	log:info(string.format(
		"CombatRequest received -> player=%s action=%s weaponId=%s shotId=%s payloadWeaponId=%s",
		playerLabel(player),
		tostring(action),
		tostring(weaponId),
		tostring(shotId),
		tostring(payload.weaponId)
	))
	if action == "Shoot" then
		processShoot(player, payload)
	elseif action == "Reload" then
		processReload(player, payload)
	elseif action == "DryTrigger" then
		log:trace(string.format("DryTrigger received -> player=%s weaponId=%s reason=%s", playerLabel(player), tostring(weaponId), tostring(payload.reason)))
		forceAmmoSync(player, weaponId, weaponCfg, tostring(payload.reason))
	else
		log:warn(string.format("CombatRequest ignored: unknown action=%s", tostring(action)))
	end
end)

local function bindPlayer(player: Player)
	log:trace("Binding combat state for player " .. playerLabel(player))
	player.CharacterAdded:Connect(function()
		log:trace("CharacterAdded -> ammo handshake scheduled for " .. playerLabel(player))
		task.defer(function()
			if not player.Parent then
				log:trace("Skipped deferred handshake: player no longer valid")
				return
			end
			local weaponId = getWeaponId(player)
			local weaponCfg = Weapons.Get(weaponId)
			forceAmmoSync(player, weaponId, weaponCfg, "CharacterAdded")
		end)
	end)

	player:GetAttributeChangedSignal("WeaponId"):Connect(function()
		if not player.Parent then
			log:trace("WeaponId changed but player no longer valid")
			return
		end
		log:trace("WeaponId attribute changed on server for " .. playerLabel(player))
		local weaponId = getWeaponId(player)
		local weaponCfg = Weapons.Get(weaponId)
		forceAmmoSync(player, weaponId, weaponCfg, "WeaponChanged")
	end)
end

Players.PlayerAdded:Connect(bindPlayer)

for _, p in ipairs(Players:GetPlayers()) do
	bindPlayer(p)
	local weaponId = getWeaponId(p)
	local weaponCfg = Weapons.Get(weaponId)
	forceAmmoSync(p, weaponId, weaponCfg, "ExistingPlayerBootstrap")
end

Players.PlayerRemoving:Connect(function(player)
	lastShotAt[player] = nil
	ammoByPlayer[player] = nil
	ammoHandshakeByPlayer[player] = nil
	processedDamageShotByPlayer[player] = nil
end)

log:info("CombatService active (shoot tracing enabled)")
