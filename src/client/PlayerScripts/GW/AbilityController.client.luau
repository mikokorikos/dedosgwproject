--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Characters = require(RS.GW.Shared.CharacterRegistry)
local Abilities = require(RS.GW.Shared.AbilityRegistry)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Ability")
local localCooldownEnd: {[string]: number} = {}

local function isTyping(): boolean
	local typing = UIS:GetFocusedTextBox() ~= nil
	log:trace("TextBox focused = " .. tostring(typing))
	return typing
end

local function getAimDirection(): Vector3
	local cam = workspace.CurrentCamera
	if not cam then
		log:warn("CurrentCamera not available; fallback direction will be used")
		return Vector3.new(0, 0, -1)
	end
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
	return ray.Direction.Unit
end

local function getAnimator(): Animator?
	local char = player.Character
	if not char then
		log:warn("Character not found")
		return nil
	end
	log:trace("Character resolved = " .. char:GetFullName())

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		log:warn("Humanoid not found")
		return nil
	end
	log:trace("Humanoid resolved = " .. hum:GetFullName())

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		log:warn("Animator not found; creating one")
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	log:trace("Animator resolved = " .. animator:GetFullName())
	return animator
end

local function normalizeAnimationId(animationId: string): string
	if string.match(animationId, "^%d+$") then
		return "rbxassetid://" .. animationId
	end
	return animationId
end

local function fireAbility(abilityId: string, triggerSource: string)
	local direction = getAimDirection()
	log:info(string.format("sending request -> abilityId = %s, trigger = %s", abilityId, triggerSource))
	Net.AbilityRequest:FireServer({
		abilityId = abilityId,
		direction = direction,
	})
end

local function playAnimAndFire(cfg: any, abilityId: string): boolean
	local rawAnimId = cfg.clientAnimId
	log:info("abilityId = " .. tostring(abilityId))
	log:info("animationId(raw) = " .. tostring(rawAnimId))

	if type(rawAnimId) ~= "string" or rawAnimId == "" then
		log:warn("AnimationId is missing/empty -> ability will fire without local animation")
		fireAbility(abilityId, "no_animation_id")
		return false
	end

	local animId = normalizeAnimationId(rawAnimId)
	log:info("animationId = " .. animId)

	local animator = getAnimator()
	if not animator then
		log:warn("Animator unavailable -> ability will fire without local animation")
		fireAbility(abilityId, "no_animator")
		return false
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	log:trace("Animation instance created")

	local okLoad, trackOrErr = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not okLoad or not trackOrErr then
		log:error("LoadAnimation failed: " .. tostring(trackOrErr))
		fireAbility(abilityId, "load_failed")
		return false
	end

	local track = trackOrErr
	log:info("LoadAnimation succeeded")
	track.Priority = Enum.AnimationPriority.Action

	local okPlay, playErr = pcall(function()
		track:Play(0.10, 1, 1.0)
	end)
	if not okPlay then
		log:error("Track failed to play: " .. tostring(playErr))
		fireAbility(abilityId, "play_failed")
		return false
	end
	log:info("Track Play() succeeded")

	local fired = false
	local function fireOnce(trigger: string)
		if fired then
			return
		end
		fired = true
		fireAbility(abilityId, trigger)
	end

	if cfg.useMarker == true then
		local marker = cfg.launchMarkerName or "Launch"
		log:trace("Marker mode enabled; marker = " .. tostring(marker))

		local okSignal, signalOrErr = pcall(function()
			return track:GetMarkerReachedSignal(marker)
		end)
		if okSignal and signalOrErr then
			log:trace("Marker signal connected")
			signalOrErr:Connect(function()
				log:trace("Marker reached -> firing ability request")
				fireOnce("marker")
			end)
		else
			log:warn("Marker signal unavailable: " .. tostring(signalOrErr))
		end
	else
		log:trace("Marker mode disabled; fallback timer will fire request")
	end

	local fallbackDelay = tonumber(cfg.fallbackLaunchDelay) or 0.35
	log:trace(string.format("fallbackLaunchDelay = %.2f", fallbackDelay))
	task.delay(fallbackDelay, function()
		fireOnce("fallback_delay")
	end)

	return true
end

local function getBinds()
	local rawCharacterId = player:GetAttribute("CharacterId")
	log:trace("CharacterId attribute = " .. tostring(rawCharacterId))

	local resolvedCharacterId = if typeof(rawCharacterId) == "string" then rawCharacterId else nil
	local charCfg = Characters.Get(resolvedCharacterId)
	log:trace("CharacterId resolved = " .. tostring(charCfg.id))

	local binds = charCfg.abilities or {}
	if #binds == 0 then
		log:warn("Character has no ability binds; fallback Q => BackRocket")
		return { { id = "BackRocket", key = "Q" } }
	end

	for index, bind in ipairs(binds) do
		log:trace(string.format("bind[%d] key=%s id=%s", index, tostring(bind.key), tostring(bind.id)))
	end
	return binds
end

local function tryUse(abilityId: string)
	log:info("tryUse requested abilityId = " .. tostring(abilityId))

	local cfg = Abilities.Get(abilityId)
	if not cfg then
		log:error("AbilityRegistry missing config for abilityId = " .. tostring(abilityId))
		return
	end
	log:trace("Ability config resolved id = " .. tostring(cfg.id))

	local now = os.clock()
	local cooldown = tonumber(cfg.cooldown) or 0
	local readyAt = localCooldownEnd[abilityId] or 0
	if now < readyAt then
		log:trace(string.format("local cooldown blocked (remaining=%.2fs)", readyAt - now))
		return
	end
	localCooldownEnd[abilityId] = now + cooldown
	log:trace(string.format("local cooldown passed (next=%.2f)", localCooldownEnd[abilityId]))

	local playedLocally = playAnimAndFire(cfg, abilityId)
	log:info("local animation played = " .. tostring(playedLocally))
end

UIS.InputBegan:Connect(function(input, gameProcessed)
	local qPressed = input.KeyCode == Enum.KeyCode.Q
	if qPressed then
		log:info("Q pressed")
	end

	local typing = isTyping()
	if qPressed then
		log:trace("gameProcessed = " .. tostring(gameProcessed))
		log:trace("isTyping = " .. tostring(typing))
	end

	if gameProcessed or typing then
		if qPressed then
			log:trace("Q ignored due to input guard")
		end
		return
	end

	for _, bind in ipairs(getBinds()) do
		local key = bind.key
		local keyCode: Enum.KeyCode? = nil

		if typeof(key) == "EnumItem" then
			keyCode = key
		elseif type(key) == "string" then
			keyCode = Enum.KeyCode[key]
		end

		if keyCode and input.KeyCode == keyCode then
			log:info("abilityId = " .. tostring(bind.id))
			tryUse(bind.id)
			return
		end
	end

	if qPressed then
		log:warn("Q pressed but no ability bind matched")
	end
end)

log:info("AbilityController ready (Q pipeline tracing enabled)")

