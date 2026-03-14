--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("Plantables")

local Types = require(script.Parent.Types)
local ConfigValidator = require(script.Parent.ConfigValidator)
local DeployableRegistry = require(script.Parent.DeployableRegistry)
type PlantableConfig = Types.PlantableConfig

local DEBUG_REGISTRY = false

local function debugLog(...: any)
	if DEBUG_REGISTRY then
		print("[GW][PlantableRegistry]", ...)
	end
end

local function requirePlantableConfig(mod: ModuleScript): PlantableConfig
	debugLog("Loading", mod:GetFullName())

	local ok, result = pcall(require, mod)
	if not ok then
		error(string.format("[PlantableRegistry] Error loading module '%s': %s", mod:GetFullName(), tostring(result)))
	end

	if type(result) ~= "table" then
		error(string.format(
			"[PlantableRegistry] Module '%s' must return exactly one table value (got %s)",
			mod:GetFullName(),
			typeof(result)
		))
	end

	return result :: PlantableConfig
end

local byId: {[string]: PlantableConfig} = {}
local defaultId: string? = nil
local modules: {ModuleScript} = {}

for _, child in ipairs(folder:GetChildren()) do
	if child:IsA("ModuleScript") then
		table.insert(modules, child)
	else
		debugLog(string.format("Skipping non-ModuleScript child '%s' (%s)", child:GetFullName(), child.ClassName))
	end
end

table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

for _, mod in ipairs(modules) do
	local cfg = requirePlantableConfig(mod)
	ConfigValidator.validatePlantableConfig(mod:GetFullName(), cfg, DeployableRegistry.ById)
	if byId[cfg.id] ~= nil then
		error(string.format("[PlantableRegistry] Duplicate id '%s' in module '%s'", cfg.id, mod:GetFullName()))
	end
	byId[cfg.id] = cfg
	if cfg.isDefault == true then
		defaultId = cfg.id
	end
end

if next(byId) == nil then
	error(string.format("[PlantableRegistry] No plantable configs were loaded from '%s'", folder:GetFullName()))
end

local function getDefaultId(): string
	if defaultId and byId[defaultId] then
		return defaultId
	end
	for id in pairs(byId) do
		return id
	end
	return "PlantZombieSpotExploder"
end

local function get(id: string?): PlantableConfig
	local resolvedId = if type(id) == "string" then id else getDefaultId()
	local cfg = byId[resolvedId] or byId[getDefaultId()]
	if not cfg then
		error("PlantableRegistry has no configs loaded")
	end
	return cfg
end

return {
	ById = byId,
	DefaultId = getDefaultId(),
	Get = get,
}
