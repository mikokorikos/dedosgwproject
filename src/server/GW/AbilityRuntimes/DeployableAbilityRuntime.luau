--!strict
local RS = game:GetService("ReplicatedStorage")

local DeployableService = require(script.Parent.Parent.DeployableService)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("AbilityDeployable")

local DeployableAbilityRuntime = {}

function DeployableAbilityRuntime.tryExecute(player: Player, payload: any, cfg: any, hrp: BasePart): (boolean, string?)
	if type(cfg.deployableId) ~= "string" or cfg.deployableId == "" then
		return false, nil
	end

	local dir = payload.direction
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.01 then
		dir = hrp.CFrame.LookVector
	end
	dir = dir.Unit

	local spawnForward = tonumber(cfg.deployableSpawnForwardOffset) or 4.0
	local spawnUp = tonumber(cfg.deployableSpawnUpOffset) or 0.0
	local spawnPos = hrp.Position + dir * spawnForward + Vector3.new(0, spawnUp, 0)
	local spawnCFrame = CFrame.lookAt(spawnPos, spawnPos + dir)

	log:info(string.format(
		"Deployable ability request -> ability=%s deployableId=%s",
		tostring(cfg.id),
		tostring(cfg.deployableId)
	))

	local spawnResult, spawnErr = DeployableService.spawn(player, cfg.deployableId, spawnCFrame)
	if not spawnResult then
		return true, tostring(spawnErr)
	end

	if cfg.deployableUsePrototypeRunner == true then
		DeployableService.runPrototype(spawnResult)
		log:trace("Deployable prototype runner started")
	end

	return true, nil
end

return DeployableAbilityRuntime
