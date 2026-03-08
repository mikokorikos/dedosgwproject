local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local LocalEffectsBus = require(script.Parent.LocalEffectsBus)

local okW, Weapons = pcall(require, RS.GW.Shared:WaitForChild("WeaponRegistry"))
if not okW then
	Weapons = { Get = function() return {} end }
end

local AssetResolver = require(RS.GW.Shared.AssetResolver)
local Assets = RS.GW:WaitForChild("Assets")
local FXRoot = Assets:WaitForChild("FX")
local SoundsRoot = Assets:WaitForChild("Sounds")

local function getCamFolder()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local f = cam:FindFirstChild("_GW_FX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "_GW_FX"
		f.Parent = cam
	end
	return f
end

local function makeAnchor(pos, name, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2,0.2,0.2)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.CastShadow = false
	p.CFrame = CFrame.new(pos)
	p.Parent = parent or getCamFolder()
	return p
end

local function findDescendantByName(root, name)
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name then return d end
	end
	return nil
end

local function resolveFolder(pathOrName)
	if typeof(pathOrName) ~= "string" or pathOrName == "" then return nil end
	local inst = AssetResolver.resolve(FXRoot, pathOrName)
	if inst and inst:IsA("Folder") then return inst end
	-- fallback por nombre plano
	local f = findDescendantByName(FXRoot, pathOrName)
	if f and f:IsA("Folder") then return f end
	return nil
end

local function resolveBeam(pathOrName)
	if typeof(pathOrName) ~= "string" or pathOrName == "" then return nil end
	local inst = AssetResolver.resolve(FXRoot, pathOrName)
	if inst and inst:IsA("Beam") then return inst end
	local b = findDescendantByName(FXRoot, pathOrName)
	if b and b:IsA("Beam") then return b end
	return nil
end

local function resolveSound(pathOrName)
	if typeof(pathOrName) ~= "string" or pathOrName == "" then return nil end
	local inst = AssetResolver.resolve(SoundsRoot, pathOrName)
	if inst and inst:IsA("Sound") then return inst end
	local s = findDescendantByName(SoundsRoot, pathOrName)
	if s and s:IsA("Sound") then return s end
	return nil
end

local function collectEmitters(folder)
	local list = {}
	if not folder then return list end
	for _, obj in ipairs(folder:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then table.insert(list, obj) end
	end
	return list
end

local function emitBurst(templates, att, defaultCount)
	for _, t in ipairs(templates) do
		local e = t:Clone()
		e.Enabled = false
		e.Rate = 0
		e.Parent = att
		local n = e:GetAttribute("EmitCount")
		if typeof(n) ~= "number" then n = defaultCount end
		e:Emit(n)
	end
end

local function maxEmitterLife(folder)
	local m = 1.0
	if not folder then return 1.2 end
	for _, obj in ipairs(folder:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			m = math.max(m, obj.Lifetime.Max)
		end
	end
	return m
end

local function buildSurfaceAlignedCFrame(pos, normal)
	local n = (typeof(normal) == "Vector3" and normal.Magnitude > 0.001) and normal.Unit or Vector3.new(0,1,0)
	local helper = (math.abs(n:Dot(Vector3.new(0,1,0))) > 0.98) and Vector3.new(1,0,0) or Vector3.new(0,1,0)
	local right = (helper:Cross(n)).Unit
	local forward = (n:Cross(right)).Unit
	return CFrame.fromMatrix(pos, right, n, -forward)
end

local function play3D(soundPathOrName, parent)
	local t = resolveSound(soundPathOrName)
	if not t then return end
	if t.SoundId == "" or t.SoundId == "rbxassetid://0" then return end
	local s = t:Clone()
	s.Parent = parent
	s.RollOffMode = Enum.RollOffMode.Inverse
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 140
	s.EmitterSize = 2
	s.Volume = 1
	s.Looped = false
	s:Play()
	Debris:AddItem(s, 4)
end

local function fadeBeam(beam, fadeTime)
	local v = Instance.new("NumberValue")
	v.Value = 0
	v.Parent = beam
	local conn
	conn = v:GetPropertyChangedSignal("Value"):Connect(function()
		local a = math.clamp(v.Value, 0, 1)
		beam.Transparency = NumberSequence.new(a)
	end)
	local tw = TweenService:Create(v, TweenInfo.new(fadeTime, Enum.EasingStyle.Linear), {Value = 1})
	tw:Play()
	tw.Completed:Connect(function()
		if conn then conn:Disconnect() end
		if v.Parent then v:Destroy() end
	end)
end

local function renderShot(ev)
	if type(ev) ~= "table" then return end
	local shooter = ev.shooterUserId
	if typeof(shooter) == "number" and shooter == player.UserId then
		-- tu arma local puede renderizarse por otro script; pero si no hay, igual dejamos esto activo
	end

	local weaponId = (type(ev.weaponId) == "string" and ev.weaponId) or "SoldierRifle"
	local cfg = Weapons.Get(weaponId) or {}
	local fx = cfg.fx or {}
	local tracer = fx.tracer or {}

	local startPos = ev.startPos or ev.muzzlePos or ev.origin
	local hitPos = ev.hitPos
	if typeof(startPos) ~= "Vector3" or typeof(hitPos) ~= "Vector3" then return end

	local hitNormal = (typeof(ev.hitNormal) == "Vector3") and ev.hitNormal or Vector3.new(0,1,0)
	local didHit = ev.didHit == true

	-- muzzle
	do
		local folder = resolveFolder(fx.muzzleEmittersPath or "MuzzleEmitters")
		local templates = collectEmitters(folder)
		local a = makeAnchor(startPos, "MuzzleFX")
		local att = Instance.new("Attachment"); att.Parent = a
		emitBurst(templates, att, 4)
		Debris:AddItem(a, 0.35)
	end

	-- tracer snapshot
	do
		local startA = makeAnchor(startPos, "TracerStart")
		local endA = makeAnchor(hitPos, "TracerEnd")
		local a0 = Instance.new("Attachment"); a0.Parent = startA
		local a1 = Instance.new("Attachment"); a1.Parent = endA

		local beamT = resolveBeam(fx.beamTemplatePath or "TracerBeamTemplate")
		local beam = beamT and beamT:Clone() or Instance.new("Beam")
		beam.FaceCamera = true
		beam.Attachment0 = a0
		beam.Attachment1 = a1

		beam.Width0 = tonumber(tracer.width0) or 0.16
		beam.Width1 = tonumber(tracer.width1) or 0.10
		beam.Brightness = tonumber(tracer.brightness) or 1.0
		beam.Parent = endA

		local speed = tonumber(tracer.speed) or 3200
		local persist = tonumber(tracer.persist) or 0.035
		local fade = tonumber(tracer.fade) or 0.8

		local dist = (hitPos - startPos).Magnitude
		local travel = math.clamp(dist / math.max(speed,1), 0.01, 0.04)

		task.delay(persist, function()
			if beam.Parent then fadeBeam(beam, fade) end
		end)

		local life = persist + fade + 0.12
		Debris:AddItem(startA, life)
		Debris:AddItem(endA, life)

		if didHit then
			task.delay(travel, function()
				local folder = resolveFolder(fx.impactEmittersPath or "ImpactEmitters")
				local templates = collectEmitters(folder)
				local n = (hitNormal.Magnitude > 0.001) and hitNormal.Unit or Vector3.new(0,1,0)
				local p = hitPos + n * 0.03
				local imp = makeAnchor(p, "ImpactFX")
				imp.CFrame = buildSurfaceAlignedCFrame(p, n)
				local att = Instance.new("Attachment"); att.Parent = imp
				emitBurst(templates, att, 8)
				Debris:AddItem(imp, 0.35)
			end)
		end
	end
end

local function renderExplosion(ev)
	if type(ev) ~= "table" then return end
	local pos = ev.pos
	if typeof(pos) ~= "Vector3" then return end
	local normal = (typeof(ev.normal) == "Vector3") and ev.normal or Vector3.new(0,1,0)

	local fxPath = ev.fxPath or ev.fxFolder or "RocketExplosionEmitters"
	local folder = resolveFolder(fxPath)
	if not folder then return end

	local n = (normal.Magnitude > 0.001) and normal.Unit or Vector3.new(0,1,0)
	local p = pos + n * 0.03

	local anchor = makeAnchor(p, "ExplosionFX", Workspace)
	anchor.CFrame = buildSurfaceAlignedCFrame(p, n)

	local att = Instance.new("Attachment"); att.Parent = anchor
	local templates = collectEmitters(folder)
	emitBurst(templates, att, 10)

	local sp = ev.soundPath or ev.soundName or "RocketExplosionSound"
	play3D(sp, anchor)

	Debris:AddItem(anchor, maxEmitterLife(folder) + 0.8)
end

Net.FXEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then return end
	local t = ev.type
	if t == "Explosion" then
		renderExplosion(ev)
	end
end)

Net.ReplicateShot.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then return end
	local shooter = ev.shooterUserId
	if typeof(shooter) == "number" and shooter == player.UserId then
		return
	end
	renderShot(ev)
end)

LocalEffectsBus.OnShot(function(ev)
	renderShot(ev)
end)

print("[GW] FXController (paths+fallback) activo.")
