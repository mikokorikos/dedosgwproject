--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)
local LocalEffectsBus = require(script.Parent.LocalEffectsBus)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Combat")

local firingState = {
	triggerHeld = false,
	isFiringLoopActive = false,
	fireModeAuto = false,
	nextShotAt = 0,
	fireInterval = 0,
}
local NO_CAMERA_BACKOFF = 1 / 60
local shotSequence = 0
local spreadRng = Random.new()
local lastRateBlockLogAt = 0
local RATE_BLOCK_LOG_INTERVAL = 0.25

local localAmmo = {
	initialized = false,
	mag = 0,
	reserve = 0,
	reloading = false,
	reloadEnd = 0,
	weaponId = Weapons.DefaultId,
}

local function ammoSnapshot(): string
	return string.format(
		"weaponId=%s initialized=%s mag=%s reserve=%s reloading=%s reloadEnd=%.3f",
		tostring(localAmmo.weaponId),
		tostring(localAmmo.initialized),
		tostring(localAmmo.mag),
		tostring(localAmmo.reserve),
		tostring(localAmmo.reloading),
		type(localAmmo.reloadEnd) == "number" and localAmmo.reloadEnd or 0
	)
end

local function canUseAmmoState(): boolean
	return localAmmo.initialized == true
end

local function resetAmmoInitializationForWeapon()
	localAmmo.initialized = false
	localAmmo.reloading = false
	localAmmo.reloadEnd = 0
	log:trace("Ammo initialization reset for weapon change")
end

local function getWeaponCfg()
	local rawId = player:GetAttribute("WeaponId")
	local id = if typeof(rawId) == "string" then rawId else Weapons.DefaultId
	localAmmo.weaponId = id
	log:trace("weaponId resolved = " .. tostring(id))
	return Weapons.Get(id)
end

local function getAimRay()
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local vp = cam.ViewportSize
	local cx, cy = vp.X * 0.5, vp.Y * 0.5
	local ray = cam:ViewportPointToRay(cx, cy)
	return ray.Origin, ray.Direction
end

local function getSpreadAngleDeg(weaponCfg): number
	local netCfg = weaponCfg.net
	if type(netCfg) == "table" and typeof(netCfg.maxConeAngle) == "number" then
		return math.max(netCfg.maxConeAngle, 0)
	end

	return 0
end

local function applySpread(dir: Vector3, spreadAngleDeg: number): Vector3
	local unitDir = dir.Unit
	if spreadAngleDeg <= 0 then
		return unitDir
	end

	local coneRad = math.rad(spreadAngleDeg)
	local yaw = spreadRng:NextNumber(0, math.pi * 2)
	local pitch = spreadRng:NextNumber(0, coneRad)

	local axis = (math.abs(unitDir:Dot(Vector3.yAxis)) > 0.98) and Vector3.xAxis or Vector3.yAxis
	local right = (unitDir:Cross(axis)).Unit
	local up = (right:Cross(unitDir)).Unit

	local offset = (right * math.cos(yaw) + up * math.sin(yaw)) * math.tan(pitch)
	return (unitDir + offset).Unit
end

local function castShot(origin: Vector3, dir: Vector3, maxDistance: number): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local char = player.Character
	params.FilterDescendantsInstances = char and {char} or {}
	return workspace:Raycast(origin, dir.Unit * maxDistance, params)
end

local function isTyping(): boolean
	local typing = UIS:GetFocusedTextBox() ~= nil
	log:trace("TextBox active = " .. tostring(typing))
	return typing
end

local function tryShoot(): "ok" | "blocked_reload" | "blocked_ammo" | "no_camera"
	local weaponCfg = getWeaponCfg()
	log:trace("Shoot attempt: " .. ammoSnapshot())

	if not canUseAmmoState() then
		log:warn("Shoot blocked: local ammo state not initialized")
		Net.CombatRequest:FireServer({
			action = "DryTrigger",
			weaponId = localAmmo.weaponId,
			reason = "AmmoUninitialized",
		})
		log:trace("DryTrigger sent to request ammo sync")
		return "blocked_reload"
	end

	local now = os.clock()
	if localAmmo.reloading and now < localAmmo.reloadEnd then
		log:trace(string.format("Shoot blocked: reloading (now=%.3f < reloadEnd=%.3f)", now, localAmmo.reloadEnd))
		return "blocked_reload"
	end

	if localAmmo.mag <= 0 then
		log:warn("Shoot blocked: ammo is 0")
		Net.CombatRequest:FireServer({ action = "DryTrigger", weaponId = localAmmo.weaponId, reason = "EmptyMag" })
		return "blocked_ammo"
	end

	local origin, dir = getAimRay()
	if not origin or not dir then
		log:warn("Shoot blocked: aim ray unavailable (no camera)")
		return "no_camera"
	end
	log:trace("Aim direction calculated")

	local spreadAngle = getSpreadAngleDeg(weaponCfg)
	local spreadDir = applySpread(dir, spreadAngle)
	log:trace(string.format("Spread applied (deg=%.2f)", spreadAngle))

	local range = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.range) or 2000
	local shotResult = castShot(origin, spreadDir, range)
	local hitPos = if shotResult then shotResult.Position else origin + spreadDir * range
	local clientShotTime = os.clock()

	localAmmo.mag -= 1
	shotSequence += 1
	local shotId = string.format("%d-%d", player.UserId, shotSequence)
	log:info("shotId generated = " .. shotId)

	LocalEffectsBus.EmitShot({
		type = "Shot",
		weaponId = localAmmo.weaponId,
		shooterUserId = player.UserId,
		shotSeq = shotSequence,
		shotId = shotId,
		clientShotTime = clientShotTime,
		startPos = origin,
		origin = origin,
		direction = spreadDir,
		hitPos = hitPos,
		hitNormal = shotResult and shotResult.Normal or nil,
		didHit = shotResult ~= nil,
		hitInstance = shotResult and shotResult.Instance or nil,
	})

	Net.CombatRequest:FireServer({
		action = "Shoot",
		weaponId = localAmmo.weaponId,
		shotId = shotId,
		clientShotTime = clientShotTime,
		origin = origin,
		direction = spreadDir,
		claimedHitPart = shotResult and shotResult.Instance.Name or nil,
		claimedHitPosition = shotResult and shotResult.Position or nil,
	})
	log:info("Shoot request sent to server shotId=" .. shotId)

	Net.ReportHit:FireServer({
		shotSeq = shotSequence,
		shotId = shotId,
		clientShotTime = clientShotTime,
		weaponId = localAmmo.weaponId,
		origin = origin,
		dir = spreadDir,
		hitInstance = shotResult and shotResult.Instance or nil,
		hitPos = shotResult and shotResult.Position or nil,
		hitNormal = shotResult and shotResult.Normal or nil,
	})
	log:trace("ReportHit sent shotId=" .. shotId)

	if shotResult then
		log:trace("Client cast result: hit")
	else
		log:trace("Client cast result: miss")
	end

	return "ok"
end

local function tryReload()
	if not canUseAmmoState() then
		log:trace("Reload blocked: ammo state not initialized")
		return
	end
	local weaponCfg = getWeaponCfg()
	local magSize = tonumber(weaponCfg.ammo and weaponCfg.ammo.magSize) or 30
	if localAmmo.reloading and os.clock() < localAmmo.reloadEnd then
		log:trace("Reload blocked: already reloading")
		return
	end
	if localAmmo.mag >= magSize then
		log:trace("Reload blocked: magazine already full")
		return
	end
	if localAmmo.reserve <= 0 then
		log:trace("Reload blocked: reserve ammo empty")
		return
	end

	Net.CombatRequest:FireServer({
		action = "Reload",
		weaponId = localAmmo.weaponId,
	})
	log:info("Reload request sent weaponId=" .. tostring(localAmmo.weaponId))
end

local function stopFiringLoop()
	if firingState.triggerHeld or firingState.isFiringLoopActive then
		log:trace("Firing loop stopped")
	end
	firingState.triggerHeld = false
	firingState.isFiringLoopActive = false
end

local function onShotAttempt(shotResult: "ok" | "blocked_reload" | "blocked_ammo" | "no_camera", now: number)
	log:trace("Shot attempt result = " .. tostring(shotResult))
	if shotResult == "no_camera" then
		firingState.nextShotAt = now + NO_CAMERA_BACKOFF
	else
		firingState.nextShotAt = now + firingState.fireInterval
	end
end

local function fireImmediateShot(now: number)
	local shotResult = tryShoot()
	onShotAttempt(shotResult, now)
end

local function bindHumanoidDeath(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		log:trace("Humanoid not found for death binding")
		return
	end

	humanoid.Died:Connect(function()
		log:trace("Humanoid died -> stopping fire loop")
		stopFiringLoop()
	end)
end

player.CharacterAdded:Connect(function(character)
	log:trace("CharacterAdded in CombatController")
	stopFiringLoop()
	resetAmmoInitializationForWeapon()
	bindHumanoidDeath(character)
end)

if player.Character then
	bindHumanoidDeath(player.Character)
end

player:GetAttributeChangedSignal("WeaponId"):Connect(function()
	log:trace("WeaponId attribute changed")
	stopFiringLoop()
	getWeaponCfg()
	resetAmmoInitializationForWeapon()
end)

UIS.InputBegan:Connect(function(input, gameProcessed)
	local isMouse1 = input.UserInputType == Enum.UserInputType.MouseButton1
	if isMouse1 then
		log:info("MouseButton1 detected")
	end

	local typing = isTyping()
	if isMouse1 then
		log:trace("gameProcessed = " .. tostring(gameProcessed))
		log:trace("isTyping = " .. tostring(typing))
	end

	if gameProcessed or typing then
		if isMouse1 then
			log:trace("MouseButton1 blocked by input guard")
		end
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if firingState.triggerHeld then
			log:trace("MouseButton1 ignored: trigger already held")
			return
		end

		local rawWeaponId = player:GetAttribute("WeaponId")
		local equipped = player.Character ~= nil and typeof(rawWeaponId) == "string" and rawWeaponId ~= ""
		log:info("weapon equipped = " .. tostring(equipped))

		firingState.triggerHeld = true

		local weaponCfg = getWeaponCfg()
		firingState.fireModeAuto = (weaponCfg.fire and weaponCfg.fire.auto) == true
		local rpm = tonumber(weaponCfg.fire and weaponCfg.fire.rpm) or 420
		firingState.fireInterval = 60 / math.max(rpm, 1)
		log:trace(string.format("fireModeAuto=%s rpm=%.2f interval=%.4f", tostring(firingState.fireModeAuto), rpm, firingState.fireInterval))
		log:trace("ammo state before fire: " .. ammoSnapshot())

		local now = os.clock()
		fireImmediateShot(now)
		firingState.isFiringLoopActive = firingState.fireModeAuto
	elseif input.KeyCode == Enum.KeyCode.R then
		log:trace("Reload key detected")
		tryReload()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		log:trace("MouseButton1 released")
		stopFiringLoop()
	end
end)

UIS.WindowFocusReleased:Connect(function()
	log:trace("Window focus released -> stop firing loop")
	stopFiringLoop()
end)

RunService.Heartbeat:Connect(function()
	if not firingState.isFiringLoopActive then
		return
	end
	if not firingState.triggerHeld then
		stopFiringLoop()
		return
	end

	local now = os.clock()
	if now < firingState.nextShotAt then
		if now - lastRateBlockLogAt >= RATE_BLOCK_LOG_INTERVAL then
			lastRateBlockLogAt = now
			log:trace(string.format("fire rate block active (nextShotAt=%.4f now=%.4f)", firingState.nextShotAt, now))
		end
		return
	end

	local shotResult = tryShoot()
	onShotAttempt(shotResult, now)
end)

Net.FXEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then
		return
	end
	if ev.type == "Ammo" then
		if ev.weaponId == localAmmo.weaponId then
			localAmmo.initialized = true
			localAmmo.mag = tonumber(ev.mag) or localAmmo.mag
			localAmmo.reserve = tonumber(ev.reserve) or localAmmo.reserve
			localAmmo.reloading = (ev.reloading == true)
			localAmmo.reloadEnd = tonumber(ev.reloadEnd) or 0
			log:trace("Ammo sync received: " .. ammoSnapshot())
		else
			log:trace(string.format("Ammo sync ignored due weapon mismatch (event=%s local=%s)", tostring(ev.weaponId), tostring(localAmmo.weaponId)))
		end
	elseif ev.type == "ReloadStart" then
		localAmmo.reloading = true
		localAmmo.reloadEnd = os.clock() + (tonumber(ev.reloadTime) or 0)
		log:trace("ReloadStart received")
	elseif ev.type == "ReloadEnd" then
		localAmmo.reloading = false
		localAmmo.reloadEnd = 0
		log:trace("ReloadEnd received")
	end
end)

log:info("CombatController ready (Shoot + Reload tracing enabled)")
