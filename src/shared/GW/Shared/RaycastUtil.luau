--!strict
local RaycastUtil = {}

function RaycastUtil.hitscan(ignore: {Instance}?, origin: Vector3, dir: Vector3, maxDist: number): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = ignore or {}

	return workspace:Raycast(origin, dir.Unit * maxDist, params)
end

function RaycastUtil.findHumanoidFromHit(inst: Instance): (Humanoid?, Model?)
	local current: Instance? = inst
	while current and current ~= workspace do
		if current:IsA("Model") then
			local hum = current:FindFirstChildOfClass("Humanoid")
			if hum then return hum, current end
		end
		current = current.Parent
	end
	return nil, nil
end

return RaycastUtil
