--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("Characters")

local Types = require(script.Parent.Types)
local AbilityRegistry = require(script.Parent.AbilityRegistry)
local WeaponRegistry = require(script.Parent.WeaponRegistry)
local ConfigValidator = require(script.Parent.ConfigValidator)
type CharacterConfig = Types.CharacterConfig

local byId: {[string]: CharacterConfig} = {}
local defaultId: string? = nil

for _, mod in ipairs(folder:GetChildren()) do
	if mod:IsA("ModuleScript") then
		local cfg = require(mod) :: CharacterConfig
		ConfigValidator.validateCharacterConfig(mod:GetFullName(), cfg, AbilityRegistry.ById, WeaponRegistry.ById)
		byId[cfg.id] = cfg
		if cfg.isDefault == true then
			defaultId = cfg.id
		end
	end
end

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
}
