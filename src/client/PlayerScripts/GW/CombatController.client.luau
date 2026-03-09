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
local lastAmmoSyncRequestAt = 0
local AMMO_SYNC_REQUEST_COOLDOWN = 0.20
local pendingFirstShotAfterInit = false

local localAmmo = {
	initialized = false,
	mag = 0,
	reserve = 0,
	reloading = false,
	reloadEnd = 0,
	weaponId = Weapons.DefaultId,
}

local function requestAmmoSync(reason: string)
	local now = os.clock()
	if now - lastAmmoSyncRequestAt < AMMO_SYNC_REQUEST_COOLDOWN then
		log:trace(string.format("Ammo sync request throttled reason=%s", tostring(reason)))
		return
	end
	lastAmmoSyncRequestAt = now
	Net.CombatRequest:FireServer({
		action = "DryTrigger",
		weaponId = localAmmo.weaponId,
		reason = reason,
	})
	log:info(string.format("DryTrigger sent to request ammo sync reason=%s weaponId=%s", tostring(reason), tostring(localAmmo.weaponId)))
end

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
	local previousInitialized = localAmmo.initialized
	localAmmo.initialized = false
	localAmmo.mag = 0
	localAmmo.reserve = 0
	localAmmo.reloading = false
	localAmmo.reloadEnd = 0
	log:trace(string.format("Ammo initialization reset (prevInitialized=%s)", tostring(previousInitialized)))
	pendingFirstShotAfterInit = false
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

local function findMuzzleAttachment(character: Model, weaponCfg: any): (Attachment?, string)
	local mount = weaponCfg.mount or {}
	local gunName = tostring(mount.gunModelName or "SoldierGun")
	local muzzleName = tostring(mount.muzzleAttachmentName or "Muzzle")

	local namedInGun: Attachment? = nil
	local namedFallback: Attachment? = nil
	local genericInGun: Attachment? = nil
	local genericFallback: Attachment? = nil

	for _, inst in ipairs(character:GetDescendants()) do
		if inst:IsA("Attachment") then
			local attachmentName = inst.Name
			local attachmentNameLower = string.lower(attachmentName)
			local inConfiguredGun = inst:FindFirstAncestor(gunName) ~= nil

			if attachmentName == muzzleName then
				if inConfiguredGun then
					namedInGun = namedInGun or inst
				else
					namedFallback = namedFallback or inst
				end
			end

			if attachmentNameLower == "muzzle" or attachmentNameLower == "muzzleattachment" or attachmentNameLower == "muzzlepoint" then
				if inConfiguredGun then
					genericInGun = genericInGun or inst
				else
					genericFallback = genericFallback or inst
				end
			end
		end
	end

	if namedInGun then
		return namedInGun, "named_in_gun"
	end
	if genericInGun then
		return genericInGun, "generic_in_gun"
	end
	if namedFallback then
		return namedFallback, "named_fallback"
	end
	if genericFallback then
		return genericFallback, "generic_fallback"
	end

	return nil, "missing"
end

local function getCharacterOriginFallback(character: Model?, cameraOrigin: Vector3): Vector3
	if character then
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head.Position
		end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			return hrp.Position
		end
	end
	return cameraOrigin
end

local function getAimPoint(cameraOrigin: Vector3, cameraDir: Vector3, range: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local char = player.Character
	params.FilterDescendantsInstances = char and {char} or {}
	local hit = workspace:Raycast(cameraOrigin, cameraDir * range, params)
	if hit then
		return hit.Position
	end
	return cameraOrigin + cameraDir * range
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

local function tryShoot(): "ok" | "blocked_uninitialized" | "blocked_reload" | "blocked_ammo" | "no_camera"
	local weaponCfg = getWeaponCfg()
	log:trace("Shoot attempt: " .. ammoSnapshot())

	if not canUseAmmoState() then
		log:warn("Shoot blocked: local ammo state not initialized")
		pendingFirstShotAfterInit = true
		requestAmmoSync("AmmoUninitialized")
		return "blocked_uninitialized"
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
	local cameraOrigin = origin
	local cameraDir = dir.Unit
	log:trace("Aim direction calculated")

	local range = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.range) or 2000
	local aimPoint = getAimPoint(cameraOrigin, cameraDir, range)

	local char = player.Character
	local muzzle: Attachment?
	local muzzleSource = "missing"
	if char then
		muzzle, muzzleSource = findMuzzleAttachment(char, weaponCfg)
	end
	if muzzle then
		log:trace("Muzzle found source=" .. tostring(muzzleSource))
		log:trace("Muzzle world position = " .. tostring(muzzle.WorldPosition))
	else
		log:warn("Muzzle not found; using fallback origin source=" .. tostring(muzzleSource))
	end
	log:trace("Camera origin = " .. tostring(cameraOrigin))
	log:trace("Aim point = " .. tostring(aimPoint))

	local shotOrigin = if muzzle then muzzle.WorldPosition else getCharacterOriginFallback(char, cameraOrigin)
	local toAim = aimPoint - shotOrigin
	local baseDir = if toAim.Magnitude > 0.001 then toAim.Unit else cameraDir

	local spreadAngle = getSpreadAngleDeg(weaponCfg)
	local spreadDir = applySpread(baseDir, spreadAngle)
	log:trace(string.format("Spread applied (deg=%.2f)", spreadAngle))
	log:trace("Shot origin final = " .. tostring(shotOrigin))
	log:trace("Shot direction final = " .. tostring(spreadDir))

	local shotResult = castShot(shotOrigin, spreadDir, range)
	local hitPos = if shotResult then shotResult.Position else shotOrigin + spreadDir * range
	local clientShotTime = os.clock()

	localAmmo.mag -= 1
	shotSequence += 1
	local shotId = string.format("%d-%d", player.UserId, shotSequence)
	log:info("shotId generated = " .. shotId)
	if pendingFirstShotAfterInit then
		log:info("First successful shot after ammo initialization")
		pendingFirstShotAfterInit = false
	end

	LocalEffectsBus.EmitShot({
		type = "Shot",
		weaponId = localAmmo.weaponId,
		shooterUserId = player.UserId,
		shotSeq = shotSequence,
		shotId = shotId,
		clientShotTime = clientShotTime,
		startPos = shotOrigin,
		origin = shotOrigin,
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
		origin = shotOrigin,
		direction = spreadDir,
		claimedHitPart = shotResult and shotResult.Instance.Name or nil,
		claimedHitPosition = shotResult and shotResult.Position or nil,
		muzzlePos = muzzle and muzzle.WorldPosition or nil,
		cameraOrigin = cameraOrigin,
		aimPoint = aimPoint,
	})
	log:info("Shoot request sent to server shotId=" .. shotId)

	if shotResult and shotResult.Instance then
		Net.ReportHit:FireServer({
			shotSeq = shotSequence,
			shotId = shotId,
			clientShotTime = clientShotTime,
			weaponId = localAmmo.weaponId,
			origin = shotOrigin,
			dir = spreadDir,
			hitInstance = shotResult.Instance,
			hitPos = shotResult.Position,
			hitNormal = shotResult.Normal,
			cameraOrigin = cameraOrigin,
			aimPoint = aimPoint,
		})
		log:trace("ReportHit sent shotId=" .. shotId)
	else
		log:trace("ReportHit skipped: client cast miss")
	end

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

local function onShotAttempt(shotResult: "ok" | "blocked_uninitialized" | "blocked_reload" | "blocked_ammo" | "no_camera", now: number)
	log:trace("Shot attempt result = " .. tostring(shotResult))
	if shotResult == "no_camera" then
		firingState.nextShotAt = now + NO_CAMERA_BACKOFF
	elseif shotResult == "blocked_uninitialized" then
		firingState.nextShotAt = now + 0.10
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
	getWeaponCfg()
	requestAmmoSync("CharacterAdded")
	bindHumanoidDeath(character)
end)

if player.Character then
	bindHumanoidDeath(player.Character)
	getWeaponCfg()
	requestAmmoSync("InitialBootstrap")
end

player:GetAttributeChangedSignal("WeaponId"):Connect(function()
	log:trace("WeaponId attribute changed")
	stopFiringLoop()
	getWeaponCfg()
	resetAmmoInitializationForWeapon()
	requestAmmoSync("WeaponChanged")
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
			local wasInitialized = localAmmo.initialized
			localAmmo.initialized = true
			localAmmo.mag = tonumber(ev.mag) or localAmmo.mag
			localAmmo.reserve = tonumber(ev.reserve) or localAmmo.reserve
			localAmmo.reloading = (ev.reloading == true)
			localAmmo.reloadEnd = tonumber(ev.reloadEnd) or 0
			if not wasInitialized then
				log:info(string.format("Ammo initialized=true via server sync weaponId=%s", tostring(localAmmo.weaponId)))
			end
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

log:trace("Local ammo state created: " .. ammoSnapshot())
log:info("CombatController ready (Shoot + Reload tracing enabled)")
