--!strict
local RS = game:GetService("ReplicatedStorage")

local DamageUtil = require(RS.GW.Shared.DamageUtil)
local RaycastUtil = require(RS.GW.Shared.RaycastUtil)

export type TargetEntry = {
	humanoid: Humanoid,
	model: Model,
	rootPart: BasePart,
	distance: number,
}

export type CollectOptions = {
	allowFriendlyFire: boolean?,
	excludeInstances: {Instance}?,
	maxResults: number?,
	filter: ((humanoid: Humanoid, model: Model, rootPart: BasePart, distance: number) -> boolean)?,
}

local TargetingUtil = {}

local function getRootPart(model: Model, fallback: BasePart): BasePart
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return fallback
end

function TargetingUtil.collectHumanoidsInRadius(sourceEntity: any, origin: Vector3, radius: number, options: CollectOptions?): {TargetEntry}
	local opts = options or {}
	local allowFriendlyFire = opts.allowFriendlyFire == true
	local maxResults = math.max(1, math.floor(tonumber(opts.maxResults) or math.huge))

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = opts.excludeInstances or {}

	local parts = workspace:GetPartBoundsInRadius(origin, radius, overlap)
	local seen: {[Humanoid]: true} = {}
	local targets: {TargetEntry} = {}

	for _, part in ipairs(parts) do
		local hum, model = RaycastUtil.findHumanoidFromHit(part)
		if hum and model and hum.Health > 0 and not seen[hum] then
			seen[hum] = true
			if DamageUtil.canTarget(sourceEntity, hum, allowFriendlyFire) then
				local rootPart = getRootPart(model, part)
				local dist = (rootPart.Position - origin).Magnitude
				if not opts.filter or opts.filter(hum, model, rootPart, dist) then
					table.insert(targets, {
						humanoid = hum,
						model = model,
						rootPart = rootPart,
						distance = dist,
					})
				end
			end
		end
	end

	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)

	if #targets > maxResults then
		local trimmed: {TargetEntry} = table.create(maxResults)
		for i = 1, maxResults do
			trimmed[i] = targets[i]
		end
		return trimmed
	end

	return targets
end

function TargetingUtil.findClosestEnemyHumanoid(sourceEntity: any, origin: Vector3, radius: number, allowFriendlyFire: boolean, excludeInstances: {Instance}?): (Humanoid?, number?, BasePart?)
	local targets = TargetingUtil.collectHumanoidsInRadius(sourceEntity, origin, radius, {
		allowFriendlyFire = allowFriendlyFire,
		excludeInstances = excludeInstances,
		maxResults = 1,
	})
	local first = targets[1]
	if not first then
		return nil, nil, nil
	end
	return first.humanoid, first.distance, first.rootPart
end

return TargetingUtil
