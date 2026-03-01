--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)
local RaycastUtil = require(RS.GW.Shared.RaycastUtil)
local DamageUtil = require(RS.GW.Shared.DamageUtil)

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
local rejectionCountByReason: {[string]: number} = {}

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
	return st
end

local function fireAmmoUpdate(player: Player, weaponId: string, st: AmmoState)
	ammoHandshakeByPlayer[player] = ammoHandshakeByPlayer[player] or {}
	ammoHandshakeByPlayer[player][weaponId] = true

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
	if ammoHandshakeByPlayer[player][weaponId] then return end
	local st = getAmmoState(player, weaponId, weaponCfg)
	fireAmmoUpdate(player, weaponId, st)
end

local function canShoot(player: Player, weaponId: string, rpm: number): boolean
	lastShotAt[player] = lastShotAt[player] or {}
	local now = os.clock()
	local last = lastShotAt[player][weaponId] or 0
	local interval = 60 / math.max(rpm, 1)
	if now - last < interval then
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
	rejectionCountByReason[reason] = (rejectionCountByReason[reason] or 0) + 1
	local shotId = if type(payload) == "table" and type(payload.shotId) == "string" then payload.shotId else "n/a"
	warn(string.format(
		"[GW][CombatReject] player=%s userId=%d shotId=%s reason=%s count=%d",
		player.Name,
		player.UserId,
		shotId,
		reason,
		rejectionCountByReason[reason]
	))
end

local function distPointToRay(point: Vector3, origin: Vector3, dirUnit: Vector3): number
	local t = math.max(0, (point - origin):Dot(dirUnit))
	local closest = origin + dirUnit * t
	return (point - closest).Magnitude
end

local function validateClaimedHit(player: Player, payload: any, char: Model, hrp: BasePart, weaponId: string, weaponCfg: any): (boolean, string?, Vector3?, Vector3?, RaycastResult?)
	local fire = weaponCfg.fire or {}
	local rpm = tonumber(fire.rpm) or 420
	if not canShoot(player, weaponId, rpm) then
		return false, "cadence_rpm"
	end

	local netCfg = weaponCfg.net or {}
	local range = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.range) or 800
	local originMax = tonumber(netCfg.originMaxOffsetFromHead) or 20
	local origin = sanitizeOrigin(payload.origin, char, hrp, originMax)
	if not origin then
		return false, "origin_invalid"
	end

	local rawDir = payload.direction
	if typeof(rawDir) ~= "Vector3" then
		return false, "dir_invalid_type"
	end
	local rawMagnitude = rawDir.Magnitude
	if rawMagnitude < 0.001 or rawMagnitude > 10_000 then
		return false, "dir_invalid_magnitude"
	end

	local dir = sanitizeDir(rawDir)
	if not dir then
		return false, "dir_invalid"
	end

	local claimedHitPosition = payload.claimedHitPosition
	if claimedHitPosition ~= nil then
		if typeof(claimedHitPosition) ~= "Vector3" then
			return false, "claimed_hit_invalid_type"
		end
		if (claimedHitPosition - origin).Magnitude > (range + 16) then
			return false, "claimed_hit_too_far"
		end
		local lineTolerance = tonumber(netCfg.claimedHitLineTolerance) or 8
		if distPointToRay(claimedHitPosition, origin, dir) > lineTolerance then
			return false, "claimed_hit_offline"
		end
	end

	local result = RaycastUtil.hitscan({char}, origin, dir, range)
	if claimedHitPosition and result then
		local reconTolerance = tonumber(netCfg.recastHitPosTolerance) or 12
		if (claimedHitPosition - result.Position).Magnitude > reconTolerance then
			return false, "recast_mismatch"
		end
	end

	if claimedHitPosition and not result then
		return false, "claimed_hit_without_geometry"
	end

	return true, nil, origin, dir, result
end

local function processShoot(player: Player, payload: any)
	local weaponId = getWeaponId(player)
	local weaponCfg = Weapons.Get(weaponId)
	ensureAmmoHandshake(player, weaponId, weaponCfg)

	local char, shooterHum, hrp = getAlive(player)
	if not char then return end

	local st = getAmmoState(player, weaponId, weaponCfg)
	if st.reloading and os.clock() < st.reloadEnd then
		return
	end
	st.reloading = false

	if st.mag <= 0 then
		fireAmmoUpdate(player, weaponId, st)
		Net.FXEvent:FireClient(player, { type="DryFire", weaponId = weaponId })
		return
	end

	local muzzle = findMuzzle(char, weaponCfg)
	local muzzlePos = muzzle and muzzle.WorldPosition or hrp.Position

	local netCfg = weaponCfg.net or {}
	local ok, reason, origin, dir, validatedResult = validateClaimedHit(player, payload, char, hrp, weaponId, weaponCfg)
	if not ok or not origin or not dir then
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
			shotId = payload.shotId,
			rejected = true,
			reason = reason,
		})
		return
	end

	-- gastar bala (server-authoritative)
	st.mag -= 1
	fireAmmoUpdate(player, weaponId, st)

	if weaponCfg.kind == "Hitscan" then
		local range = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.range) or 800
		local result = validatedResult or RaycastUtil.hitscan({char}, origin, dir, range)
		local hitPos = result and result.Position or (origin + dir * range)
		local hitNormal = result and result.Normal or Vector3.new(0,1,0)
		local didHit = (result ~= nil)

		local didDamage = false
		local didKill = false
		local targetHum: Humanoid? = nil
		local damageApplied = 0

		if result and result.Instance then
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
			shotId = payload.shotId,
			clientShotTime = payload.clientShotTime,
			claimedHitPart = payload.claimedHitPart,
			claimedHitPosition = payload.claimedHitPosition,
		})

		-- HitConfirm al tirador
		if didDamage then
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
	end
end

local function processReload(player: Player, payload: any)
	local weaponId = getWeaponId(player)
	local weaponCfg = Weapons.Get(weaponId)
	ensureAmmoHandshake(player, weaponId, weaponCfg)
	local char, hum, hrp = getAlive(player)
	if not char then return end

	local st = getAmmoState(player, weaponId, weaponCfg)

	local magSize = tonumber(weaponCfg.ammo and weaponCfg.ammo.magSize) or 30
	local reloadTime = tonumber(weaponCfg.ammo and weaponCfg.ammo.reloadTime) or 2.0

	if st.reloading and os.clock() < st.reloadEnd then return end
	if st.mag >= magSize then return end
	if st.reserve <= 0 then return end

	st.reloading = true
	st.reloadEnd = os.clock() + reloadTime
	fireAmmoUpdate(player, weaponId, st)

	Net.FXEvent:FireClient(player, { type="ReloadStart", weaponId = weaponId, reloadTime = reloadTime })

	task.delay(reloadTime, function()
		if not player.Parent then return end
		local char2, hum2 = getAlive(player)
		if not char2 then
			st.reloading = false
			fireAmmoUpdate(player, weaponId, st)
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
	end)
end

Net.CombatRequest.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" then return end

	local weaponId = getWeaponId(player)
	local weaponCfg = Weapons.Get(weaponId)
	ensureAmmoHandshake(player, weaponId, weaponCfg)

	local action = payload.action
	if action == "Shoot" then
		processShoot(player, payload)
	elseif action == "Reload" then
		processReload(player, payload)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not player.Parent then return end
			local weaponId = getWeaponId(player)
			local weaponCfg = Weapons.Get(weaponId)
			ensureAmmoHandshake(player, weaponId, weaponCfg)
		end)
	end)

	player:GetAttributeChangedSignal("WeaponId"):Connect(function()
		if not player.Parent then return end
		local weaponId = getWeaponId(player)
		local weaponCfg = Weapons.Get(weaponId)
		ensureAmmoHandshake(player, weaponId, weaponCfg)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastShotAt[player] = nil
	ammoByPlayer[player] = nil
	ammoHandshakeByPlayer[player] = nil
end)

print("[GW] CombatService activo.")
