--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)
local AssetResolver = require(RS.GW.Shared.AssetResolver)
local LocalEffectsBus = require(script.Parent.LocalEffectsBus)

local SoundsRoot = RS.GW.Assets:WaitForChild("Sounds")

local worldFolder = Workspace:FindFirstChild("_GW_WorldSFX")
if not worldFolder then
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "_GW_WorldSFX"
	worldFolder.Parent = Workspace
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

local function onShotEvent(ev: any, localVolume: number, remoteVolume: number)
	if type(ev) ~= "table" then return end
	local pos = resolveStartPos(ev)
	if not pos then return end

	local shooter = ev.shooterUserId
	local isLocalShooter = typeof(shooter) == "number" and shooter == player.UserId
	local volume = if isLocalShooter then localVolume else remoteVolume
	local weaponId = resolveWeaponId(ev)
	playShotSoundAt(pos, weaponId, volume)
end

LocalEffectsBus.OnShot(function(ev)
	onShotEvent(ev, 0.95, 0.80)
end)

Net.FXEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then return end

	local t = ev.type
	if t ~= "Shot" and t ~= "Shoot" and t ~= "GunShot" then
		return
	end

	local shooter = ev.shooterUserId
	if typeof(shooter) == "number" and shooter == player.UserId then
		return -- evita duplicado del evento local instantáneo
	end

	onShotEvent(ev, 0.95, 0.80)
end)

print("[GW] SoundController (local bus + remote) activo.")
