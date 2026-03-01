--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)

local triggerHeld = false
local fireModeAuto = false
local nextShotAt = 0
local shootRequested = false
local fireInterval = 0

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

local function isTyping()
	return UIS:GetFocusedTextBox() ~= nil
end

local function tryShoot(weaponCfg)
	if not canUseAmmoState() then return false end
	if localAmmo.reloading and os.clock() < localAmmo.reloadEnd then return false end
	if localAmmo.mag <= 0 then
		Net.CombatRequest:FireServer({ action="DryTrigger", weaponId = localAmmo.weaponId })
		return false
	end

	local origin, dir = getAimRay()
	if not origin or not dir then return false end

	-- predicción local de ammo para UI feel
	localAmmo.mag -= 1

	Net.CombatRequest:FireServer({
		action = "Shoot",
		weaponId = localAmmo.weaponId,
		origin = origin,
		direction = dir,
	})

	return true
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

player.CharacterAdded:Connect(function()
	resetAmmoInitializationForWeapon()
end)

player:GetAttributeChangedSignal("WeaponId"):Connect(function()
	getWeaponCfg()
	resetAmmoInitializationForWeapon()
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp or isTyping() then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if triggerHeld then return end
		triggerHeld = true

		local weaponCfg = getWeaponCfg()
		fireModeAuto = (weaponCfg.fire and weaponCfg.fire.auto) == true
		local rpm = tonumber(weaponCfg.fire and weaponCfg.fire.rpm) or 420
		fireInterval = 60 / math.max(rpm, 1)
		shootRequested = true
	elseif input.KeyCode == Enum.KeyCode.R then
		tryReload()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		triggerHeld = false
	end
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextShotAt then return end

	local shouldTryShoot = false
	if fireModeAuto then
		if triggerHeld then
			shouldTryShoot = true
		end
	elseif shootRequested then
		shouldTryShoot = true
	end

	if not shouldTryShoot then return end

	local weaponCfg = getWeaponCfg()
	if tryShoot(weaponCfg) then
		nextShotAt = now + fireInterval
	end

	if not fireModeAuto then
		shootRequested = false
	end
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
