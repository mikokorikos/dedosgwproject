--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local DamageUtil = require(RS.GW.Shared.DamageUtil)
local AnimationKeys = require(RS.GW.Shared.AnimationKeys)
local RaycastUtil = require(RS.GW.Shared.RaycastUtil)
local Logger = require(RS.GW.Shared.Logger)
local AutonomousEntityService = require(script.Parent.Parent.AutonomousEntityService)

local log = Logger.scoped("DeployableLegendary")

local Runtime = {}

local function getTargetRoot(model: Model, fallbackPart: BasePart): BasePart
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	return fallbackPart
end

local function isOwnerHumanoid(ownerUserId: number?, targetHumanoid: Humanoid): boolean
	if type(ownerUserId) ~= "number" then
		return false
	end
	local targetModel = targetHumanoid.Parent
	if not targetModel or not targetModel:IsA("Model") then
		return false
	end
	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	if not targetPlayer then
		return false
	end
	return targetPlayer.UserId == ownerUserId
end

local function randomPatrolOffset(rng: Random, halfSize: number): Vector3
	local x = rng:NextNumber(-halfSize, halfSize)
	local z = rng:NextNumber(-halfSize, halfSize)
	return Vector3.new(x, 0, z)
end

local function randomChainOffset(rng: Random, halfSize: number): Vector3
	local x = rng:NextNumber(-halfSize, halfSize)
	local z = rng:NextNumber(-halfSize, halfSize)
	local y = rng:NextNumber(-halfSize * 0.45, halfSize * 0.45)
	return Vector3.new(x, y, z)
end

function Runtime.run(spawnResult: any, deps: any)
	local model = spawnResult.model :: Model
	local body = spawnResult.body :: BasePart
	local behavior = spawnResult.behavior or spawnResult.config

	local ownerUserId = DamageUtil.resolveOwnerUserId(model) or DamageUtil.resolveSummonerUserId(model)
	local deployableId = tostring(behavior.id or model:GetAttribute("DeployableId") or model.Name)
	local displayName = tostring(behavior.displayName or model:GetAttribute("DeployableDisplayName") or deployableId)

	local moveSpeed = math.max(0, tonumber(behavior.MoveSpeed) or 0)
	local detectionRadius = math.max(0.1, tonumber(behavior.DetectionRadius) or 28)
	local retargetInterval = math.max(0.05, tonumber(behavior.RetargetInterval) or 0.25)
	local loseTargetDistance = math.max(detectionRadius, tonumber(behavior.LoseTargetDistance) or (detectionRadius * 1.5))
	local patrolEnabled = behavior.PatrolEnabled ~= false
	local patrolRadius = math.max(0, tonumber(behavior.PatrolRadius) or 16)
	local patrolStepInterval = math.max(0.1, tonumber(behavior.PatrolStepInterval) or 0.8)
	local triggerRadius = math.max(0.1, tonumber(behavior.TriggerRadius) or 4.5)
	local triggerOnTouch = behavior.TriggerOnTouch == true
	local canDamageAllies = behavior.CanDamageAllies == true
	local canDamageOwner = behavior.CanDamageOwner == true

	local armDelay = math.max(0, tonumber(behavior.ArmDelay) or 2.0)
	local stopOnArm = behavior.StopOnArm ~= false
	local armingSoundName = behavior.ArmingSoundName
	local armingFxName = behavior.ArmingFxName

	local mainExplosionDamage = math.max(0, tonumber(behavior.ExplosionDamage) or 40)
	local mainExplosionRadius = math.max(0.1, tonumber(behavior.ExplosionRadius) or 11)
	local mainExplosionSoundName = behavior.ExplosionSoundName
	local mainExplosionFxName = behavior.ExplosionFxName
	local mainExplosionKnockback = math.max(0, tonumber(behavior.ExplosionKnockback) or 0)

	local chainEnabled = behavior.ChainEnabled == true
	local chainDuration = math.max(0, tonumber(behavior.ChainDuration) or 0)
	local chainInterval = math.max(0.05, tonumber(behavior.ChainInterval) or 0.35)
	local chainAreaHalfSize = math.max(0, tonumber(behavior.ChainAreaHalfSize) or 16)
	local chainExplosionDamage = math.max(0, tonumber(behavior.ChainExplosionDamage) or 20)
	local chainExplosionRadius = math.max(0.1, tonumber(behavior.ChainExplosionRadius) or 8)
	local chainExplosionSoundName = behavior.ChainExplosionSoundName
	local chainExplosionFxName = behavior.ChainExplosionFxName
	local chainExplosionKnockback = math.max(0, tonumber(behavior.ChainExplosionKnockback) or 0)
	local chainExplosionCount = math.max(0, math.floor(tonumber(behavior.ChainExplosionCount) or 0))

	local killBellEnabled = behavior.KillBellEnabled ~= false
	local killBellSoundName = behavior.KillBellSoundName
	local lifetime = math.max(0.1, tonumber(behavior.Lifetime) or 12)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rng = Random.new(math.floor(os.clock() * 1000) % 10_000_000)
	local spawnOrigin = body.Position
	local currentState = "Patrol"
	local currentTargetHumanoid: Humanoid? = nil
	local currentTargetRoot: BasePart? = nil
	local nextRetargetAt = 0.0
	local nextPatrolAt = 0.0
	local patrolPoint: Vector3? = nil
	local armingEndAt = 0.0
	local isArming = false
	local isDetonated = false

	model:SetAttribute("DeployableState", currentState)
	model:SetAttribute("Arming", false)
	if deps.playAction then
		deps.playAction(model, AnimationKeys.Actions.Deploy)
	end

	local function setState(nextState: string)
		if currentState == nextState then
			return
		end
		currentState = nextState
		model:SetAttribute("DeployableState", nextState)
		log:trace(string.format("State change -> id=%s state=%s", deployableId, nextState))
	end

	local function clearTarget()
		currentTargetHumanoid = nil
		currentTargetRoot = nil
	end

	local function applyMovementToward(targetPos: Vector3, dt: number)
		if moveSpeed <= 0 then
			return
		end
		if humanoid then
			humanoid.WalkSpeed = moveSpeed
			humanoid:MoveTo(targetPos)
			return
		end
		local fromPos = body.Position
		local toTarget = targetPos - fromPos
		if toTarget.Magnitude < 0.001 then
			return
		end
		local step = math.min(toTarget.Magnitude, moveSpeed * dt)
		local nextPos = fromPos + toTarget.Unit * step
		model:PivotTo(CFrame.lookAt(nextPos, nextPos + toTarget.Unit))
	end

	local function runChainExplosions(centerPos: Vector3)
		if not chainEnabled then
			return
		end
		if chainDuration <= 0 then
			return
		end
		local anchorModel, anchorBody = deps.createDetachedChainRuntimeAnchor(model, centerPos)
		if not anchorModel or not anchorBody then
			log:warn("Chain explosion runner skipped: failed to create runtime anchor")
			return
		end

		local chainEndAt = os.clock() + chainDuration
		local emitted = 0
		local nextExplosionAt = os.clock() + 0.05

		AutonomousEntityService.register(anchorModel, {
			kind = "DeployableChainRunner",
			stepInterval = 0,
			state = {
				chainEndAt = chainEndAt,
			},
			onStep = function(_entry, _dt)
				local now = os.clock()
				local byCount = chainExplosionCount > 0 and emitted >= chainExplosionCount
				local byTime = now >= chainEndAt
				if byCount or byTime then
					AutonomousEntityService.stop(anchorModel, "chain_complete")
					if anchorModel.Parent then
						anchorModel:Destroy()
					end
					return
				end
				if now < nextExplosionAt then
					return
				end
				nextExplosionAt = now + chainInterval
				emitted += 1

				local chainCenter = centerPos + randomChainOffset(rng, chainAreaHalfSize)
				deps.applyExplosionAt(anchorModel, chainCenter, {
					damage = chainExplosionDamage,
					radius = chainExplosionRadius,
					knockback = chainExplosionKnockback,
					fxPath = chainExplosionFxName,
					soundPath = chainExplosionSoundName,
					canDamageAllies = canDamageAllies,
					canDamageOwner = canDamageOwner,
				}, {
					deployableId = deployableId,
					deployableDisplayName = displayName,
					killBellEnabled = killBellEnabled,
					killBellSoundName = killBellSoundName,
					context = "chain_explosion",
				})
			end,
			onCleanup = function(_entry, reason)
				log:trace(string.format("Chain runner cleanup -> id=%s reason=%s", deployableId, tostring(reason)))
			end,
		})
	end

	local function detonate(reason: string)
		if isDetonated then
			return
		end
		isDetonated = true
		isArming = false
		model:SetAttribute("Arming", false)
		setState("Detonated")
		if deps.stopLocomotion then
			deps.stopLocomotion(model, 0.08)
		end
		if deps.playAction then
			deps.playAction(model, AnimationKeys.Actions.Explode)
		end

		local centerPos = body.Position
		deps.applyExplosionAt(model, centerPos, {
			damage = mainExplosionDamage,
			radius = mainExplosionRadius,
			knockback = mainExplosionKnockback,
			fxPath = mainExplosionFxName,
			soundPath = mainExplosionSoundName,
			canDamageAllies = canDamageAllies,
			canDamageOwner = canDamageOwner,
		}, {
			deployableId = deployableId,
			deployableDisplayName = displayName,
			killBellEnabled = killBellEnabled,
			killBellSoundName = killBellSoundName,
			context = "main_explosion",
		})

		runChainExplosions(centerPos)

		AutonomousEntityService.stop(model, "detonate_" .. tostring(reason))
		if model.Parent then
			model:Destroy()
		end
	end

	local function startArming(triggerReason: string)
		if isDetonated then
			return
		end
		if isArming then
			log:trace("Arming ignored: already arming")
			return
		end
		isArming = true
		armingEndAt = os.clock() + armDelay
		model:SetAttribute("Arming", true)
		model:SetAttribute("ArmingReason", triggerReason)
		setState("Arming")

		log:info(string.format(
			"Arming started -> id=%s reason=%s delay=%.2f",
			deployableId,
			triggerReason,
			armDelay
		))

		if stopOnArm then
			if humanoid then
				humanoid:MoveTo(body.Position)
			end
			if deps.stopLocomotion then
				deps.stopLocomotion(model, 0.08)
			end
		end
		if deps.playAction then
			deps.playAction(model, AnimationKeys.Actions.Arm)
		end

		if type(armingFxName) == "string" and armingFxName ~= "" then
			deps.emitDeployableFx(body.Position, Vector3.new(0, 1, 0), armingFxName, nil)
		else
			log:warn("Arming FX missing in config")
		end

		if type(armingSoundName) == "string" and armingSoundName ~= "" then
			deps.playConfiguredSound(body, armingSoundName, "arming", armDelay + 0.2)
		else
			log:warn("Arming sound missing in config")
		end

		if armDelay <= 0 then
			detonate("armdelay_zero")
		end
	end

	local function updateTarget(now: number)
		if now < nextRetargetAt then
			return
		end
		nextRetargetAt = now + retargetInterval

		local targetHum, dist, targetRoot = deps.findClosestEnemyHumanoid(model, detectionRadius, canDamageAllies)
		if targetHum and dist and targetRoot and dist <= detectionRadius then
			currentTargetHumanoid = targetHum
			currentTargetRoot = targetRoot
			return
		end
		clearTarget()
	end

	local function isTargetValid(): boolean
		if not currentTargetHumanoid or not currentTargetRoot then
			return false
		end
		if currentTargetHumanoid.Health <= 0 then
			return false
		end
		if not currentTargetRoot.Parent then
			return false
		end
		if not DamageUtil.canTarget(model, currentTargetHumanoid, canDamageAllies) then
			return false
		end
		local dist = (currentTargetRoot.Position - body.Position).Magnitude
		if dist > loseTargetDistance then
			return false
		end
		return true
	end

	local function runPatrol(now: number, dt: number)
		if not patrolEnabled then
			if deps.setLocomotionState then
				deps.setLocomotionState(model, AnimationKeys.Locomotion.Idle, 1)
			end
			return
		end
		if now >= nextPatrolAt then
			nextPatrolAt = now + patrolStepInterval
			local offset = randomPatrolOffset(rng, patrolRadius)
			patrolPoint = spawnOrigin + offset
		end
		if patrolPoint then
			applyMovementToward(patrolPoint, dt)
			if deps.setLocomotionState then
				local speedScale = if moveSpeed > 0 then math.clamp(moveSpeed / 8, 0.6, 2.6) else 1
				deps.setLocomotionState(model, AnimationKeys.Locomotion.Walk, speedScale)
			end
		elseif deps.setLocomotionState then
			deps.setLocomotionState(model, AnimationKeys.Locomotion.Idle, 1)
		end
	end

	local runner = AutonomousEntityService.register(model, {
		kind = "LegendaryDeployableExploder",
		stepInterval = 0,
		state = {
			expiresAt = os.clock() + lifetime,
		},
		onCleanup = function(_entry, reason)
			setState("Finished")
			model:SetAttribute("Arming", false)
			if deps.stopLocomotion then
				deps.stopLocomotion(model, 0.08)
			end
			log:trace(string.format("Runtime cleanup -> id=%s reason=%s", deployableId, tostring(reason)))
		end,
		onStep = function(entry, dt)
			if isDetonated then
				return
			end

			local now = os.clock()
			if now >= entry.state.expiresAt then
				AutonomousEntityService.stop(model, "ttl_expired")
				if model.Parent then
					model:Destroy()
				end
				return
			end

			if isArming then
				if now >= armingEndAt then
					detonate("arming_complete")
				end
				return
			end

			updateTarget(now)
			if not isTargetValid() then
				clearTarget()
				setState("Patrol")
				runPatrol(now, dt)
				return
			end

			local targetHum = currentTargetHumanoid
			local targetRoot = currentTargetRoot
			if not targetHum or not targetRoot then
				return
			end

			if not canDamageOwner and isOwnerHumanoid(ownerUserId, targetHum) then
				clearTarget()
				setState("Patrol")
				runPatrol(now, dt)
				return
			end

			local targetModel = targetHum.Parent
			if not targetModel or not targetModel:IsA("Model") then
				clearTarget()
				setState("Patrol")
				runPatrol(now, dt)
				return
			end

			local resolvedTargetRoot = getTargetRoot(targetModel, targetRoot)
			local dist = (resolvedTargetRoot.Position - body.Position).Magnitude
			if dist <= triggerRadius then
				startArming("proximity")
				return
			end

			setState("Chase")
			applyMovementToward(resolvedTargetRoot.Position, dt)
			if deps.setLocomotionState then
				local speedScale = if moveSpeed > 0 then math.clamp(moveSpeed / 10, 0.6, 2.8) else 1
				deps.setLocomotionState(model, AnimationKeys.Locomotion.Chase, speedScale)
			end
		end,
	})

	if triggerOnTouch then
		local touchConn = body.Touched:Connect(function(otherPart: BasePart)
			if isDetonated or isArming then
				return
			end
			if not otherPart or not otherPart.Parent then
				return
			end
			if otherPart:IsDescendantOf(model) then
				return
			end

			local touchHumanoid = RaycastUtil.findHumanoidFromHit(otherPart)
			if not touchHumanoid or touchHumanoid.Health <= 0 then
				return
			end
			if not DamageUtil.canTarget(model, touchHumanoid, canDamageAllies) then
				return
			end
			if not canDamageOwner and isOwnerHumanoid(ownerUserId, touchHumanoid) then
				return
			end
			startArming("touch")
		end)
		AutonomousEntityService.bindConnection(model, touchConn)
	end

	return runner
end

return Runtime
