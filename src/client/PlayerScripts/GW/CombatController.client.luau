--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)

local firing = false
local lastLocalShotAt = 0

local localAmmo = {
	mag = 0,
	reserve = 0,
	reloading = false,
	reloadEnd = 0,
	weaponId = Weapons.DefaultId,
}

local function getWeaponCfg()
	local id = player:GetAttribute("WeaponId")
	if typeof(id) ~= "string" then id = Weapons.DefaultId end
	localAmmo.weaponId = id
	return Weapons.Get(id)
end

local function canLocalShoot(rpm: number)
	local now = os.clock()
	local interval = 60 / math.max(rpm, 1)
	return (now - lastLocalShotAt) >= interval
end

local function markLocalShot()
	lastLocalShotAt = os.clock()
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

local function tryShoot()
	local weaponCfg = getWeaponCfg()
	local rpm = tonumber(weaponCfg.fire and weaponCfg.fire.rpm) or 420
	if not canLocalShoot(rpm) then return end
	if localAmmo.reloading and os.clock() < localAmmo.reloadEnd then return end
	if localAmmo.mag <= 0 then
		Net.CombatRequest:FireServer({ action="Shoot", origin=Vector3.zero, direction=Vector3.new(0,0,-1) })
		return
	end

	local origin, dir = getAimRay()
	if not origin or not dir then return end

	markLocalShot()

	-- predicción local de ammo para UI feel
	localAmmo.mag -= 1

	Net.CombatRequest:FireServer({
		action = "Shoot",
		weaponId = localAmmo.weaponId,
		origin = origin,
		direction = dir,
	})
end

local function tryReload()
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

UIS.InputBegan:Connect(function(input, gp)
	if gp or isTyping() then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if firing then return end
		firing = true
		task.spawn(function()
			while firing do
				local weaponCfg = getWeaponCfg()
				local auto = (weaponCfg.fire and weaponCfg.fire.auto) == true
				tryShoot()
				if not auto then break end
				task.wait(0.01)
			end
		end)
	elseif input.KeyCode == Enum.KeyCode.R then
		tryReload()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
	end
end)

-- sync desde server
Net.FXEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then return end
	if ev.type == "Ammo" then
		if ev.weaponId == localAmmo.weaponId then
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
