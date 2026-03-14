--!strict
local RS = game:GetService("ReplicatedStorage")

local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("AnimRuntime")

type AnimationEntry = {
	animationId: string,
	priority: string?,
	looped: boolean?,
	fadeTime: number?,
	speed: number?,
	weight: number?,
	referenceSpeed: number?,
	triggerMode: string?,
	triggerMarkerName: string?,
	triggerDelay: number?,
}

type AnimationProfileConfig = {
	id: string,
	defaults: {
		fadeTime: number?,
		speed: number?,
		weight: number?,
		triggerDelay: number?,
		runThresholdRatio: number?,
	}?,
	locomotion: {[string]: AnimationEntry}?,
	actions: {[string]: AnimationEntry}?,
}

export type Runtime = {
	model: Model,
	humanoid: Humanoid?,
	animator: Animator?,
	profile: AnimationProfileConfig,
	setLocomotionState: (self: Runtime, key: string, speedScale: number?) -> boolean,
	stopLocomotion: (self: Runtime, fadeOverride: number?) -> (),
	playAction: (self: Runtime, key: string) -> boolean,
	playActionWithTrigger: (self: Runtime, key: string, onTrigger: ((string) -> ())?) -> boolean,
	destroy: (self: Runtime) -> (),
}

local AnimationRuntimeCore = {}

local PRIORITY_MAP = {
	Core = Enum.AnimationPriority.Core,
	Idle = Enum.AnimationPriority.Idle,
	Movement = Enum.AnimationPriority.Movement,
	Action = Enum.AnimationPriority.Action,
	Action2 = Enum.AnimationPriority.Action2,
	Action3 = Enum.AnimationPriority.Action3,
	Action4 = Enum.AnimationPriority.Action4,
}

local function normalizeAnimationId(animationId: string): string
	if string.match(animationId, "^%d+$") then
		return "rbxassetid://" .. animationId
	end
	return animationId
end

local function resolvePriority(priorityName: string?): Enum.AnimationPriority
	if type(priorityName) == "string" then
		local resolved = PRIORITY_MAP[priorityName]
		if resolved then
			return resolved
		end
	end
	return Enum.AnimationPriority.Action
end

local function safeNumber(value: any, fallback: number): number
	local n = tonumber(value)
	if n == nil then
		return fallback
	end
	return n
end

local function getHumanoid(model: Model): Humanoid?
	return model:FindFirstChildOfClass("Humanoid")
end

local function ensureAnimator(humanoid: Humanoid?): Animator?
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end
	animator = Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

local function stopTrackList(trackList: {[string]: AnimationTrack}, exceptTrack: AnimationTrack?, fadeTime: number)
	for _, track in pairs(trackList) do
		if track ~= exceptTrack and track.IsPlaying then
			track:Stop(fadeTime)
		end
	end
end

local function warnOnce(runtimeInternal: any, key: string, message: string)
	if runtimeInternal.warned[key] then
		return
	end
	runtimeInternal.warned[key] = true
	log:warn(string.format("[%s] %s", runtimeInternal.model.Name, message))
end

local function loadTrack(runtimeInternal: any, cache: {[string]: AnimationTrack}, cacheKey: string, entry: AnimationEntry, defaultPriority: string): AnimationTrack?
	local existing = cache[cacheKey]
	if existing and existing.Parent then
		return existing
	end
	if runtimeInternal.destroyed then
		return nil
	end
	if not runtimeInternal.animator then
		warnOnce(runtimeInternal, "no_animator", "Animator missing; animation playback skipped")
		return nil
	end
	if type(entry.animationId) ~= "string" or entry.animationId == "" then
		warnOnce(runtimeInternal, "missing_anim_" .. cacheKey, "AnimationId missing for key=" .. cacheKey)
		return nil
	end

	local anim = Instance.new("Animation")
	anim.Name = "GWAnim_" .. cacheKey
	anim.AnimationId = normalizeAnimationId(entry.animationId)

	local ok, trackOrErr = pcall(function()
		return runtimeInternal.animator:LoadAnimation(anim)
	end)
	if not ok or not trackOrErr then
		warnOnce(runtimeInternal, "load_failed_" .. cacheKey, "LoadAnimation failed for key=" .. cacheKey .. " err=" .. tostring(trackOrErr))
		return nil
	end

	local track = trackOrErr :: AnimationTrack
	track.Priority = resolvePriority(entry.priority or defaultPriority)
	track.Looped = entry.looped == true
	cache[cacheKey] = track
	return track
end

function AnimationRuntimeCore.create(model: Model, profile: AnimationProfileConfig): Runtime
	local internal: any = {
		model = model,
		humanoid = getHumanoid(model),
		profile = profile,
		animator = nil,
		locomotionTracks = {},
		actionTracks = {},
		warned = {},
		currentLocomotionKey = nil,
		destroyed = false,
	}
	internal.animator = ensureAnimator(internal.humanoid)

	local runtime = {} :: Runtime

	function runtime:setLocomotionState(key: string, speedScale: number?): boolean
		if internal.destroyed then
			return false
		end
		local locomotion = internal.profile.locomotion or {}
		local entry = locomotion[key]
		local resolvedKey = key
		if entry == nil then
			entry = locomotion.Idle
			resolvedKey = "Idle"
		end
		if entry == nil then
			warnOnce(internal, "missing_locomotion_" .. tostring(key), "Locomotion key missing and Idle fallback unavailable")
			return false
		end

		local track = loadTrack(internal, internal.locomotionTracks, resolvedKey, entry, "Movement")
		if not track then
			return false
		end

		local defaults = internal.profile.defaults or {}
		local fade = safeNumber(entry.fadeTime, safeNumber(defaults.fadeTime, 0.12))
		local baseSpeed = safeNumber(entry.speed, safeNumber(defaults.speed, 1))
		local playWeight = safeNumber(entry.weight, safeNumber(defaults.weight, 1))
		local speed = baseSpeed
		if type(speedScale) == "number" then
			speed *= speedScale
		end
		speed = math.clamp(speed, 0.05, 4)

		if internal.currentLocomotionKey ~= resolvedKey then
			stopTrackList(internal.locomotionTracks, track, fade)
			if not track.IsPlaying then
				track:Play(fade, playWeight, speed)
			else
				track:AdjustWeight(playWeight, fade)
				track:AdjustSpeed(speed)
			end
			internal.currentLocomotionKey = resolvedKey
		else
			if not track.IsPlaying then
				track:Play(fade, playWeight, speed)
			end
			track:AdjustSpeed(speed)
		end

		return true
	end

	function runtime:stopLocomotion(fadeOverride: number?)
		local defaults = internal.profile.defaults or {}
		local fade = safeNumber(fadeOverride, safeNumber(defaults.fadeTime, 0.1))
		stopTrackList(internal.locomotionTracks, nil, fade)
		internal.currentLocomotionKey = nil
	end

	local function runActionTrigger(entry: AnimationEntry, track: AnimationTrack?, onTrigger: ((string) -> ())?)
		if not onTrigger then
			return
		end
		local defaults = internal.profile.defaults or {}
		local triggerMode = if type(entry.triggerMode) == "string" then string.lower(entry.triggerMode) else "instant"
		local triggerDelay = safeNumber(entry.triggerDelay, safeNumber(defaults.triggerDelay, 0.2))
		local fired = false
		local function fire(reason: string)
			if fired then
				return
			end
			fired = true
			onTrigger(reason)
		end

		if triggerMode == "marker" and track then
			local markerName = if type(entry.triggerMarkerName) == "string" and entry.triggerMarkerName ~= "" then entry.triggerMarkerName else "Launch"
			local okSignal, signalOrErr = pcall(function()
				return track:GetMarkerReachedSignal(markerName)
			end)
			if okSignal and signalOrErr then
				local conn: RBXScriptConnection? = nil
				conn = (signalOrErr :: RBXScriptSignal):Connect(function()
					if conn then
						conn:Disconnect()
					end
					fire("marker")
				end)
				task.delay(math.max(triggerDelay, 0.05), function()
					if conn then
						conn:Disconnect()
					end
					fire("marker_fallback")
				end)
			else
				warnOnce(internal, "marker_failed_" .. tostring(markerName), "Marker signal unavailable: " .. tostring(signalOrErr))
				task.delay(math.max(triggerDelay, 0), function()
					fire("delay_fallback")
				end)
			end
		elseif triggerMode == "delay" then
			task.delay(math.max(triggerDelay, 0), function()
				fire("delay")
			end)
		else
			fire("instant")
		end
	end

	function runtime:playAction(key: string): boolean
		return self:playActionWithTrigger(key, nil)
	end

	function runtime:playActionWithTrigger(key: string, onTrigger: ((string) -> ())?): boolean
		if internal.destroyed then
			return false
		end
		local actions = internal.profile.actions or {}
		local entry = actions[key]
		if entry == nil then
			warnOnce(internal, "missing_action_" .. tostring(key), "Action key missing: " .. tostring(key))
			if onTrigger then
				onTrigger("missing_action")
			end
			return false
		end

		local track = loadTrack(internal, internal.actionTracks, key, entry, "Action")
		if not track then
			if onTrigger then
				onTrigger("load_failed")
			end
			return false
		end

		local defaults = internal.profile.defaults or {}
		local fade = safeNumber(entry.fadeTime, safeNumber(defaults.fadeTime, 0.1))
		local speed = math.clamp(safeNumber(entry.speed, safeNumber(defaults.speed, 1)), 0.05, 4)
		local weight = safeNumber(entry.weight, safeNumber(defaults.weight, 1))

		stopTrackList(internal.actionTracks, track, fade)
		local okPlay, playErr = pcall(function()
			track:Play(fade, weight, speed)
		end)
		if not okPlay then
			warnOnce(internal, "play_failed_" .. tostring(key), "Track play failed key=" .. tostring(key) .. " err=" .. tostring(playErr))
			if onTrigger then
				onTrigger("play_failed")
			end
			return false
		end

		runActionTrigger(entry, track, onTrigger)
		return true
	end

	function runtime:destroy()
		if internal.destroyed then
			return
		end
		internal.destroyed = true
		stopTrackList(internal.locomotionTracks, nil, 0.05)
		stopTrackList(internal.actionTracks, nil, 0.05)
		table.clear(internal.locomotionTracks)
		table.clear(internal.actionTracks)
	end

	runtime.model = model
	runtime.humanoid = internal.humanoid
	runtime.animator = internal.animator
	runtime.profile = profile
	return runtime
end

return AnimationRuntimeCore
