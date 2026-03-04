--!strict

local shotEvent = Instance.new("BindableEvent")

local LocalEffectsBus = {}

function LocalEffectsBus.EmitShot(ev: {[string]: any})
	shotEvent:Fire(ev)
end

function LocalEffectsBus.OnShot(callback: (ev: {[string]: any}) -> ())
	return shotEvent.Event:Connect(callback)
end

return LocalEffectsBus
