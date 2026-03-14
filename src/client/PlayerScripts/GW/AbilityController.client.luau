--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Characters = require(RS.GW.Shared.CharacterRegistry)
local Abilities = require(RS.GW.Shared.AbilityRegistry)
local ClientAnimationService = require(RS.GW.Shared.ClientAnimationService)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Ability")
local localCooldownEnd: {[string]: number} = {}

type AbilityBind = {
	id: string,
	key: string?,
	animationActionKey: string?,
}

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

local function fireAbility(abilityId: string, triggerSource: string)
	local direction = getAimDirection()
	log:info(string.format("sending request -> abilityId = %s, trigger = %s", abilityId, triggerSource))
	Net.AbilityRequest:FireServer({
		abilityId = abilityId,
		direction = direction,
	})
end

local function getBinds(): {AbilityBind}
	local rawCharacterId = player:GetAttribute("CharacterId")
	log:trace("CharacterId attribute = " .. tostring(rawCharacterId))

	local resolvedCharacterId = if typeof(rawCharacterId) == "string" then rawCharacterId else nil
	local charCfg = Characters.Get(resolvedCharacterId)
	log:trace("CharacterId resolved = " .. tostring(charCfg.id))

	local binds = (charCfg.abilities or {}) :: {AbilityBind}
	if #binds == 0 then
		log:warn("Character has no ability binds; fallback Q => BackRocket")
		return { { id = "BackRocket", key = "Q", animationActionKey = "AbilityQ" } }
	end

	for index, bind in ipairs(binds) do
		log:trace(string.format("bind[%d] key=%s id=%s action=%s", index, tostring(bind.key), tostring(bind.id), tostring(bind.animationActionKey)))
	end
	return binds
end

local function tryUse(bind: AbilityBind)
	local abilityId = bind.id
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

	local actionKey = ClientAnimationService.resolveAbilityActionKey(bind.key, bind.animationActionKey)
	log:info("ability action key = " .. tostring(actionKey))

	local fired = false
	local function fireOnce(trigger: string)
		if fired then
			return
		end
		fired = true
		fireAbility(abilityId, trigger)
	end

	local playedLocally = ClientAnimationService.playActionWithTrigger(actionKey, function(triggerReason)
		fireOnce("anim_" .. tostring(triggerReason))
	end)
	log:info("local action played = " .. tostring(playedLocally))

	if not playedLocally then
		fireOnce("no_animation_action")
	end

	-- Hard safety: runtime should trigger, but never allow dropped request.
	task.delay(0.75, function()
		fireOnce("failsafe")
	end)
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
		local keyCode: Enum.KeyCode? = if type(key) == "string" then Enum.KeyCode[key] else nil

		if keyCode and input.KeyCode == keyCode then
			log:info("abilityId = " .. tostring(bind.id))
			tryUse(bind)
			return
		end
	end

	if qPressed then
		log:warn("Q pressed but no ability bind matched")
	end
end)

ClientAnimationService.ensureInitialized()
log:info("AbilityController ready (character-driven animation actions enabled)")
