local AssetResolver = {}

local function parts(path)
	local t = {}
	for p in string.gmatch(path, "[^/]+") do
		table.insert(t, p)
	end
	return t
end

function AssetResolver.resolve(root, path)
	if typeof(path) ~= "string" or path == "" then return nil end
	if not string.find(path, "/", 1, true) then
		return root:FindFirstChild(path)
	end
	local cur = root
	for _, p in ipairs(parts(path)) do
		cur = cur:FindFirstChild(p)
		if not cur then return nil end
	end
	return cur
end

return AssetResolver
