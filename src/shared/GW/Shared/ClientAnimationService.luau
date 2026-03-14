--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local CharacterRegistry = require(RS.GW.Shared.CharacterRegistry)
local AnimationKeys = require(RS.GW.Shared.AnimationKeys)
local AnimationProfiles = require(RS.GW.Shared.AnimationProfileRegistry)
local AnimationRuntimeCore = require(RS.GW.Shared.AnimationRuntimeCore)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("AnimClient")

local ClientAnimationService = {}

local player = Players.LocalPlayer
local initialized = false
local characterAddedConn: RBXScriptConnection? = nil
local characterRemovingConn: RBXScriptConnection? = nil
local heartbeatConn: RBXScriptConnection? = nil
local characterIdChangedConn: RBXScriptConnection? = nil
local profileChangedConn: RBXScriptConnection? = nil

local currentCharacter: Model? = nil
local currentRuntime: AnimationRuntimeCore.Runtime? = nil
local currentProfileId: string? = nil

local function getHorizontalSpeed(character: Model): number
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return 0
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function resolveProfileId(character: Model?): string
	if character then
		local byCharacter = character:GetAttribute("AnimationProfileId")
		if type(byCharacter) == "string" and byCharacter ~= "" then
			return byCharacter
		end
	end

	local byPlayer = player:GetAttribute("AnimationProfileId")
	if type(byPlayer) == "string" and byPlayer ~= "" then
		return byPlayer
	end

	local characterId = player:GetAttribute("CharacterId")
	local characterCfg = CharacterRegistry.Get(if type(characterId) == "string" then characterId else nil)
	if type(characterCfg.animationProfileId) == "string" and characterCfg.animationProfileId ~= "" then
		return characterCfg.animationProfileId
	end

	return AnimationProfiles.DefaultId
end

local function cleanupRuntime()
	if currentRuntime then
		currentRuntime:destroy()
	end
	currentRuntime = nil
	currentCharacter = nil
	currentProfileId = nil
end

local function bindRuntimeToCharacter(character: Model)
	if currentCharacter == character and currentRuntime then
		return
	end
	cleanupRuntime()

	local profileId = resolveProfileId(character)
	local profile = AnimationProfiles.Get(profileId)
	currentCharacter = character
	currentProfileId = profile.id
	currentRuntime = AnimationRuntimeCore.create(character, profile)

	if not currentRuntime.humanoid then
		log:warn(string.format("Humanoid missing -> animation runtime degraded character=%s", character:GetFullName()))
	else
		log:info(string.format("Animation runtime bound -> character=%s profile=%s", character:GetFullName(), profile.id))
	end
end

local function computeLocomotionState(runtime: AnimationRuntimeCore.Runtime, speed: number): (string, number)
	local profile = runtime.profile
	local defaults = profile.defaults or {}
	local runThresholdRatio = tonumber(defaults.runThresholdRatio) or 0.75
	local state = runtime.humanoid and runtime.humanoid:GetState() or Enum.HumanoidStateType.Running

	if state == Enum.HumanoidStateType.Dead then
		return AnimationKeys.Locomotion.Death, 1
	end
	if state == Enum.HumanoidStateType.Jumping then
		return AnimationKeys.Locomotion.Jump, 1
	end
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown then
		return AnimationKeys.Locomotion.Fall, 1
	end

	local moveThreshold = 0.15
	if speed <= moveThreshold then
		return AnimationKeys.Locomotion.Idle, 1
	end

	local walkSpeed = 16
	if runtime.humanoid and runtime.humanoid.WalkSpeed > 0 then
		walkSpeed = runtime.humanoid.WalkSpeed
	end

	if speed >= (walkSpeed * runThresholdRatio) then
		local runCfg = profile.locomotion and profile.locomotion.Run
		local ref = tonumber(runCfg and runCfg.referenceSpeed) or walkSpeed
		return AnimationKeys.Locomotion.Run, math.clamp(speed / math.max(ref, 0.1), 0.6, 2.8)
	end

	local walkCfg = profile.locomotion and profile.locomotion.Walk
	local ref = tonumber(walkCfg and walkCfg.referenceSpeed) or math.max(walkSpeed * 0.6, 0.1)
	return AnimationKeys.Locomotion.Walk, math.clamp(speed / math.max(ref, 0.1), 0.6, 2.8)
end

local function stepLocomotion(_dt: number)
	if not currentRuntime or not currentCharacter or not currentCharacter.Parent then
		return
	end
	if not currentRuntime.humanoid then
		return
	end

	local speed = getHorizontalSpeed(currentCharacter)
	local locomotionKey, speedScale = computeLocomotionState(currentRuntime, speed)
	currentRuntime:setLocomotionState(locomotionKey, speedScale)
end

function ClientAnimationService.ensureInitialized()
	if initialized then
		return
	end
	initialized = true

	characterAddedConn = player.CharacterAdded:Connect(function(character)
		bindRuntimeToCharacter(character)
	end)
	characterRemovingConn = player.CharacterRemoving:Connect(function(character)
		if currentCharacter == character then
			cleanupRuntime()
		end
	end)
	characterIdChangedConn = player:GetAttributeChangedSignal("CharacterId"):Connect(function()
		if player.Character then
			bindRuntimeToCharacter(player.Character)
		end
	end)
	profileChangedConn = player:GetAttributeChangedSignal("AnimationProfileId"):Connect(function()
		if player.Character then
			bindRuntimeToCharacter(player.Character)
		end
	end)
	heartbeatConn = RunService.Heartbeat:Connect(stepLocomotion)

	if player.Character then
		bindRuntimeToCharacter(player.Character)
	end

	log:info("ClientAnimationService initialized")
end

function ClientAnimationService.bindCharacter(character: Model)
	ClientAnimationService.ensureInitialized()
	bindRuntimeToCharacter(character)
end

function ClientAnimationService.getCurrentProfileId(): string?
	return currentProfileId
end

function ClientAnimationService.resolveAbilityActionKey(bindKey: string?, explicitActionKey: string?): string
	if type(explicitActionKey) == "string" and explicitActionKey ~= "" then
		return explicitActionKey
	end
	return AnimationKeys.actionFromBindKey(bindKey)
end

function ClientAnimationService.playAction(actionKey: string): boolean
	ClientAnimationService.ensureInitialized()
	if not currentRuntime then
		log:warn("playAction skipped: runtime unavailable")
		return false
	end
	return currentRuntime:playAction(actionKey)
end

function ClientAnimationService.playActionWithTrigger(actionKey: string, onTrigger: ((string) -> ())?): boolean
	ClientAnimationService.ensureInitialized()
	if not currentRuntime then
		log:warn("playActionWithTrigger skipped: runtime unavailable")
		if onTrigger then
			onTrigger("no_runtime")
		end
		return false
	end
	return currentRuntime:playActionWithTrigger(actionKey, onTrigger)
end

function ClientAnimationService.shutdown()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if characterAddedConn then
		characterAddedConn:Disconnect()
		characterAddedConn = nil
	end
	if characterRemovingConn then
		characterRemovingConn:Disconnect()
		characterRemovingConn = nil
	end
	if characterIdChangedConn then
		characterIdChangedConn:Disconnect()
		characterIdChangedConn = nil
	end
	if profileChangedConn then
		profileChangedConn:Disconnect()
		profileChangedConn = nil
	end
	cleanupRuntime()
	initialized = false
end

return ClientAnimationService
