--!strict
local RS = game:GetService("ReplicatedStorage")

local AnimationProfiles = require(RS.GW.Shared.AnimationProfileRegistry)
local AnimationRuntimeCore = require(RS.GW.Shared.AnimationRuntimeCore)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("AnimServer")

local ServerAnimationService = {}

local runtimeByModel = setmetatable({}, { __mode = "k" }) :: {[Model]: AnimationRuntimeCore.Runtime}
local ancestryConnByModel = setmetatable({}, { __mode = "k" }) :: {[Model]: RBXScriptConnection}

local function cleanupModel(model: Model)
	local runtime = runtimeByModel[model]
	if runtime then
		runtime:destroy()
		runtimeByModel[model] = nil
	end
	local conn = ancestryConnByModel[model]
	if conn then
		conn:Disconnect()
		ancestryConnByModel[model] = nil
	end
end

function ServerAnimationService.ensureRuntime(model: Model, profileId: string?): AnimationRuntimeCore.Runtime?
	if not model or model.Parent == nil then
		return nil
	end

	local existing = runtimeByModel[model]
	if existing then
		return existing
	end

	local resolvedProfileId = profileId
	if type(resolvedProfileId) ~= "string" or resolvedProfileId == "" then
		local attrProfileId = model:GetAttribute("AnimationProfileId")
		if type(attrProfileId) == "string" and attrProfileId ~= "" then
			resolvedProfileId = attrProfileId
		end
	end
	if type(resolvedProfileId) ~= "string" or resolvedProfileId == "" then
		resolvedProfileId = AnimationProfiles.DefaultId
	end

	local profile = AnimationProfiles.Get(resolvedProfileId)
	local runtime = AnimationRuntimeCore.create(model, profile)
	runtimeByModel[model] = runtime

	local conn = model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			cleanupModel(model)
		end
	end)
	ancestryConnByModel[model] = conn

	log:trace(string.format("Runtime created model=%s profile=%s", model:GetFullName(), profile.id))
	return runtime
end

function ServerAnimationService.playAction(model: Model, actionKey: string): boolean
	local runtime = ServerAnimationService.ensureRuntime(model, nil)
	if not runtime then
		return false
	end
	return runtime:playAction(actionKey)
end

function ServerAnimationService.setLocomotionState(model: Model, locomotionKey: string, speedScale: number?): boolean
	local runtime = ServerAnimationService.ensureRuntime(model, nil)
	if not runtime then
		return false
	end
	return runtime:setLocomotionState(locomotionKey, speedScale)
end

function ServerAnimationService.stopLocomotion(model: Model, fadeTime: number?)
	local runtime = ServerAnimationService.ensureRuntime(model, nil)
	if not runtime then
		return
	end
	runtime:stopLocomotion(fadeTime)
end

function ServerAnimationService.cleanupModel(model: Model)
	cleanupModel(model)
end

return ServerAnimationService
