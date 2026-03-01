local RS = game:GetService("ReplicatedStorage")
local GW = RS:WaitForChild("GW")
local folder = GW:WaitForChild("Config"):WaitForChild("Abilities")

local byId = {}
for _, mod in ipairs(folder:GetChildren()) do
	if mod:IsA("ModuleScript") then
		local cfg = require(mod)
		if type(cfg) == "table" and type(cfg.id) == "string" then
			byId[cfg.id] = cfg
		end
	end
end

return {
	ById = byId,
	Get = function(id)
		if type(id) ~= "string" then return nil end
		return byId[id]
	end,
}
