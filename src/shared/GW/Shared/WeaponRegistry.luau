--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("Weapons")

local Types = require(script.Parent.Types)
local ConfigValidator = require(script.Parent.ConfigValidator)
type WeaponConfig = Types.WeaponConfig

local DEBUG_REGISTRY = false

local function debugLog(...: any)
	if DEBUG_REGISTRY then
		print("[GW][WeaponRegistry]", ...)
	end
end

local function requireWeaponConfig(mod: ModuleScript): WeaponConfig
	debugLog("Loading", mod:GetFullName())

	local ok, result = pcall(require, mod)
	if not ok then
		error(string.format("[WeaponRegistry] Error loading module '%s': %s", mod:GetFullName(), tostring(result)))
	end

	if type(result) ~= "table" then
		error(string.format(
			"[WeaponRegistry] Module '%s' must return exactly one table value (got %s)",
			mod:GetFullName(),
			typeof(result)
		))
	end

	return result :: WeaponConfig
end

local byId: {[string]: WeaponConfig} = {}
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
	local cfg = requireWeaponConfig(mod)
	ConfigValidator.validateWeaponConfig(mod:GetFullName(), cfg)
	if byId[cfg.id] ~= nil then
		error(string.format("[WeaponRegistry] Duplicate id '%s' in module '%s'", cfg.id, mod:GetFullName()))
	end
	byId[cfg.id] = cfg
	if cfg.isDefault == true then
		defaultId = cfg.id
	end
end

if next(byId) == nil then
	error(string.format("[WeaponRegistry] No weapon configs were loaded from '%s'", folder:GetFullName()))
end

local function getDefaultId(): string
	if defaultId and byId[defaultId] then
		return defaultId
	end
	for id in pairs(byId) do
		return id
	end
	return "SoldierRifle"
end

local function get(id: string?): WeaponConfig
	local resolvedId = if type(id) == "string" then id else getDefaultId()
	local cfg = byId[resolvedId] or byId[getDefaultId()]
	if not cfg then
		error("WeaponRegistry has no configs loaded")
	end
	return cfg
end

return {
	ById = byId,
	DefaultId = getDefaultId(),
	Get = get,
}
