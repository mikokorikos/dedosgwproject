--!strict
local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("Weapons")

local byId: {[string]: any} = {}
local defaultId: string? = nil

for _, mod in ipairs(folder:GetChildren()) do
	if mod:IsA("ModuleScript") then
		local cfg = require(mod)
		if type(cfg) == "table" and type(cfg.id) == "string" then
			byId[cfg.id] = cfg
			if cfg.isDefault == true then
				defaultId = cfg.id
			end
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

return {
	ById = byId,
	DefaultId = getDefaultId(),
	Get = function(id: string?): any
		if type(id) ~= "string" then
			id = getDefaultId()
		end
		return byId[id] or byId[getDefaultId()]
	end,
}
