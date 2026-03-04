--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)
local LocalEffectsBus = require(script.Parent.LocalEffectsBus)

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

local localAmmo = {
	initialized = false,
	mag = 0,
	reserve = 0,
	reloading = false,
	reloadEnd = 0,
	weaponId = Weapons.DefaultId,
}

local function canUseAmmoState(): boolean
	return localAmmo.initialized == true
end

local function resetAmmoInitializationForWeapon()
	localAmmo.initialized = false
	localAmmo.reloading = false
	localAmmo.reloadEnd = 0
end

local function getWeaponCfg()
	local id = player:GetAttribute("WeaponId")
	if typeof(id) ~= "string" then id = Weapons.DefaultId end
	localAmmo.weaponId = id
	return Weapons.Get(id)
end

local function getAimRay()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
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

local function isTyping()
	return UIS:GetFocusedTextBox() ~= nil
end

local function tryShoot(): "ok" | "blocked_reload" | "blocked_ammo" | "no_camera"
	if not canUseAmmoState() then return "blocked_reload" end
	if localAmmo.reloading and os.clock() < localAmmo.reloadEnd then return "blocked_reload" end
	if localAmmo.mag <= 0 then
		Net.CombatRequest:FireServer({ action="DryTrigger", weaponId = localAmmo.weaponId })
		return "blocked_ammo"
	end

	local origin, dir = getAimRay()
	if not origin or not dir then return "no_camera" end
	local weaponCfg = getWeaponCfg()
	local spreadDir = applySpread(dir, getSpreadAngleDeg(weaponCfg))
	local range = tonumber(weaponCfg.hitscan and weaponCfg.hitscan.range) or 2000
	local shotResult = castShot(origin, spreadDir, range)
	local hitPos = if shotResult then shotResult.Position else origin + spreadDir * range
	local clientShotTime = os.clock()

	-- predicción local de ammo para UI feel
	localAmmo.mag -= 1
	shotSequence += 1
	local shotId = string.format("%d-%d", player.UserId, shotSequence)

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

	return "ok"
end

local function tryReload()
	if not canUseAmmoState() then return end
	local weaponCfg = getWeaponCfg()
	local magSize = tonumber(weaponCfg.ammo and weaponCfg.ammo.magSize) or 30
	if localAmmo.reloading and os.clock() < localAmmo.reloadEnd then return end
	if localAmmo.mag >= magSize then return end
	if localAmmo.reserve <= 0 then return end

	Net.CombatRequest:FireServer({
		action = "Reload",
		weaponId = localAmmo.weaponId,
	})
end

local function stopFiringLoop()
	firingState.triggerHeld = false
	firingState.isFiringLoopActive = false
end

local function onShotAttempt(shotResult: "ok" | "blocked_reload" | "blocked_ammo" | "no_camera", now: number)
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
	if not humanoid then return end

	humanoid.Died:Connect(function()
		stopFiringLoop()
	end)
end

player.CharacterAdded:Connect(function(character)
	stopFiringLoop()
	resetAmmoInitializationForWeapon()
	bindHumanoidDeath(character)
end)

if player.Character then
	bindHumanoidDeath(player.Character)
end

player:GetAttributeChangedSignal("WeaponId"):Connect(function()
	stopFiringLoop()
	getWeaponCfg()
	resetAmmoInitializationForWeapon()
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp or isTyping() then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if firingState.triggerHeld then return end
		firingState.triggerHeld = true

		local weaponCfg = getWeaponCfg()
		firingState.fireModeAuto = (weaponCfg.fire and weaponCfg.fire.auto) == true
		local rpm = tonumber(weaponCfg.fire and weaponCfg.fire.rpm) or 420
		firingState.fireInterval = 60 / math.max(rpm, 1)

		local now = os.clock()
		fireImmediateShot(now)
		firingState.isFiringLoopActive = firingState.fireModeAuto
	elseif input.KeyCode == Enum.KeyCode.R then
		tryReload()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stopFiringLoop()
	end
end)

UIS.WindowFocusReleased:Connect(function()
	stopFiringLoop()
end)

RunService.Heartbeat:Connect(function()
	if not firingState.isFiringLoopActive then return end
	if not firingState.triggerHeld then
		stopFiringLoop()
		return
	end

	local now = os.clock()
	if now < firingState.nextShotAt then return end

	local shotResult = tryShoot()
	onShotAttempt(shotResult, now)
end)

-- sync desde server
Net.FXEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then return end
	if ev.type == "Ammo" then
		if ev.weaponId == localAmmo.weaponId then
			localAmmo.initialized = true
			localAmmo.mag = tonumber(ev.mag) or localAmmo.mag
			localAmmo.reserve = tonumber(ev.reserve) or localAmmo.reserve
			localAmmo.reloading = (ev.reloading == true)
			localAmmo.reloadEnd = tonumber(ev.reloadEnd) or 0
		end
	elseif ev.type == "ReloadStart" then
		localAmmo.reloading = true
		localAmmo.reloadEnd = os.clock() + (tonumber(ev.reloadTime) or 0)
	elseif ev.type == "ReloadEnd" then
		localAmmo.reloading = false
		localAmmo.reloadEnd = 0
	end
end)

print("[GW] CombatController listo (Shoot + Reload).")
