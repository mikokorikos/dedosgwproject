--!strict
-- CustomAnimateLite.lua
-- Animate compacto para rigs personalizados (Humanoid + Animator + anims hechas para tu rig)
print("loaded")
local RunService = game:GetService("RunService")

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid

local Animator = Humanoid:FindFirstChildOfClass("Animator")
if not Animator then
	Animator = Instance.new("Animator")
	Animator.Parent = Humanoid
end

--==================================================
-- CONFIG (PON TUS IDS)
--==================================================
local ANIMS = {
	idle = "rbxassetid://76906466107364",
	walk = "rbxassetid://100477131302338",
	run  = "rbxassetid://100477131302338", -- opcional (si lo dejas vacío usa walk)
	jump = "rbxassetid://81601740746075",
	fall = "rbxassetid://81601740746075",
	land = "", -- opcional
	sit  = "", -- opcional
	dead = "", -- opcional
}

local CFG = {
	Fade = 0.12,
	AirFade = 0.08,

	MoveThreshold = 0.15, -- velocidad mínima para considerar movimiento
	RunThresholdRatio = 0.75, -- speed >= WalkSpeed * ratio => run

	WalkRefSpeed = 8,   -- velocidad a la que tu anim de walk se ve natural
	RunRefSpeed  = 16,  -- velocidad a la que tu anim de run se ve natural

	MinTrackSpeed = 0.6,
	MaxTrackSpeed = 2.4,

	JumpHold = 0.15, -- evita que Freefall corte jump instantáneamente
	LandLock = 0.10, -- pequeño lock para que se vea "land"
	HeartbeatFallbackRate = 0.08, -- respaldo ligero (segundos)
}

--==================================================
-- UTILIDADES
--==================================================
local function clamp(n: number, a: number, b: number): number
	if n < a then return a end
	if n > b then return b end
	return n
end

local function now(): number
	return os.clock()
end

local function getRoot(): BasePart?
	return Humanoid.RootPart or Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
end

local function horizontalSpeed(): number
	local root = getRoot()
	if not root then return 0 end
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function isAirState(state: Enum.HumanoidStateType): boolean
	return state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.FallingDown
end

--==================================================
-- CARGA DE TRACKS (cache)
--==================================================
local tracks: {[string]: AnimationTrack} = {}
local loaded = false

local function makeTrack(name: string, animId: string): AnimationTrack?
	if animId == nil or animId == "" then
		return nil
	end

	local anim = Instance.new("Animation")
	anim.Name = "Anim_" .. name
	anim.AnimationId = animId

	local ok, result = pcall(function()
		return Animator:LoadAnimation(anim)
	end)
	if not ok then
		warn(("CustomAnimateLite: no se pudo cargar '%s' (%s): %s"):format(name, animId, tostring(result)))
		return nil
	end

	local track = result :: AnimationTrack
	track.Looped = (name ~= "jump" and name ~= "land" and name ~= "dead")
	track.Priority = (name == "idle" or name == "sit") and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
	if name == "dead" then
		track.Priority = Enum.AnimationPriority.Action
	end
	return track
end

local function loadTracks()
	if loaded then return end
	for name, animId in pairs(ANIMS) do
		local t = makeTrack(name, animId)
		if t then tracks[name] = t end
	end
	loaded = true
end

loadTracks()

--==================================================
-- ESTADO / PLAYBACK
--==================================================
local currentState = ""
local currentTrack: AnimationTrack? = nil
local dead = false
local speedHint = 0
local jumpHoldUntil = 0
local stateLockUntil = 0

local function stopOthers(except: AnimationTrack?, fade: number)
	for _, t in pairs(tracks) do
		if t ~= except and t.IsPlaying then
			t:Stop(fade)
		end
	end
end

local function playState(name: string, fade: number?, trackSpeed: number?)
	if dead and name ~= "dead" then return end

	local track = tracks[name]
	if not track then return end

	local f = fade or CFG.Fade
	local s = trackSpeed or 1

	-- mismo estado: solo ajusta velocidad
	if currentState == name and currentTrack == track then
		track:AdjustSpeed(s)
		return
	end

	stopOthers(track, f)

	if not track.IsPlaying then
		track:Play(f, 1, s)
	else
		track:AdjustSpeed(s)
	end

	currentState = name
	currentTrack = track
end

local function chooseGroundLocomotion(): (string, number)
	local speed = math.max(speedHint, horizontalSpeed())

	if speed <= CFG.MoveThreshold then
		return "idle", 1
	end

	local hasRun = tracks.run ~= nil
	local walkSpeed = (Humanoid.WalkSpeed > 0 and Humanoid.WalkSpeed or 16)

	if hasRun and speed >= walkSpeed * CFG.RunThresholdRatio then
		return "run", clamp(speed / CFG.RunRefSpeed, CFG.MinTrackSpeed, CFG.MaxTrackSpeed)
	end

	return "walk", clamp(speed / CFG.WalkRefSpeed, CFG.MinTrackSpeed, CFG.MaxTrackSpeed)
end

local function updateByState()
	if dead then return end
	if now() < stateLockUntil then return end

	local state = Humanoid:GetState()

	if state == Enum.HumanoidStateType.Dead then
		dead = true
		if tracks.dead then
			playState("dead", 0.05, 1)
		else
			stopOthers(nil, 0.1)
		end
		return
	end

	if state == Enum.HumanoidStateType.Seated and tracks.sit then
		playState("sit", 0.12, 1)
		return
	end

	if state == Enum.HumanoidStateType.Jumping then
		playState("jump", CFG.AirFade, 1)
		return
	end

	if state == Enum.HumanoidStateType.Freefall then
		if now() >= jumpHoldUntil then
			playState("fall", CFG.AirFade, 1)
		end
		return
	end

	-- suelo
	local locomotionState, locomotionSpeed = chooseGroundLocomotion()
	playState(locomotionState, CFG.Fade, locomotionSpeed)
end

--==================================================
-- EVENTOS
--==================================================
Humanoid.Running:Connect(function(speed: number)
	speedHint = speed
	-- Si estamos en walk/run, actualiza inmediatamente
	if currentState == "walk" or currentState == "run" or currentState == "idle" then
		updateByState()
	end
end)

Humanoid.Jumping:Connect(function(active: boolean)
	if active and not dead then
		jumpHoldUntil = now() + CFG.JumpHold
		playState("jump", CFG.AirFade, 1)
	end
end)

Humanoid.FreeFalling:Connect(function(active: boolean)
	if dead then return end
	if active then
		if now() >= jumpHoldUntil then
			playState("fall", CFG.AirFade, 1)
		end
	else
		updateByState()
	end
end)

Humanoid.Seated:Connect(function(_active: boolean, _seat: BasePart?)
	if dead then return end
	updateByState()
end)

Humanoid.StateChanged:Connect(function(_oldState, newState)
	if dead then return end

	if newState == Enum.HumanoidStateType.Landed then
		if tracks.land then
			playState("land", 0.05, 1)
			stateLockUntil = now() + CFG.LandLock
		else
			updateByState()
		end
		return
	end

	updateByState()
end)

Humanoid.Died:Connect(function()
	dead = true
	if tracks.dead then
		playState("dead", 0.05, 1)
	else
		stopOthers(nil, 0.1)
	end
end)

--==================================================
-- HEARTBEAT FALLBACK (ligero, no spam)
--==================================================
local acc = 0
local hbConn: RBXScriptConnection? = nil
hbConn = RunService.Heartbeat:Connect(function(dt)
	if not Character.Parent then
		if hbConn then hbConn:Disconnect() end
		return
	end

	acc += dt
	if acc < CFG.HeartbeatFallbackRate then
		return
	end
	acc = 0

	-- Mantén speed de walk/run sincronizado y recupera si algún evento falló
	updateByState()
end)

-- Inicializa
task.defer(function()
	updateByState()
end)


print("loaded")