--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Net = require(RS.GW.Shared.Net)
local Abilities = require(RS.GW.Shared.AbilityRegistry)
local DamageUtil = require(RS.GW.Shared.DamageUtil)
local Logger = require(RS.GW.Shared.Logger)

local log = Logger.scoped("Ability")

local GW = RS:WaitForChild("GW")
local Assets = GW:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")
local Projectiles = Assets:WaitForChild("Projectiles")

local cooldowns: {[Player]: {[string]: number}} = {}
local rocketOriginal = setmetatable({}, {__mode = "k"}) :: {[BasePart]: {Size: Vector3, Transparency: number}}

local function playerLabel(player: Player): string
	return string.format("%s(%d)", player.Name, player.UserId)
end

local function getAlive(player: Player): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp or hum.Health <= 0 then
		return nil, nil, nil
	end
	return char, hum, hrp
end

local function cdOK(player: Player, id: string, cooldownSeconds: number): boolean
	cooldowns[player] = cooldowns[player] or {}
	local now = os.clock()
	if now < (cooldowns[player][id] or 0) then
		return false
	end
	cooldowns[player][id] = now + cooldownSeconds
	return true
end

local function storeRocket(rocket: BasePart)
	if not rocketOriginal[rocket] then
		rocketOriginal[rocket] = {Size = rocket.Size, Transparency = rocket.Transparency}
	end
	return rocketOriginal[rocket]
end

local function hideAndRegrow(rocket: BasePart, cfg: any)
	local st = storeRocket(rocket)
	local scale = math.max(tonumber(cfg.regrowStartScale) or 0.06, 0.01)
	rocket.Size = st.Size * scale
	rocket.Transparency = 1

	task.delay(tonumber(cfg.regrowDelay) or 0, function()
		if not rocket.Parent then
			return
		end
		TweenService:Create(
			rocket,
			TweenInfo.new(tonumber(cfg.regrowTime) or 3.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = st.Size, Transparency = st.Transparency}
		):Play()
	end)
end

local function playSound(name: any, parent: Instance, loop: boolean): Sound?
	if type(name) ~= "string" or name == "" then
		log:warn("sound name missing/invalid")
		return nil
	end

	local template = Sounds:FindFirstChild(name, true)
	if not (template and template:IsA("Sound")) then
		log:warn("missing sound template: " .. tostring(name))
		return nil
	end
	if template.SoundId == "" or template.SoundId == "rbxassetid://0" then
		log:warn("sound template has invalid SoundId: " .. tostring(name))
		return nil
	end

	local sound = template:Clone()
	sound.Parent = parent
	sound.Looped = loop
	sound:Play()
	if not loop then
		Debris:AddItem(sound, 4)
	end
	return sound
end

local function instantiateProjectile(cfg: any)
	if type(cfg.projectileTemplateName) ~= "string" or cfg.projectileTemplateName == "" then
		log:warn("projectileTemplateName missing in ability config")
		return nil
	end

	local template = Projectiles:FindFirstChild(cfg.projectileTemplateName, true)
	if not template then
		log:warn("missing projectile template: " .. tostring(cfg.projectileTemplateName))
		return nil
	end

	local clone = template:Clone()
	local body: BasePart? = nil
	if type(cfg.projectileBodyName) == "string" and cfg.projectileBodyName ~= "" then
		body = clone:FindFirstChild(cfg.projectileBodyName, true) :: BasePart?
	end
	if not (body and body:IsA("BasePart")) then
		body = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	end
	if not body then
		clone:Destroy()
		log:warn("projectile has no BasePart body")
		return nil
	end
	clone.PrimaryPart = body

	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Massless = true

	local flightAtt: Attachment? = nil
	if type(cfg.projectileFlightAttachmentName) == "string" and cfg.projectileFlightAttachmentName ~= "" then
		flightAtt = body:FindFirstChild(cfg.projectileFlightAttachmentName, true) :: Attachment?
	end
	if not (flightAtt and flightAtt:IsA("Attachment")) then
		flightAtt = body:FindFirstChildWhichIsA("Attachment")
	end

	return clone, body, flightAtt
end

local function explode(player: Player, cfg: any, pos: Vector3, normal: Vector3)
	Net.FXEvent:FireAllClients({
		type = "Explosion",
		fxPath = cfg.fx and cfg.fx.explosionEmittersFolderName,
		soundPath = cfg.sfx and cfg.sfx.explosionSoundName,
		pos = pos,
		normal = normal,
	})

	local radius = tonumber(cfg.explosionRadius) or 12
	local maxD = tonumber(cfg.explosionMaxDamage) or 45
	local minD = tonumber(cfg.explosionMinDamage) or 10
	local exp = math.max(0.1, tonumber(cfg.explosionFalloffExponent) or 1.0)

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	if player.Character then
		overlap.FilterDescendantsInstances = {player.Character}
	end

	local parts = workspace:GetPartBoundsInRadius(pos, radius, overlap)
	local seen: {[Humanoid]: boolean} = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not seen[hum] then
				seen[hum] = true
				local targetPlayer = Players:GetPlayerFromCharacter(model)
				if targetPlayer == player and (cfg.selfDamage ~= true) then
				elseif DamageUtil.isFriendly(player, hum, (cfg.friendlyFire == true)) then
				else
					local ref = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or part
					local dist = (ref.Position - pos).Magnitude
					local t = math.clamp(dist / math.max(radius, 0.001), 0, 1)
					local dmg = maxD + (minD - maxD) * (t ^ exp)
					dmg = math.max(0, math.floor(dmg + 0.5))
					if dmg > 0 then
						hum:TakeDamage(dmg)
					end
				end
			end
		end
	end
end

Net.AbilityRequest.OnServerEvent:Connect(function(player: Player, payload: any)
	log:info("activate request received from " .. playerLabel(player))

	if type(payload) ~= "table" then
		log:warn("payload is not a table")
		return
	end

	local abilityId = payload.abilityId
	log:info("abilityId = " .. tostring(abilityId))
	if type(abilityId) ~= "string" or abilityId == "" then
		log:warn("invalid abilityId in payload")
		return
	end

	local cfg = Abilities.Get(abilityId)
	if not cfg then
		log:warn("unknown abilityId: " .. abilityId)
		return
	end
	log:trace("ability config resolved for id = " .. tostring(cfg.id))

	if type(cfg.clientAnimId) ~= "string" or cfg.clientAnimId == "" then
		log:warn("clientAnimId missing in ability config: " .. tostring(cfg.id))
	else
		log:trace("clientAnimId configured = " .. tostring(cfg.clientAnimId))
	end
	log:trace("server-side animation playback skipped by design (client handles immediate ability animation)")

	local char, hum, hrp = getAlive(player)
	if not char or not hum or not hrp then
		log:warn("player is not in a valid alive state")
		return
	end
	log:trace("alive validation passed")

	local cooldownSeconds = tonumber(cfg.cooldown) or 0
	if not cdOK(player, cfg.id, cooldownSeconds) then
		log:trace("cooldown blocked on server")
		return
	end

	if cfg.id ~= "BackRocket" then
		log:trace("ability is valid but not handled by AbilityService: " .. tostring(cfg.id))
		return
	end
	log:info("validation passed")

	if type(cfg.characterRocketName) ~= "string" or cfg.characterRocketName == "" then
		log:warn("characterRocketName missing in config")
		return
	end

	local rocket = char:FindFirstChild(cfg.characterRocketName, true)
	if not (rocket and rocket:IsA("BasePart")) then
		log:warn("missing rocket visual: " .. tostring(cfg.characterRocketName))
		return
	end

	local dir = payload.direction
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.01 then
		dir = hrp.CFrame.LookVector
	end
	dir = dir.Unit

	log:info("executing BackRocket for " .. playerLabel(player))
	hideAndRegrow(rocket, cfg)

	local spawnPos = rocket.Position
		+ dir * (tonumber(cfg.spawnForwardOffset) or 2.2)
		+ Vector3.new(0, tonumber(cfg.spawnUpOffset) or 0.35, 0)

	local model, body, _flightAtt = instantiateProjectile(cfg)
	if not model or not body then
		log:warn("projectile instantiation failed")
		return
	end
	model.Parent = workspace
	model:PivotTo(CFrame.lookAt(spawnPos, spawnPos + dir))

	playSound(cfg.launchSoundName, body, false)
	local loop = playSound(cfg.flightLoopSoundName, body, true)

	local speed = tonumber(cfg.projectileSpeed) or 80
	local maxDist = tonumber(cfg.maxDistance) or 220
	local life = tonumber(cfg.lifetime) or 2.8

	local traveled = 0
	local pos = spawnPos
	local startT = os.clock()

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = {char, model}

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
			conn:Disconnect()
			return
		end

		if os.clock() - startT >= life then
			conn:Disconnect()
			if loop then
				loop:Stop()
			end
			model:Destroy()
			explode(player, cfg, pos, Vector3.new(0, 1, 0))
			return
		end

		dt = math.clamp(dt, 1 / 240, 1 / 30)
		local step = speed * dt
		local nextPos = pos + dir * step

		local hit = workspace:Raycast(pos, nextPos - pos, params)
		if hit then
			conn:Disconnect()
			if loop then
				loop:Stop()
			end
			model:Destroy()
			explode(player, cfg, hit.Position, hit.Normal)
			return
		end

		traveled += step
		if traveled >= maxDist then
			conn:Disconnect()
			if loop then
				loop:Stop()
			end
			model:Destroy()
			explode(player, cfg, nextPos, Vector3.new(0, 1, 0))
			return
		end

		pos = nextPos
		model:PivotTo(CFrame.lookAt(pos, pos + dir))
	end)
end)

log:info("AbilityService active (server tracing enabled)")

