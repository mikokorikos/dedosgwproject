--!strict
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Net = require(RS.GW.Shared.Net)
local AssetResolver = require(RS.GW.Shared.AssetResolver)
local DamageUtil = require(RS.GW.Shared.DamageUtil)
local Deployables = require(RS.GW.Shared.DeployableRegistry)
local EntityRelations = require(RS.GW.Shared.EntityRelations)
local TargetingUtil = require(RS.GW.Shared.TargetingUtil)
local Logger = require(RS.GW.Shared.Logger)
local AnimationKeys = require(RS.GW.Shared.AnimationKeys)
local LegendaryExploderRuntime = require(script.Parent.DeployableRuntimes.LegendaryExploderRuntime)
local ServerAnimationService = require(script.Parent.ServerAnimationService)

local log = Logger.scoped("Deployable")

type SpawnResult = {
	model: Model,
	body: BasePart,
	config: any,
	behavior: any,
}

type ExplosionSummary = {
	targetsScanned: number,
	damagedTargets: number,
	killedTargets: number,
	blockedFriendly: number,
	blockedOwner: number,
}

local DeployableService = {}
local deathLock = setmetatable({}, { __mode = "k" }) :: { [Humanoid]: number }
local DEATH_LOCK_WINDOW = 0.25

local function getAssetsRoot(): Instance?
	return RS.GW:FindFirstChild("Assets")
end

local function getDeployablesRoot(): Instance?
	local assets = getAssetsRoot()
	if not assets then
		return nil
	end
	return assets:FindFirstChild("Deployables")
end

local function getFxRoot(): Instance?
	local assets = getAssetsRoot()
	if not assets then
		return nil
	end
	return assets:FindFirstChild("FX")
end

local function getSoundsRoot(): Instance?
	local assets = getAssetsRoot()
	if not assets then
		return nil
	end
	return assets:FindFirstChild("Sounds")
end

local function findDescendantByName(root: Instance, className: string, name: string): Instance?
	for _, desc in ipairs(root:GetDescendants()) do
		if desc.ClassName == className and desc.Name == name then
			return desc
		end
	end
	return nil
end

local function resolveFxFolder(pathOrName: any): Folder?
	if type(pathOrName) ~= "string" or pathOrName == "" then
		return nil
	end
	local fxRoot = getFxRoot()
	if not fxRoot then
		return nil
	end
	local resolved = AssetResolver.resolve(fxRoot, pathOrName)
	if resolved and resolved:IsA("Folder") then
		return resolved
	end
	local byName = findDescendantByName(fxRoot, "Folder", pathOrName)
	if byName and byName:IsA("Folder") then
		return byName
	end
	return nil
end

local function resolveSoundTemplate(pathOrName: any): Sound?
	if type(pathOrName) ~= "string" or pathOrName == "" then
		return nil
	end
	local soundsRoot = getSoundsRoot()
	if not soundsRoot then
		return nil
	end
	local resolved = AssetResolver.resolve(soundsRoot, pathOrName)
	if resolved and resolved:IsA("Sound") then
		return resolved
	end
	local byName = findDescendantByName(soundsRoot, "Sound", pathOrName)
	if byName and byName:IsA("Sound") then
		return byName
	end
	return nil
end

local function fireSoundCueToPlayer(player: Player, soundPath: string, mode: string, position: Vector3?, context: string)
	Net.FXEvent:FireClient(player, {
		type = "SoundCue",
		soundPath = soundPath,
		mode = mode,
		position = position,
		context = context,
	})
end

local function fireSoundCueToAll(soundPath: string, mode: string, position: Vector3?, context: string)
	Net.FXEvent:FireAllClients({
		type = "SoundCue",
		soundPath = soundPath,
		mode = mode,
		position = position,
		context = context,
	})
end

local function playConfiguredSound(parent: Instance, soundPath: any, context: string, minLifetime: number?): Sound?
	if type(soundPath) ~= "string" or soundPath == "" then
		log:trace("Deployable sound skipped (not configured) context=" .. tostring(context))
		return nil
	end
	local template = resolveSoundTemplate(soundPath)
	if not template then
		log:warn(string.format("Deployable sound missing -> context=%s path=%s", tostring(context), tostring(soundPath)))
		return nil
	end
	if template.SoundId == "" or template.SoundId == "rbxassetid://0" then
		log:warn(string.format("Deployable sound invalid SoundId -> context=%s path=%s", tostring(context), tostring(soundPath)))
		return nil
	end

	local sound = template:Clone()
	sound.Parent = parent
	sound.Looped = false
	sound:Play()

	local ttl = 4.0
	if sound.TimeLength > 0 then
		ttl = (sound.TimeLength / math.max(sound.PlaybackSpeed, 0.01)) + 0.3
	end
	if type(minLifetime) == "number" and minLifetime > 0 then
		ttl = math.max(ttl, minLifetime)
	end
	Debris:AddItem(sound, ttl)
	return sound
end

local function emitDeployableFx(pos: Vector3, normal: Vector3, fxPath: any, soundPath: any?)
	local hasFx = type(fxPath) == "string" and fxPath ~= ""
	local hasSound = type(soundPath) == "string" and soundPath ~= ""

	if not hasFx then
		log:warn("Deployable FX missing for event")
		if hasSound then
			fireSoundCueToAll(soundPath, "3D", pos, "DeployableFxNoFolder")
		end
		return
	end

	if not resolveFxFolder(fxPath) then
		log:warn("Deployable FX folder missing -> expected path=" .. tostring(fxPath))
		if hasSound then
			fireSoundCueToAll(soundPath, "3D", pos, "DeployableFxMissingFolder")
		end
	end

	Net.FXEvent:FireAllClients({
		type = "DeployableFX",
		fxPath = fxPath,
		soundPath = soundPath,
		pos = pos,
		normal = normal,
	})
end

local function readPath(tbl: any, path: string): any
	local cur = tbl
	for segment in string.gmatch(path, "[^%.]+") do
		if type(cur) ~= "table" then
			return nil
		end
		cur = cur[segment]
	end
	return cur
end

local function pickValue(cfg: any, paths: {string}): any
	for _, path in ipairs(paths) do
		local value = readPath(cfg, path)
		if value ~= nil then
			return value
		end
	end
	return nil
end

local function pickString(cfg: any, defaultValue: string, paths: {string}): string
	local value = pickValue(cfg, paths)
	if type(value) == "string" and value ~= "" then
		return value
	end
	return defaultValue
end

local function pickOptionalString(cfg: any, paths: {string}): string?
	local value = pickValue(cfg, paths)
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function pickNumber(cfg: any, defaultValue: number, paths: {string}): number
	local value = pickValue(cfg, paths)
	local asNum = tonumber(value)
	if asNum ~= nil then
		return asNum
	end
	return defaultValue
end

local function pickOptionalNumber(cfg: any, paths: {string}): number?
	local value = pickValue(cfg, paths)
	local asNum = tonumber(value)
	if asNum ~= nil then
		return asNum
	end
	return nil
end

local function pickBoolean(cfg: any, defaultValue: boolean, paths: {string}): boolean
	local value = pickValue(cfg, paths)
	if type(value) == "boolean" then
		return value
	end
	return defaultValue
end

local function normalizeBehaviorConfig(cfg: any): any
	local explosionDamage = pickNumber(cfg, 40, { "ExplosionDamage", "explosionMaxDamage" })
	local mainMinDamage = pickOptionalNumber(cfg, { "ExplosionMinDamage", "explosionMinDamage" }) or explosionDamage
	local chainDamage = pickNumber(cfg, math.max(8, math.floor(explosionDamage * 0.45)), { "ChainExplosionDamage", "chainExplosionDamage" })

	local behavior = {
		id = tostring(cfg.id or "Deployable"),
		displayName = pickString(cfg, tostring(cfg.id or "Deployable"), { "displayName", "DisplayName" }),
		kind = string.lower(pickString(cfg, "exploder", { "kind", "Kind" })),
		AnimationProfileId = pickString(cfg, "", { "animationProfileId", "AnimationProfileId" }),

		ModelAssetName = pickString(cfg, "", { "ModelAssetName", "templateName" }),
		BodyPartName = pickString(cfg, "HumanoidRootPart", { "bodyPartName", "BodyPartName" }),
		MaxHealth = pickOptionalNumber(cfg, { "MaxHealth", "maxHealth" }),

		Lifetime = math.max(0.1, pickNumber(cfg, 12, { "Lifetime", "lifetime" })),
		KillBellEnabled = pickBoolean(cfg, true, { "KillBellEnabled" }),
		KillBellSoundName = pickString(cfg, "Combat/KillBell", { "KillBellSoundName", "sfx.killBellSoundPath" }),
		CanDamageAllies = pickBoolean(cfg, false, { "CanDamageAllies", "allowFriendlyFire" }),
		CanDamageOwner = pickBoolean(cfg, false, { "CanDamageOwner" }),

		DeploySoundName = pickOptionalString(cfg, {
			"DeploySoundName",
			"sfx.deploySoundName",
			"sfx.deploySoundPath",
			"sfx.spawnSoundPath",
		}),
		MoveSpeed = math.max(0, pickNumber(cfg, 10, { "MoveSpeed", "moveSpeed" })),
		DetectionRadius = math.max(0.1, pickNumber(cfg, 28, { "DetectionRadius", "detectionRadius" })),
		RetargetInterval = math.max(0.05, pickNumber(cfg, 0.25, { "RetargetInterval" })),
		PatrolEnabled = pickBoolean(cfg, true, { "PatrolEnabled" }),
		PatrolRadius = math.max(0, pickNumber(cfg, 16, { "PatrolRadius" })),
		PatrolStepInterval = math.max(0.1, pickNumber(cfg, 0.8, { "PatrolStepInterval" })),
		LoseTargetDistance = math.max(0.1, pickNumber(cfg, pickNumber(cfg, 28, { "DetectionRadius", "detectionRadius" }) * 1.5, { "LoseTargetDistance" })),
		TriggerRadius = math.max(0.1, pickNumber(cfg, 4.5, { "TriggerRadius", "triggerRadius" })),
		TriggerOnTouch = pickBoolean(cfg, true, { "triggerOnTouch", "TriggerOnTouch" }),

		ArmDelay = math.max(0, pickNumber(cfg, 2.0, { "ArmDelay", "armDelay" })),
		StopOnArm = pickBoolean(cfg, true, { "StopOnArm" }),
		ArmingSoundName = pickOptionalString(cfg, {
			"ArmingSoundName",
			"sfx.armingSoundName",
			"sfx.explodeSequenceSoundPath",
		}),
		ArmingFxName = pickOptionalString(cfg, {
			"ArmingFxName",
			"fx.armingFxName",
			"fx.armingEmittersPath",
			"fx.spawnEmittersPath",
		}),

		ExplosionDamage = math.max(0, explosionDamage),
		ExplosionMinDamage = math.max(0, mainMinDamage),
		ExplosionRadius = math.max(0.1, pickNumber(cfg, 11, { "ExplosionRadius", "explosionRadius" })),
		ExplosionFalloffExponent = math.max(0.1, pickNumber(cfg, 1.0, { "ExplosionFalloffExponent", "explosionFalloffExponent" })),
		ExplosionSoundName = pickOptionalString(cfg, {
			"ExplosionSoundName",
			"sfx.explosionSoundName",
			"sfx.explosionSoundPath",
		}),
		ExplosionFxName = pickOptionalString(cfg, {
			"ExplosionFxName",
			"fx.explosionFxName",
			"fx.explosionEmittersPath",
		}),
		ExplosionKnockback = math.max(0, pickNumber(cfg, 0, { "ExplosionKnockback", "explosionKnockback" })),

		ChainEnabled = pickBoolean(cfg, false, { "ChainEnabled" }),
		ChainDuration = math.max(0, pickNumber(cfg, 0, { "ChainDuration" })),
		ChainInterval = math.max(0.05, pickNumber(cfg, 0.35, { "ChainInterval" })),
		ChainAreaHalfSize = math.max(0, pickNumber(cfg, 14, { "ChainAreaHalfSize" })),
		ChainExplosionDamage = math.max(0, chainDamage),
		ChainExplosionRadius = math.max(0.1, pickNumber(cfg, 8, { "ChainExplosionRadius" })),
		ChainExplosionSoundName = pickOptionalString(cfg, {
			"ChainExplosionSoundName",
			"sfx.chainExplosionSoundName",
			"sfx.chainExplosionSoundPath",
			"ExplosionSoundName",
			"sfx.explosionSoundName",
		}),
		ChainExplosionFxName = pickOptionalString(cfg, {
			"ChainExplosionFxName",
			"fx.chainExplosionFxName",
			"fx.chainExplosionEmittersPath",
			"ExplosionFxName",
			"fx.explosionFxName",
			"fx.explosionEmittersPath",
		}),
		ChainExplosionKnockback = math.max(0, pickNumber(cfg, 0, { "ChainExplosionKnockback" })),
		ChainExplosionCount = math.max(0, math.floor(pickNumber(cfg, 0, { "ChainExplosionCount" }))),
	}

	return behavior
end

local function getModelAndBody(template: Instance, bodyPartName: string?): (Model?, BasePart?)
	local model: Model? = nil
	if template:IsA("Model") then
		model = template:Clone()
	elseif template:IsA("BasePart") then
		model = Instance.new("Model")
		local partClone = template:Clone()
		partClone.Parent = model
		model.PrimaryPart = partClone
	else
		return nil, nil
	end

	if not model then
		return nil, nil
	end

	local body: BasePart? = nil
	if type(bodyPartName) == "string" and bodyPartName ~= "" then
		body = model:FindFirstChild(bodyPartName, true) :: BasePart?
	end
	if not (body and body:IsA("BasePart")) then
		body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	if not body then
		model:Destroy()
		return nil, nil
	end
	model.PrimaryPart = body

	return model, body
end

local function isFiniteVector(v: Vector3): boolean
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
		return false
	end
	local maxAbs = 100000
	return math.abs(v.X) < maxAbs and math.abs(v.Y) < maxAbs and math.abs(v.Z) < maxAbs
end

local function resolveSpawnCFrame(ownerPlayer: Player, requestedCFrame: CFrame, body: BasePart): CFrame
	local pos = requestedCFrame.Position
	local look = requestedCFrame.LookVector
	if look.Magnitude < 0.001 then
		look = Vector3.zAxis
	else
		look = look.Unit
	end

	if not isFiniteVector(pos) then
		local fallback = ownerPlayer.Character and ownerPlayer.Character:FindFirstChild("HumanoidRootPart")
		if fallback and fallback:IsA("BasePart") then
			pos = fallback.Position + fallback.CFrame.LookVector * 4
		else
			pos = Vector3.zero
		end
		log:warn("Deployable spawn cframe invalid; fallback position used")
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = ownerPlayer.Character and { ownerPlayer.Character } or {}

	local castOrigin = pos + Vector3.new(0, 8, 0)
	local castDir = Vector3.new(0, -24, 0)
	local hit = workspace:Raycast(castOrigin, castDir, params)
	if hit then
		local bodyHalf = math.max(body.Size.Y * 0.5, 0.5)
		pos = Vector3.new(pos.X, hit.Position.Y + bodyHalf + 0.05, pos.Z)
	end

	return CFrame.lookAt(pos, pos + look)
end

local function getPlayerByUserId(userId: number?): Player?
	if type(userId) ~= "number" then
		return nil
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

local function applyKnockback(targetHumanoid: Humanoid, centerPos: Vector3, knockback: number)
	if knockback <= 0 then
		return
	end
	local targetModel = targetHumanoid.Parent
	if not targetModel or not targetModel:IsA("Model") then
		return
	end
	local root = targetModel:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if root.Anchored then
		return
	end

	local away = root.Position - centerPos
	if away.Magnitude < 0.001 then
		away = Vector3.new(0, 1, 0)
	else
		away = away.Unit
	end
	local velocity = away * knockback + Vector3.new(0, knockback * 0.28, 0)
	root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + velocity
end

local function emitKillEvents(sourceEntity: Instance, killedHumanoids: {Humanoid}, meta: any)
	if #killedHumanoids == 0 then
		return
	end
	local ownerUserId = DamageUtil.resolveOwnerUserId(sourceEntity) or DamageUtil.resolveSummonerUserId(sourceEntity)
	local ownerPlayer = getPlayerByUserId(ownerUserId)
	if not ownerPlayer then
		log:warn("Kill credit skipped: owner player not found for deployable")
		return
	end

	local deployableId = tostring(meta and meta.deployableId or sourceEntity:GetAttribute("DeployableId") or "Deployable")
	local deployableDisplayName = tostring(meta and meta.deployableDisplayName or sourceEntity:GetAttribute("DeployableDisplayName") or deployableId)
	local killBellEnabled = not (meta and meta.killBellEnabled == false)
	local killBellSoundName = tostring((meta and meta.killBellSoundName) or "Combat/KillBell")

	for _, killedHumanoid in ipairs(killedHumanoids) do
		local victimName = if killedHumanoid.Parent then killedHumanoid.Parent.Name else "Victim"
		Net.FXEvent:FireAllClients({
			type = "KillFeed",
			killerUserId = ownerPlayer.UserId,
			killerName = ownerPlayer.DisplayName ~= "" and ownerPlayer.DisplayName or ownerPlayer.Name,
			victimName = victimName,
			weaponId = deployableId,
			weaponDisplayName = deployableDisplayName,
			timestamp = os.time(),
		})

		if killBellEnabled then
			fireSoundCueToPlayer(ownerPlayer, killBellSoundName, "2D", nil, "DeployableKillBell")
		end
	end
end

function DeployableService.findClosestEnemyHumanoid(sourceModel: Model, radius: number, allowFriendlyFire: boolean): (Humanoid?, number?, BasePart?)
	local body = sourceModel.PrimaryPart or sourceModel:FindFirstChildWhichIsA("BasePart", true)
	if not body then
		return nil, nil, nil
	end
	return TargetingUtil.findClosestEnemyHumanoid(sourceModel, body.Position, radius, allowFriendlyFire, { sourceModel })
end

function DeployableService.createDetachedChainRuntimeAnchor(sourceEntity: Instance, position: Vector3): (Model, BasePart)
	local chainModel = Instance.new("Model")
	chainModel.Name = tostring(sourceEntity:GetAttribute("DeployableId") or "Deployable") .. "_ChainRuntime"

	local chainBody = Instance.new("Part")
	chainBody.Name = "ChainRuntimeRoot"
	chainBody.Size = Vector3.new(0.2, 0.2, 0.2)
	chainBody.Anchored = true
	chainBody.CanCollide = false
	chainBody.CanTouch = false
	chainBody.CanQuery = false
	chainBody.Transparency = 1
	chainBody.CastShadow = false
	chainBody.CFrame = CFrame.new(position)
	chainBody.Parent = chainModel
	chainModel.PrimaryPart = chainBody

	EntityRelations.tagEntity(chainModel, {
		factionId = DamageUtil.getFactionId(sourceEntity),
		teamId = DamageUtil.getTeamId(sourceEntity),
		ownerUserId = DamageUtil.resolveOwnerUserId(sourceEntity),
		summonerUserId = DamageUtil.resolveSummonerUserId(sourceEntity),
		isSummonedEntity = true,
		entityKind = "DeployableChainRuntime",
	})
	chainModel:SetAttribute("DeployableId", sourceEntity:GetAttribute("DeployableId"))
	chainModel:SetAttribute("DeployableDisplayName", sourceEntity:GetAttribute("DeployableDisplayName"))
	chainModel.Parent = workspace
	return chainModel, chainBody
end

function DeployableService.applyExplosionAt(sourceEntity: Instance, centerPos: Vector3, spec: any, meta: any?): ExplosionSummary
	local radius = math.max(0.1, tonumber(spec and spec.radius) or 10)
	local maxDamage = math.max(0, tonumber(spec and spec.damage) or 35)
	local minDamage = math.max(0, tonumber(spec and spec.minDamage) or maxDamage)
	local falloffExponent = math.max(0.1, tonumber(spec and spec.falloffExponent) or 1.0)
	local knockback = math.max(0, tonumber(spec and spec.knockback) or 0)
	local allowFriendlyFire = spec and spec.canDamageAllies == true
	local canDamageOwner = spec and spec.canDamageOwner == true
	local fxPath = if spec then spec.fxPath else nil
	local soundPath = if spec then spec.soundPath else nil

	local ownerUserId = DamageUtil.resolveOwnerUserId(sourceEntity) or DamageUtil.resolveSummonerUserId(sourceEntity)
	local targets = TargetingUtil.collectHumanoidsInRadius(sourceEntity, centerPos, radius, {
		allowFriendlyFire = true,
		excludeInstances = { sourceEntity },
	})

	local summary: ExplosionSummary = {
		targetsScanned = #targets,
		damagedTargets = 0,
		killedTargets = 0,
		blockedFriendly = 0,
		blockedOwner = 0,
	}
	local killedHumanoids: {Humanoid} = {}

	for _, target in ipairs(targets) do
		local hum = target.humanoid
		if hum.Health <= 0 then
			continue
		end

		local targetPlayer = Players:GetPlayerFromCharacter(target.model)
		if not canDamageOwner and targetPlayer and type(ownerUserId) == "number" and targetPlayer.UserId == ownerUserId then
			summary.blockedOwner += 1
			continue
		end

		if not DamageUtil.canDamage(sourceEntity, hum, allowFriendlyFire) then
			summary.blockedFriendly += 1
			continue
		end

		local dist = target.distance
		local t = math.clamp(dist / math.max(radius, 0.001), 0, 1)
		local dmg = maxDamage + (minDamage - maxDamage) * (t ^ falloffExponent)
		dmg = math.max(0, math.floor(dmg + 0.5))
		if dmg <= 0 then
			continue
		end

		local pre = hum.Health
		hum:TakeDamage(dmg)
		local post = hum.Health
		if pre ~= post then
			summary.damagedTargets += 1
		end

		applyKnockback(hum, centerPos, knockback)

		if pre > 0 and post <= 0 then
			local now = os.clock()
			local last = deathLock[hum] or 0
			if now - last > DEATH_LOCK_WINDOW then
				deathLock[hum] = now
				summary.killedTargets += 1
				table.insert(killedHumanoids, hum)
			end
		end
	end

	emitDeployableFx(centerPos, Vector3.new(0, 1, 0), fxPath, soundPath)
	emitKillEvents(sourceEntity, killedHumanoids, meta)

	log:info(string.format(
		"Explosion applied -> context=%s scanned=%d damaged=%d killed=%d blockedFriendly=%d blockedOwner=%d",
		tostring(meta and meta.context or "explosion"),
		summary.targetsScanned,
		summary.damagedTargets,
		summary.killedTargets,
		summary.blockedFriendly,
		summary.blockedOwner
	))

	return summary
end

function DeployableService.explode(sourceModel: Model, cfg: any, reason: string?): boolean
	if sourceModel:GetAttribute("Exploded") == true then
		log:trace("Explode ignored: already exploded")
		return false
	end
	sourceModel:SetAttribute("Exploded", true)

	local body = sourceModel.PrimaryPart or sourceModel:FindFirstChildWhichIsA("BasePart", true)
	if not body then
		log:warn("Explode aborted: missing body")
		sourceModel:Destroy()
		return false
	end

	local behavior = normalizeBehaviorConfig(cfg)
	DeployableService.applyExplosionAt(sourceModel, body.Position, {
		damage = behavior.ExplosionDamage,
		minDamage = behavior.ExplosionMinDamage,
		falloffExponent = behavior.ExplosionFalloffExponent,
		radius = behavior.ExplosionRadius,
		knockback = behavior.ExplosionKnockback,
		fxPath = behavior.ExplosionFxName,
		soundPath = behavior.ExplosionSoundName,
		canDamageAllies = behavior.CanDamageAllies,
		canDamageOwner = behavior.CanDamageOwner,
	}, {
		deployableId = behavior.id,
		deployableDisplayName = behavior.displayName,
		killBellEnabled = behavior.KillBellEnabled,
		killBellSoundName = behavior.KillBellSoundName,
		context = reason or "explode_compat",
	})

	sourceModel:Destroy()
	return true
end

function DeployableService.spawn(ownerPlayer: Player, deployableId: string, requestedSpawnCFrame: any): (SpawnResult?, string?)
	if not ownerPlayer or ownerPlayer.Parent == nil then
		log:warn("Deployable spawn blocked: invalid owner player")
		return nil, "invalid_owner"
	end

	local cfg = Deployables.Get(deployableId)
	local behavior = normalizeBehaviorConfig(cfg)
	if type(behavior.AnimationProfileId) ~= "string" or behavior.AnimationProfileId == "" then
		log:warn("Deployable spawn blocked: animationProfileId missing")
		return nil, "animation_profile_missing"
	end
	local modelAssetName = behavior.ModelAssetName
	if type(modelAssetName) ~= "string" or modelAssetName == "" then
		log:warn("Deployable spawn blocked: ModelAssetName/templateName missing")
		return nil, "model_asset_missing"
	end

	log:info(string.format("Deployable spawn request -> id=%s owner=%s(%d)", tostring(cfg.id), ownerPlayer.Name, ownerPlayer.UserId))
	log:trace(string.format(
		"Deployable assets expected -> model=Deployables/%s fxArming=%s fxExplosion=%s fxChain=%s sfxDeploy=%s sfxArming=%s sfxExplosion=%s sfxChain=%s killBell=%s",
		tostring(modelAssetName),
		tostring(behavior.ArmingFxName),
		tostring(behavior.ExplosionFxName),
		tostring(behavior.ChainExplosionFxName),
		tostring(behavior.DeploySoundName),
		tostring(behavior.ArmingSoundName),
		tostring(behavior.ExplosionSoundName),
		tostring(behavior.ChainExplosionSoundName),
		tostring(behavior.KillBellSoundName)
	))

	local deployablesRoot = getDeployablesRoot()
	local template: Instance? = nil
	if deployablesRoot then
		template = deployablesRoot:FindFirstChild(modelAssetName, true)
		if template then
			log:trace("Deployable template found: " .. template:GetFullName())
		else
			log:warn("Deployable template missing templateName=" .. tostring(modelAssetName))
			return nil, "template_missing"
		end
	else
		log:warn("Assets.Deployables folder missing")
		return nil, "deployables_folder_missing"
	end

	local model: Model?
	local body: BasePart?
	if template then
		model, body = getModelAndBody(template, behavior.BodyPartName)
	end
	if not model or not body then
		log:warn("Deployable model/body invalid from template")
		return nil, "deployable_body_missing"
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		model:Destroy()
		log:warn("Deployable spawn blocked: template model has no Humanoid")
		return nil, "humanoid_missing"
	end
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not (rootPart and rootPart:IsA("BasePart")) then
		model:Destroy()
		log:warn("Deployable spawn blocked: template model has no HumanoidRootPart")
		return nil, "humanoid_root_missing"
	end
	body = rootPart
	model.PrimaryPart = rootPart

	local spawnCFrame: CFrame
	if typeof(requestedSpawnCFrame) == "CFrame" then
		spawnCFrame = requestedSpawnCFrame
	else
		log:warn("Deployable spawn received invalid cframe payload; using owner fallback")
		local hrp = ownerPlayer.Character and ownerPlayer.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			local basePos = hrp.Position + hrp.CFrame.LookVector * 4
			spawnCFrame = CFrame.lookAt(basePos, basePos + hrp.CFrame.LookVector)
		else
			spawnCFrame = CFrame.new()
		end
	end

	local finalCFrame = resolveSpawnCFrame(ownerPlayer, spawnCFrame, body)
	model.Parent = workspace
	model:PivotTo(finalCFrame)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = false
		end
	end

	EntityRelations.tagSummonModel(model, ownerPlayer, nil)
	model:SetAttribute("DeployableId", behavior.id)
	model:SetAttribute("DeployableDisplayName", behavior.displayName)
	model:SetAttribute("DeployableKind", behavior.kind)
	model:SetAttribute("AnimationProfileId", behavior.AnimationProfileId)
	model:SetAttribute("SpawnedAt", os.clock())
	model:SetAttribute("Exploded", false)
	model:SetAttribute("SpawnFallbackModel", false)

	local factionId = model:GetAttribute("FactionId")
	local teamId = model:GetAttribute("TeamId")
	log:info(string.format(
		"Deployable spawned -> id=%s owner=%d faction=%s team=%s profile=%s",
		tostring(behavior.id),
		ownerPlayer.UserId,
		tostring(factionId),
		tostring(teamId),
		tostring(behavior.AnimationProfileId)
	))

	if humanoid and type(behavior.MaxHealth) == "number" and behavior.MaxHealth > 0 then
		humanoid.MaxHealth = behavior.MaxHealth
		humanoid.Health = behavior.MaxHealth
	end
	ServerAnimationService.ensureRuntime(model, behavior.AnimationProfileId)
	ServerAnimationService.playAction(model, AnimationKeys.Actions.Deploy)

	if type(behavior.DeploySoundName) == "string" and behavior.DeploySoundName ~= "" then
		playConfiguredSound(body, behavior.DeploySoundName, "deploy", nil)
	else
		log:warn("Deployable deploy sound not configured (DeploySoundName)")
	end

	local ttl = math.max(0.5, tonumber(behavior.Lifetime) or 10)
	Debris:AddItem(model, ttl + 0.5)

	return {
		model = model,
		body = body,
		config = cfg,
		behavior = behavior,
	}, nil
end

function DeployableService.runExploderPrototype(spawnResult: SpawnResult)
	return LegendaryExploderRuntime.run(spawnResult, {
		findClosestEnemyHumanoid = DeployableService.findClosestEnemyHumanoid,
		emitDeployableFx = emitDeployableFx,
		playConfiguredSound = playConfiguredSound,
		applyExplosionAt = DeployableService.applyExplosionAt,
		createDetachedChainRuntimeAnchor = DeployableService.createDetachedChainRuntimeAnchor,
		playAction = function(model: Model, actionKey: string)
			return ServerAnimationService.playAction(model, actionKey)
		end,
		setLocomotionState = function(model: Model, locomotionKey: string, speedScale: number?)
			return ServerAnimationService.setLocomotionState(model, locomotionKey, speedScale)
		end,
		stopLocomotion = function(model: Model, fadeTime: number?)
			ServerAnimationService.stopLocomotion(model, fadeTime)
		end,
	})
end

function DeployableService.runPrototype(spawnResult: SpawnResult)
	local behavior = spawnResult.behavior or normalizeBehaviorConfig(spawnResult.config)
	spawnResult.behavior = behavior
	local kind = string.lower(tostring(behavior.kind or ""))
	if kind == "" or kind == "exploder" or kind == "exploderlegendary" or kind == "legendaryexploder" then
		return DeployableService.runExploderPrototype(spawnResult)
	end

	log:warn(string.format(
		"No prototype runner for deployable kind='%s' (deployableId=%s)",
		kind,
		tostring(behavior.id or spawnResult.config and spawnResult.config.id)
	))
	return nil
end

return DeployableService
