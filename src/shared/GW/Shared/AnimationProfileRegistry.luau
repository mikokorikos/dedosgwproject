--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("AnimationProfiles")

local Types = require(script.Parent.Types)
local ConfigValidator = require(script.Parent.ConfigValidator)

type AnimationProfileConfig = Types.AnimationProfileConfig

local byId: {[string]: AnimationProfileConfig} = {}
local defaultId: string? = nil
local modules: {ModuleScript} = {}

for _, child in ipairs(folder:GetChildren()) do
	if child:IsA("ModuleScript") then
		table.insert(modules, child)
	end
end

table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

for _, mod in ipairs(modules) do
	local ok, result = pcall(require, mod)
	if not ok then
		error(string.format("[AnimationProfileRegistry] Error loading module '%s': %s", mod:GetFullName(), tostring(result)))
	end

	if type(result) ~= "table" then
		error(string.format(
			"[AnimationProfileRegistry] Module '%s' must return exactly one table value (got %s)",
			mod:GetFullName(),
			typeof(result)
		))
	end

	local cfg = result :: AnimationProfileConfig
	ConfigValidator.validateAnimationProfileConfig(mod:GetFullName(), cfg)
	if byId[cfg.id] ~= nil then
		error(string.format("[AnimationProfileRegistry] Duplicate id '%s' in module '%s'", cfg.id, mod:GetFullName()))
	end
	byId[cfg.id] = cfg
	if cfg.isDefault == true then
		defaultId = cfg.id
	end
end

if next(byId) == nil then
	error(string.format("[AnimationProfileRegistry] No animation profile configs were loaded from '%s'", folder:GetFullName()))
end

local function getDefaultId(): string
	if defaultId and byId[defaultId] then
		return defaultId
	end
	for id in pairs(byId) do
		return id
	end
	return "DefaultAnimationProfile"
end

local function get(id: string?): AnimationProfileConfig
	local resolvedId = if type(id) == "string" then id else getDefaultId()
	local cfg = byId[resolvedId] or byId[getDefaultId()]
	if not cfg then
		error("AnimationProfileRegistry has no configs loaded")
	end
	return cfg
end

return {
	ById = byId,
	DefaultId = getDefaultId(),
	Get = get,
}
