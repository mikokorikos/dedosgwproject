--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("Abilities")

local Types = require(script.Parent.Types)
local ConfigValidator = require(script.Parent.ConfigValidator)
type AbilityConfig = Types.AbilityConfig

local DEBUG_REGISTRY = false

local function debugLog(...: any)
	if DEBUG_REGISTRY then
		print("[GW][AbilityRegistry]", ...)
	end
end

local function requireAbilityConfig(mod: ModuleScript): AbilityConfig
	debugLog("Loading", mod:GetFullName())

	local ok, result = pcall(require, mod)
	if not ok then
		error(string.format("[AbilityRegistry] Error loading module '%s': %s", mod:GetFullName(), tostring(result)))
	end

	if type(result) ~= "table" then
		error(string.format(
			"[AbilityRegistry] Module '%s' must return exactly one table value (got %s)",
			mod:GetFullName(),
			typeof(result)
		))
	end

	return result :: AbilityConfig
end

local byId: {[string]: AbilityConfig} = {}
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
	local cfg = requireAbilityConfig(mod)
	ConfigValidator.validateAbilityConfig(mod:GetFullName(), cfg)
	if byId[cfg.id] ~= nil then
		error(string.format("[AbilityRegistry] Duplicate id '%s' in module '%s'", cfg.id, mod:GetFullName()))
	end
	byId[cfg.id] = cfg
	if cfg.isDefault == true then
		defaultId = cfg.id
	end
end

if next(byId) == nil then
	error(string.format("[AbilityRegistry] No ability configs were loaded from '%s'", folder:GetFullName()))
end

local function getDefaultId(): string?
	if defaultId and byId[defaultId] then
		return defaultId
	end
	for id in pairs(byId) do
		return id
	end
	return nil
end

local function get(id: string?): AbilityConfig?
	if type(id) ~= "string" then
		local fallbackId = getDefaultId()
		if not fallbackId then
			return nil
		end
		return byId[fallbackId]
	end
	return byId[id]
end

return {
	ById = byId,
	DefaultId = getDefaultId(),
	Get = get,
}
