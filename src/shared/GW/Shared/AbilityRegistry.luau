--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("Abilities")

local Types = require(script.Parent.Types)
type AbilityConfig = Types.AbilityConfig

local byId: {[string]: AbilityConfig} = {}
local defaultId: string? = nil

for _, mod in ipairs(folder:GetChildren()) do
	if mod:IsA("ModuleScript") then
		local cfg = require(mod) :: AbilityConfig
		if type(cfg) == "table" and type(cfg.id) == "string" then
			byId[cfg.id] = cfg
			if cfg.isDefault == true then
				defaultId = cfg.id
			end
		end
	end
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
