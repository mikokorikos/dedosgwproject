--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)
local AssetResolver = require(RS.GW.Shared.AssetResolver)
local LocalEffectsBus = require(script.Parent.LocalEffectsBus)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Combat")

local SoundsRoot = RS.GW.Assets:WaitForChild("Sounds")

local worldFolder = Workspace:FindFirstChild("_GW_WorldSFX")
if not worldFolder then
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "_GW_WorldSFX"
	worldFolder.Parent = Workspace
end

local function resolveSoundTemplate(pathOrName: string?): Sound?
	if type(pathOrName) ~= "string" or pathOrName == "" then
		return nil
	end
	local template = AssetResolver.resolve(SoundsRoot, pathOrName)
	if template and template:IsA("Sound") then
		return template
	end
	return nil
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
	if typeof(path) ~= "string" then
		log:warn("Shot sound skipped: missing sfx.shotPath for weaponId=" .. tostring(weaponId))
		return
	end

	local template = resolveSoundTemplate(path)
	if not (template and template:IsA("Sound")) then
		log:warn("Shot sound template not found path=" .. tostring(path))
		warn("[SoundController] Missing shot sound path:", path)
		return
	end
	if template.SoundId == "" or template.SoundId == "rbxassetid://0" then
		log:warn("Shot sound template has invalid SoundId path=" .. tostring(path))
		return
	end

	local a = makeAnchor(pos)
	local s = template:Clone()
	s.Parent = a
	log:trace("Shot sound source position = " .. tostring(pos))
	log:trace("Shot sound parent = " .. tostring(s.Parent and s.Parent:GetFullName()))
	configure3D(s, volume)
	s:Play()

	local cleanup = 2.0
	if s.TimeLength and s.TimeLength > 0 then
		cleanup = (s.TimeLength / math.max(s.PlaybackSpeed, 0.01)) + 0.2
	end
	Debris:AddItem(a, cleanup)
end

local function playCue2D(soundPath: string, volume: number?)
	local template = resolveSoundTemplate(soundPath)
	if not template then
		log:warn("SoundCue 2D template not found path=" .. tostring(soundPath))
		return
	end
	if template.SoundId == "" or template.SoundId == "rbxassetid://0" then
		log:warn("SoundCue 2D invalid SoundId path=" .. tostring(soundPath))
		return
	end
	local sound = template:Clone()
	sound.Parent = SoundService
	sound.Looped = false
	if type(volume) == "number" and volume > 0 then
		sound.Volume = volume
	end
	sound:Play()
	local ttl = 2.5
	if sound.TimeLength > 0 then
		ttl = (sound.TimeLength / math.max(sound.PlaybackSpeed, 0.01)) + 0.2
	end
	Debris:AddItem(sound, ttl)
end

local function playCue3D(soundPath: string, position: Vector3?, volume: number?)
	if typeof(position) ~= "Vector3" then
		log:warn("SoundCue 3D missing position, fallback to 2D path=" .. tostring(soundPath))
		playCue2D(soundPath, volume)
		return
	end
	local template = resolveSoundTemplate(soundPath)
	if not template then
		log:warn("SoundCue 3D template not found path=" .. tostring(soundPath))
		return
	end
	if template.SoundId == "" or template.SoundId == "rbxassetid://0" then
		log:warn("SoundCue 3D invalid SoundId path=" .. tostring(soundPath))
		return
	end

	local anchor = makeAnchor(position)
	local sound = template:Clone()
	sound.Parent = anchor
	configure3D(sound, if type(volume) == "number" and volume > 0 then volume else 1)
	sound:Play()
	local ttl = 2.5
	if sound.TimeLength > 0 then
		ttl = (sound.TimeLength / math.max(sound.PlaybackSpeed, 0.01)) + 0.2
	end
	Debris:AddItem(anchor, ttl)
end

local function onShotEvent(ev: any, localVolume: number, remoteVolume: number)
	if type(ev) ~= "table" then return end
	local pos = resolveStartPos(ev)
	if not pos then
		log:warn("Shot sound skipped: startPos/muzzlePos/origin missing")
		return
	end

	local shooter = ev.shooterUserId
	local isLocalShooter = typeof(shooter) == "number" and shooter == player.UserId
	local volume = if isLocalShooter then localVolume else remoteVolume
	local weaponId = resolveWeaponId(ev)
	log:trace(string.format("Shot sound event -> localShooter=%s weaponId=%s", tostring(isLocalShooter), tostring(weaponId)))
	playShotSoundAt(pos, weaponId, volume)
end

LocalEffectsBus.OnShot(function(ev)
	onShotEvent(ev, 0.95, 0.80)
end)

Net.ReplicateShot.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then return end

	local shooter = ev.shooterUserId
	if typeof(shooter) == "number" and shooter == player.UserId then
		return -- evita duplicado del evento local instantáneo
	end

	onShotEvent(ev, 0.95, 0.80)
end)

Net.FXEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then return end
	if ev.type ~= "SoundCue" then return end

	local soundPath = ev.soundPath
	if type(soundPath) ~= "string" or soundPath == "" then
		log:warn("SoundCue ignored: missing soundPath")
		return
	end

	local mode = string.upper(tostring(ev.mode or "2D"))
	local position = ev.position
	local volume = tonumber(ev.volume)

	if mode == "3D" then
		playCue3D(soundPath, position, volume)
	else
		playCue2D(soundPath, volume)
	end

	log:trace(string.format(
		"SoundCue played -> mode=%s path=%s context=%s",
		mode,
		soundPath,
		tostring(ev.context)
	))
end)

print("[GW] SoundController (local bus + remote) activo.")
