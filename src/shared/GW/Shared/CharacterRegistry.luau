--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("Characters")

local Types = require(script.Parent.Types)
local AbilityRegistry = require(script.Parent.AbilityRegistry)
local WeaponRegistry = require(script.Parent.WeaponRegistry)
local PlantableRegistry = require(script.Parent.PlantableRegistry)
local AnimationProfileRegistry = require(script.Parent.AnimationProfileRegistry)
local ConfigValidator = require(script.Parent.ConfigValidator)
local RegistryLinker = require(script.Parent.RegistryLinker)
type CharacterConfig = Types.CharacterConfig

local DEBUG_REGISTRY = false

local function debugLog(...: any)
	if DEBUG_REGISTRY then
		print("[GW][CharacterRegistry]", ...)
	end
end

local function requireCharacterConfig(mod: ModuleScript): CharacterConfig
	debugLog("Loading", mod:GetFullName())

	local ok, result = pcall(require, mod)
	if not ok then
		error(string.format("[CharacterRegistry] Error loading module '%s': %s", mod:GetFullName(), tostring(result)))
	end

	if type(result) ~= "table" then
		error(string.format(
			"[CharacterRegistry] Module '%s' must return exactly one table value (got %s)",
			mod:GetFullName(),
			typeof(result)
		))
	end

	return result :: CharacterConfig
end

local byId: {[string]: CharacterConfig} = {}
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
	local cfg = requireCharacterConfig(mod)
	ConfigValidator.validateCharacterConfig(mod:GetFullName(), cfg, AbilityRegistry.ById, WeaponRegistry.ById, AnimationProfileRegistry.ById, PlantableRegistry.ById)
	if byId[cfg.id] ~= nil then
		error(string.format("[CharacterRegistry] Duplicate id '%s' in module '%s'", cfg.id, mod:GetFullName()))
	end
	byId[cfg.id] = cfg
	if cfg.isDefault == true then
		defaultId = cfg.id
	end
end

if next(byId) == nil then
	error(string.format("[CharacterRegistry] No character configs were loaded from '%s'", folder:GetFullName()))
end

local linked = RegistryLinker.link(AbilityRegistry.ById, WeaponRegistry.ById, byId, PlantableRegistry.ById)

local function getDefaultId(): string
	if defaultId and byId[defaultId] then
		return defaultId
	end
	for id in pairs(byId) do
		return id
	end
	return "Soldier"
end

local function get(id: string?): CharacterConfig
	local resolvedId = if type(id) == "string" then id else getDefaultId()
	local cfg = byId[resolvedId] or byId[getDefaultId()]
	if not cfg then
		error("CharacterRegistry has no configs loaded")
	end
	return cfg
end

return {
	ById = byId,
	DefaultId = getDefaultId(),
	Get = get,
	AbilityToCharacterIds = linked.abilityToCharacterIds,
	PlantableToCharacterIds = linked.plantableToCharacterIds,
}
