--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("Weapons")

local Types = require(script.Parent.Types)
local ConfigValidator = require(script.Parent.ConfigValidator)
type WeaponConfig = Types.WeaponConfig

local byId: {[string]: WeaponConfig} = {}
local defaultId: string? = nil

for _, mod in ipairs(folder:GetChildren()) do
	if mod:IsA("ModuleScript") then
		local cfg = require(mod) :: WeaponConfig
		ConfigValidator.validateWeaponConfig(mod:GetFullName(), cfg)
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
	-- fallback: primer id
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
