--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Characters = require(RS.GW.Shared.CharacterRegistry)
local Abilities = require(RS.GW.Shared.AbilityRegistry)

local localCooldownEnd: {[string]: number} = {}

local function isTyping(): boolean
	return UIS:GetFocusedTextBox() ~= nil
end

local function getAimDirection(): Vector3
	local cam = workspace.CurrentCamera
	if not cam then return Vector3.new(0,0,-1) end
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X*0.5, vp.Y*0.5)
	return ray.Direction.Unit
end

local function getAnimator(): Animator?
	local char = player.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	return animator
end

local function fireAbility(abilityId: string)
	Net.AbilityRequest:FireServer({
		abilityId = abilityId,
		direction = getAimDirection(),
	})
end

local function playAnimAndFire(cfg: any, abilityId: string)
	local animId = cfg.clientAnimId
	if type(animId) ~= "string" or animId == "" then
		fireAbility(abilityId)
		return
	end

	local animator = getAnimator()
	if not animator then
		fireAbility(abilityId)
		return
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local ok, trackOrErr = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or not trackOrErr then
		fireAbility(abilityId)
		return
	end

	local track = trackOrErr
	track.Priority = Enum.AnimationPriority.Action
	pcall(function() track:Play(0.10, 1, 1.0) end)

	local fired = false
	local function fireOnce()
		if fired then return end
		fired = true
		fireAbility(abilityId)
	end

	if cfg.useMarker == true then
		local marker = cfg.launchMarkerName or "Launch"
		local ok2, sig = pcall(function()
			return track:GetMarkerReachedSignal(marker)
		end)
		if ok2 and sig then
			sig:Connect(function()
				fireOnce()
			end)
		end
	end

	task.delay(tonumber(cfg.fallbackLaunchDelay) or 0.35, fireOnce)
end

local function getBinds()
	local charId = player:GetAttribute("CharacterId")
	local charCfg = Characters.Get(typeof(charId)=="string" and charId or nil)
	local binds = charCfg.abilities or {}

	-- fallback: Q siempre = BackRocket si algo falla
	if #binds == 0 then
		return { { id="BackRocket", key="Q" } }
	end
	return binds
end

local function tryUse(abilityId: string)
	local cfg = Abilities.Get(abilityId)
	if not cfg then
		warn("[AbilityController] Missing ability config:", abilityId)
		return
	end
	local now = os.clock()
	local cd = tonumber(cfg.cooldown) or 0
	if now < (localCooldownEnd[abilityId] or 0) then return end
	localCooldownEnd[abilityId] = now + cd

	playAnimAndFire(cfg, abilityId)
end

UIS.InputBegan:Connect(function(input, gp)
	if gp or isTyping() then return end

	for _, bind in ipairs(getBinds()) do
		local key = bind.key
		local kc: Enum.KeyCode? = nil

		if typeof(key) == "EnumItem" then
			kc = key
		elseif type(key) == "string" then
			kc = Enum.KeyCode[key]
		end

		if kc and input.KeyCode == kc then
			tryUse(bind.id)
			return
		end
	end
end)

print("[GW] AbilityController activo (Q => BackRocket).")
