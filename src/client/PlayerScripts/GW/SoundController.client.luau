--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)
local AssetResolver = require(RS.GW.Shared.AssetResolver)

local SoundsRoot = RS.GW.Assets:WaitForChild("Sounds")

local worldFolder = Workspace:FindFirstChild("_GW_WorldSFX")
if not worldFolder then
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "_GW_WorldSFX"
	worldFolder.Parent = Workspace
end

local lastLocalShot = 0

local function isTyping()
	return UIS:GetFocusedTextBox() ~= nil
end

local function makeAnchor(pos: Vector3)
	local p = Instance.new("Part")
	p.Name = "SFXAnchor"
	p.Size = Vector3.new(0.2,0.2,0.2)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.CastShadow = false
	p.CFrame = CFrame.new(pos)
	p.Parent = worldFolder
	return p
end

local function configure3D(s: Sound, volume: number)
	s.RollOffMode = Enum.RollOffMode.Inverse
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 120
	s.EmitterSize = 2
	s.Volume = volume
	s.Looped = false
	s.PlaybackSpeed = 0.97 + (math.random() * 0.06)
end

local function resolveWeaponId(ev: any): string
	if type(ev) ~= "table" then return "SoldierRifle" end
	if type(ev.weaponId) == "string" then return ev.weaponId end
	if type(ev.weapon) == "string" then return ev.weapon end
	if type(ev.id) == "string" then return ev.id end
	return "SoldierRifle"
end

local function resolveStartPos(ev: any): Vector3?
	if type(ev) ~= "table" then return nil end
	if typeof(ev.startPos) == "Vector3" then return ev.startPos end
	if typeof(ev.muzzlePos) == "Vector3" then return ev.muzzlePos end
	if typeof(ev.origin) == "Vector3" then return ev.origin end
	return nil
end

local function playShotSoundAt(pos: Vector3, weaponId: string, volume: number)
	local cfg = Weapons.Get(weaponId)
	local path = cfg.sfx and cfg.sfx.shotPath
	if typeof(path) ~= "string" then return end

	local template = AssetResolver.resolve(SoundsRoot, path)
	if not (template and template:IsA("Sound")) then
		warn("[SoundController] Missing shot sound path:", path)
		return
	end
	if template.SoundId == "" or template.SoundId == "rbxassetid://0" then
		return
	end

	local a = makeAnchor(pos)
	local s = template:Clone()
	s.Parent = a
	configure3D(s, volume)
	s:Play()

	local cleanup = 2.0
	if s.TimeLength and s.TimeLength > 0 then
		cleanup = (s.TimeLength / math.max(s.PlaybackSpeed, 0.01)) + 0.2
	end
	Debris:AddItem(a, cleanup)
end

-- ✅ LOCAL INSTANT: siempre oyes tu rifle
local function getLocalWeaponId(): string
	local charId = player:GetAttribute("CharacterId")
	-- si tu CharacterRegistry expone weaponId por char, mejor, pero fallback SoldierRifle
	return "SoldierRifle"
end

local function getLocalMuzzlePos(): Vector3?
	local char = player.Character
	if not char then return nil end
	-- busca un Muzzle attachment en cualquier lado (rápido)
	local muzzle = char:FindFirstChild("Muzzle", true)
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end
	-- fallback HRP
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp.Position end
	return nil
end

UIS.InputBegan:Connect(function(input, gp)
	if gp or isTyping() then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	-- throttle según RPM config
	local weaponId = getLocalWeaponId()
	local cfg = Weapons.Get(weaponId)
	local rpm = (cfg.fire and tonumber(cfg.fire.rpm)) or 420
	local interval = 60 / math.max(rpm, 1)
	local now = os.clock()
	if (now - lastLocalShot) < interval then return end
	lastLocalShot = now

	local pos = getLocalMuzzlePos()
	if pos then
		playShotSoundAt(pos, weaponId, 0.95)
	end
end)

-- ✅ REMOTE: oyes a otros si llega FXEvent
Net.FXEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then return end

	-- acepta "Shot" o variantes
	local t = ev.type
	if t ~= "Shot" and t ~= "Shoot" and t ~= "GunShot" then
		return
	end

	local shooter = ev.shooterUserId
	if typeof(shooter) == "number" and shooter == player.UserId then
		return -- no duplique tu local
	end

	local pos = resolveStartPos(ev)
	if not pos then return end

	local weaponId = resolveWeaponId(ev)
	playShotSoundAt(pos, weaponId, 0.80)
end)

print("[GW] SoundController (local+remote) activo.")
