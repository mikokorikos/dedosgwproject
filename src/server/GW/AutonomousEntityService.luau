--!strict
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Autonomous")

export type RuntimeEntry = {
	model: Model,
	kind: string,
	state: {[string]: any},
	stepInterval: number,
	stepAccumulator: number,
	createdAt: number,
	onStep: ((entry: RuntimeEntry, dt: number) -> ())?,
	onCleanup: ((entry: RuntimeEntry, reason: string) -> ())?,
	connections: {RBXScriptConnection},
}

export type RegisterOptions = {
	kind: string?,
	state: {[string]: any}?,
	stepInterval: number?,
	onStep: ((entry: RuntimeEntry, dt: number) -> ())?,
	onCleanup: ((entry: RuntimeEntry, reason: string) -> ())?,
}

local AutonomousEntityService = {}

local entriesByModel: {[Model]: RuntimeEntry} = {}
local heartbeatConn: RBXScriptConnection? = nil

local function disconnectEntryConnections(entry: RuntimeEntry)
	for _, conn in ipairs(entry.connections) do
		conn:Disconnect()
	end
	table.clear(entry.connections)
end

local function ensureLoop()
	if heartbeatConn then
		return
	end

	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		for model, entry in pairs(entriesByModel) do
			if not model.Parent then
				AutonomousEntityService.stop(model, "model_removed")
			else
				if entry.stepInterval > 0 then
					entry.stepAccumulator += dt
					if entry.stepAccumulator < entry.stepInterval then
						continue
					end
					dt = entry.stepAccumulator
					entry.stepAccumulator = 0
				end

				if entry.onStep then
					local ok, err = pcall(entry.onStep, entry, dt)
					if not ok then
						log:error(string.format(
							"Autonomous step error -> kind=%s model=%s err=%s",
							entry.kind,
							model:GetFullName(),
							tostring(err)
						))
						AutonomousEntityService.stop(model, "step_error")
					end
				end
			end
		end
	end)
end

local function maybeStopLoop()
	if next(entriesByModel) ~= nil then
		return
	end
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

function AutonomousEntityService.register(model: Model, options: RegisterOptions?): RuntimeEntry
	local opts = options or {}
	if entriesByModel[model] then
		AutonomousEntityService.stop(model, "replaced")
	end

	local entry: RuntimeEntry = {
		model = model,
		kind = if type(opts.kind) == "string" and opts.kind ~= "" then opts.kind else "GenericAutonomous",
		state = opts.state or {},
		stepInterval = math.max(0, tonumber(opts.stepInterval) or 0),
		stepAccumulator = 0,
		createdAt = os.clock(),
		onStep = opts.onStep,
		onCleanup = opts.onCleanup,
		connections = {},
	}

	entriesByModel[model] = entry
	table.insert(entry.connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			AutonomousEntityService.stop(model, "ancestry_removed")
		end
	end))

	log:info(string.format("Registered autonomous entity -> kind=%s model=%s", entry.kind, model:GetFullName()))
	ensureLoop()
	return entry
end

function AutonomousEntityService.bindConnection(model: Model, connection: RBXScriptConnection)
	local entry = entriesByModel[model]
	if not entry then
		connection:Disconnect()
		return
	end
	table.insert(entry.connections, connection)
end

function AutonomousEntityService.getEntry(model: Model): RuntimeEntry?
	return entriesByModel[model]
end

function AutonomousEntityService.isRegistered(model: Model): boolean
	return entriesByModel[model] ~= nil
end

function AutonomousEntityService.stop(model: Model, reason: string?)
	local entry = entriesByModel[model]
	if not entry then
		return
	end

	entriesByModel[model] = nil
	disconnectEntryConnections(entry)

	local cleanupReason = if type(reason) == "string" and reason ~= "" then reason else "stopped"
	if entry.onCleanup then
		local ok, err = pcall(entry.onCleanup, entry, cleanupReason)
		if not ok then
			log:error(string.format(
				"Cleanup callback failed -> kind=%s model=%s err=%s",
				entry.kind,
				model:GetFullName(),
				tostring(err)
			))
		end
	end

	log:trace(string.format("Stopped autonomous entity -> kind=%s model=%s reason=%s", entry.kind, model:GetFullName(), cleanupReason))
	maybeStopLoop()
end

function AutonomousEntityService.count(): number
	local total = 0
	for _ in pairs(entriesByModel) do
		total += 1
	end
	return total
end

return AutonomousEntityService
