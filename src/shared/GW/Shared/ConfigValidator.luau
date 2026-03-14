--!strict

local function pushError(errors: {string}, path: string, message: string)
	table.insert(errors, string.format("%s %s", path, message))
end

local function validateString(errors: {string}, path: string, value: any, required: boolean)
	if value == nil then
		if required then
			pushError(errors, path, "is required")
		end
		return
	end
	if type(value) ~= "string" then
		pushError(errors, path, "must be a string")
	elseif value == "" then
		pushError(errors, path, "must not be empty")
	end
end

local function validateBoolean(errors: {string}, path: string, value: any, required: boolean)
	if value == nil then
		if required then
			pushError(errors, path, "is required")
		end
		return
	end
	if type(value) ~= "boolean" then
		pushError(errors, path, "must be a boolean")
	end
end

local function validateNumber(errors: {string}, path: string, value: any, required: boolean, minValue: number?, allowEqualMin: boolean?)
	if value == nil then
		if required then
			pushError(errors, path, "is required")
		end
		return
	end
	if type(value) ~= "number" then
		pushError(errors, path, "must be a number")
		return
	end
	if minValue ~= nil then
		if allowEqualMin == true then
			if value < minValue then
				pushError(errors, path, string.format("must be >= %s", tostring(minValue)))
			end
		elseif value <= minValue then
			pushError(errors, path, string.format("must be > %s", tostring(minValue)))
		end
	end
end

local function validateNumberRange(errors: {string}, path: string, value: any, required: boolean, minValue: number?, maxValue: number?, includeMin: boolean?, includeMax: boolean?)
	if value == nil then
		if required then
			pushError(errors, path, "is required")
		end
		return
	end
	if type(value) ~= "number" then
		pushError(errors, path, "must be a number")
		return
	end
	if minValue ~= nil then
		if includeMin == true then
			if value < minValue then
				pushError(errors, path, string.format("must be >= %s", tostring(minValue)))
			end
		elseif value <= minValue then
			pushError(errors, path, string.format("must be > %s", tostring(minValue)))
		end
	end
	if maxValue ~= nil then
		if includeMax == true then
			if value > maxValue then
				pushError(errors, path, string.format("must be <= %s", tostring(maxValue)))
			end
		elseif value >= maxValue then
			pushError(errors, path, string.format("must be < %s", tostring(maxValue)))
		end
	end
end

local function throwIfInvalid(domainName: string, moduleName: string, errors: {string})
	if #errors == 0 then
		return
	end
	error(string.format(
		"[ConfigValidator] %s config module '%s' has %d error(s):\n- %s",
		domainName,
		moduleName,
		#errors,
		table.concat(errors, "\n- ")
	))
end

local function validateWeaponConfig(moduleName: string, cfg: any)
	local errors: {string} = {}
	if type(cfg) ~= "table" then
		error(string.format("[ConfigValidator] Weapon config module '%s' must return a table", moduleName))
	end

	validateString(errors, "id", cfg.id, true)
	validateBoolean(errors, "isDefault", cfg.isDefault, false)
	validateString(errors, "displayName", cfg.displayName, true)
	validateString(errors, "kind", cfg.kind, true)

	if cfg.fire ~= nil then
		if type(cfg.fire) ~= "table" then
			pushError(errors, "fire", "must be a table")
		else
			validateNumber(errors, "fire.rpm", cfg.fire.rpm, true, 0, false)
			validateBoolean(errors, "fire.auto", cfg.fire.auto, true)
		end
	else
		pushError(errors, "fire", "is required")
	end

	if cfg.ammo ~= nil then
		if type(cfg.ammo) ~= "table" then
			pushError(errors, "ammo", "must be a table")
		else
			validateNumber(errors, "ammo.magSize", cfg.ammo.magSize, true, 1, true)
			validateNumber(errors, "ammo.reserve", cfg.ammo.reserve, true, 0, true)
			validateNumber(errors, "ammo.reloadTime", cfg.ammo.reloadTime, true, 0, false)
		end
	else
		pushError(errors, "ammo", "is required")
	end

	if cfg.hitscan ~= nil then
		if type(cfg.hitscan) ~= "table" then
			pushError(errors, "hitscan", "must be a table")
		else
			validateNumber(errors, "hitscan.range", cfg.hitscan.range, true, 0, false)
			validateNumber(errors, "hitscan.damage", cfg.hitscan.damage, true, 0, false)
		end
	else
		pushError(errors, "hitscan", "is required")
	end

	if cfg.net ~= nil then
		if type(cfg.net) ~= "table" then
			pushError(errors, "net", "must be a table")
		else
			validateNumberRange(errors, "net.originOffsetTolerance", cfg.net.originOffsetTolerance, false, 0, 256, false, true)
			validateNumberRange(errors, "net.maxOriginOffsetFromHead", cfg.net.maxOriginOffsetFromHead, false, 0, 256, false, true)
			validateNumberRange(errors, "net.originMaxOffsetFromHead", cfg.net.originMaxOffsetFromHead, false, 0, 256, false, true)
			validateNumberRange(errors, "net.muzzleMaxOffset", cfg.net.muzzleMaxOffset, false, 0, 256, false, true)

			validateNumberRange(errors, "net.rofTolerance", cfg.net.rofTolerance, false, 0, 1, true, true)
			validateNumberRange(errors, "net.maxConeAngle", cfg.net.maxConeAngle, false, 0, 45, false, true)
			validateNumberRange(errors, "net.losTolerance", cfg.net.losTolerance, false, 0, 64, false, true)

			validateBoolean(errors, "net.allowFriendlyFire", cfg.net.allowFriendlyFire, false)
		end
	end

	throwIfInvalid("Weapon", moduleName, errors)
end

local function validateAbilityConfig(moduleName: string, cfg: any)
	local errors: {string} = {}
	if type(cfg) ~= "table" then
		error(string.format("[ConfigValidator] Ability config module '%s' must return a table", moduleName))
	end

	validateString(errors, "id", cfg.id, true)
	validateBoolean(errors, "isDefault", cfg.isDefault, false)
	validateNumber(errors, "cooldown", cfg.cooldown, false, 0, true)

	validateNumber(errors, "projectileSpeed", cfg.projectileSpeed, false, 0, false)
	validateNumber(errors, "maxDistance", cfg.maxDistance, false, 0, false)
	validateNumber(errors, "lifetime", cfg.lifetime, false, 0, false)
	validateNumber(errors, "explosionRadius", cfg.explosionRadius, false, 0, false)
	validateNumber(errors, "explosionMaxDamage", cfg.explosionMaxDamage, false, 0, true)
	validateNumber(errors, "explosionMinDamage", cfg.explosionMinDamage, false, 0, true)
	validateNumber(errors, "explosionFalloffExponent", cfg.explosionFalloffExponent, false, 0, false)

	validateBoolean(errors, "friendlyFire", cfg.friendlyFire, false)
	validateBoolean(errors, "selfDamage", cfg.selfDamage, false)
	validateString(errors, "deployableId", cfg.deployableId, false)
	validateNumber(errors, "deployableSpawnForwardOffset", cfg.deployableSpawnForwardOffset, false, 0, true)
	validateNumber(errors, "deployableSpawnUpOffset", cfg.deployableSpawnUpOffset, false, -50, true)
	validateBoolean(errors, "deployableUsePrototypeRunner", cfg.deployableUsePrototypeRunner, false)

	if type(cfg.explosionMaxDamage) == "number" and type(cfg.explosionMinDamage) == "number" then
		if cfg.explosionMaxDamage < cfg.explosionMinDamage then
			pushError(errors, "explosionMaxDamage", "must be >= explosionMinDamage")
		end
	end

	throwIfInvalid("Ability", moduleName, errors)
end

local function validateAnimationEntry(errors: {string}, basePath: string, entry: any)
	if type(entry) ~= "table" then
		pushError(errors, basePath, "must be a table")
		return
	end

	validateString(errors, basePath .. ".animationId", entry.animationId, true)
	if type(entry.animationId) == "string" and entry.animationId ~= "" then
		local validAnimId = string.match(entry.animationId, "^rbxassetid://%d+$") ~= nil
			or string.match(entry.animationId, "^%d+$") ~= nil
		if not validAnimId then
			pushError(errors, basePath .. ".animationId", "must be a numeric id or 'rbxassetid://<id>'")
		end
	end

	validateString(errors, basePath .. ".priority", entry.priority, false)
	validateBoolean(errors, basePath .. ".looped", entry.looped, false)
	validateNumber(errors, basePath .. ".fadeTime", entry.fadeTime, false, 0, true)
	validateNumber(errors, basePath .. ".speed", entry.speed, false, 0, false)
	validateNumber(errors, basePath .. ".weight", entry.weight, false, 0, true)
	validateNumber(errors, basePath .. ".referenceSpeed", entry.referenceSpeed, false, 0, false)
	validateString(errors, basePath .. ".triggerMode", entry.triggerMode, false)
	validateString(errors, basePath .. ".triggerMarkerName", entry.triggerMarkerName, false)
	validateNumber(errors, basePath .. ".triggerDelay", entry.triggerDelay, false, 0, true)
end

local function validateAnimationProfileConfig(moduleName: string, cfg: any)
	local errors: {string} = {}
	if type(cfg) ~= "table" then
		error(string.format("[ConfigValidator] AnimationProfile config module '%s' must return a table", moduleName))
	end

	validateString(errors, "id", cfg.id, true)
	validateBoolean(errors, "isDefault", cfg.isDefault, false)

	if cfg.defaults ~= nil then
		if type(cfg.defaults) ~= "table" then
			pushError(errors, "defaults", "must be a table")
		else
			validateNumber(errors, "defaults.fadeTime", cfg.defaults.fadeTime, false, 0, true)
			validateNumber(errors, "defaults.speed", cfg.defaults.speed, false, 0, false)
			validateNumber(errors, "defaults.weight", cfg.defaults.weight, false, 0, true)
			validateNumber(errors, "defaults.triggerDelay", cfg.defaults.triggerDelay, false, 0, true)
			validateNumberRange(errors, "defaults.runThresholdRatio", cfg.defaults.runThresholdRatio, false, 0, 2, false, true)
		end
	end

	if cfg.locomotion ~= nil then
		if type(cfg.locomotion) ~= "table" then
			pushError(errors, "locomotion", "must be a map table")
		else
			for key, entry in pairs(cfg.locomotion) do
				validateAnimationEntry(errors, "locomotion." .. tostring(key), entry)
			end
		end
	end

	if cfg.actions ~= nil then
		if type(cfg.actions) ~= "table" then
			pushError(errors, "actions", "must be a map table")
		else
			for key, entry in pairs(cfg.actions) do
				validateAnimationEntry(errors, "actions." .. tostring(key), entry)
			end
		end
	end

	throwIfInvalid("AnimationProfile", moduleName, errors)
end

local function validateDeployableConfig(moduleName: string, cfg: any, animationProfileById: {[string]: any}?)
	local errors: {string} = {}
	if type(cfg) ~= "table" then
		error(string.format("[ConfigValidator] Deployable config module '%s' must return a table", moduleName))
	end

	validateString(errors, "id", cfg.id, true)
	validateBoolean(errors, "isDefault", cfg.isDefault, false)
	validateString(errors, "displayName", cfg.displayName, false)
	validateString(errors, "kind", cfg.kind, false)
	validateString(errors, "animationProfileId", cfg.animationProfileId, true)
	if type(cfg.animationProfileId) == "string" and animationProfileById ~= nil and animationProfileById[cfg.animationProfileId] == nil then
		pushError(errors, "animationProfileId", string.format("references unknown animation profile id '%s'", cfg.animationProfileId))
	end
	validateString(errors, "ModelAssetName", cfg.ModelAssetName, false)
	validateString(errors, "templateName", cfg.templateName, false)
	if (type(cfg.ModelAssetName) ~= "string" or cfg.ModelAssetName == "")
		and (type(cfg.templateName) ~= "string" or cfg.templateName == "") then
		pushError(errors, "ModelAssetName/templateName", "one model key is required")
	end
	validateString(errors, "bodyPartName", cfg.bodyPartName, false)
	validateString(errors, "fallbackShape", cfg.fallbackShape, false)

	if cfg.fallbackSize ~= nil then
		if type(cfg.fallbackSize) ~= "table" then
			pushError(errors, "fallbackSize", "must be a table")
		else
			validateNumber(errors, "fallbackSize.x", cfg.fallbackSize.x, true, 0, false)
			validateNumber(errors, "fallbackSize.y", cfg.fallbackSize.y, true, 0, false)
			validateNumber(errors, "fallbackSize.z", cfg.fallbackSize.z, true, 0, false)
		end
	end

	if cfg.fallbackColor ~= nil then
		if type(cfg.fallbackColor) ~= "table" then
			pushError(errors, "fallbackColor", "must be a table")
		else
			validateNumberRange(errors, "fallbackColor.r", cfg.fallbackColor.r, true, 0, 255, true, true)
			validateNumberRange(errors, "fallbackColor.g", cfg.fallbackColor.g, true, 0, 255, true, true)
			validateNumberRange(errors, "fallbackColor.b", cfg.fallbackColor.b, true, 0, 255, true, true)
		end
	end

	validateNumber(errors, "Lifetime", cfg.Lifetime, false, 0, false)
	validateBoolean(errors, "KillBellEnabled", cfg.KillBellEnabled, false)
	validateString(errors, "KillBellSoundName", cfg.KillBellSoundName, false)
	validateBoolean(errors, "CanDamageAllies", cfg.CanDamageAllies, false)
	validateBoolean(errors, "CanDamageOwner", cfg.CanDamageOwner, false)
	validateString(errors, "DeploySoundName", cfg.DeploySoundName, false)
	validateNumber(errors, "MaxHealth", cfg.MaxHealth, false, 0, false)
	validateNumber(errors, "MoveSpeed", cfg.MoveSpeed, false, 0, true)
	validateNumber(errors, "DetectionRadius", cfg.DetectionRadius, false, 0, false)
	validateNumber(errors, "RetargetInterval", cfg.RetargetInterval, false, 0, true)
	validateBoolean(errors, "PatrolEnabled", cfg.PatrolEnabled, false)
	validateNumber(errors, "PatrolRadius", cfg.PatrolRadius, false, 0, true)
	validateNumber(errors, "PatrolStepInterval", cfg.PatrolStepInterval, false, 0, true)
	validateNumber(errors, "LoseTargetDistance", cfg.LoseTargetDistance, false, 0, true)
	validateNumber(errors, "TriggerRadius", cfg.TriggerRadius, false, 0, false)
	validateBoolean(errors, "TriggerOnTouch", cfg.TriggerOnTouch, false)
	validateNumber(errors, "ArmDelay", cfg.ArmDelay, false, 0, true)
	validateBoolean(errors, "StopOnArm", cfg.StopOnArm, false)
	validateString(errors, "ArmingSoundName", cfg.ArmingSoundName, false)
	validateString(errors, "ArmingFxName", cfg.ArmingFxName, false)
	validateNumber(errors, "ExplosionDamage", cfg.ExplosionDamage, false, 0, true)
	validateNumber(errors, "ExplosionRadius", cfg.ExplosionRadius, false, 0, false)
	validateString(errors, "ExplosionSoundName", cfg.ExplosionSoundName, false)
	validateString(errors, "ExplosionFxName", cfg.ExplosionFxName, false)
	validateNumber(errors, "ExplosionKnockback", cfg.ExplosionKnockback, false, 0, true)
	validateBoolean(errors, "ChainEnabled", cfg.ChainEnabled, false)
	validateNumber(errors, "ChainDuration", cfg.ChainDuration, false, 0, true)
	validateNumber(errors, "ChainInterval", cfg.ChainInterval, false, 0, true)
	validateNumber(errors, "ChainAreaHalfSize", cfg.ChainAreaHalfSize, false, 0, true)
	validateNumber(errors, "ChainExplosionDamage", cfg.ChainExplosionDamage, false, 0, true)
	validateNumber(errors, "ChainExplosionRadius", cfg.ChainExplosionRadius, false, 0, false)
	validateString(errors, "ChainExplosionSoundName", cfg.ChainExplosionSoundName, false)
	validateString(errors, "ChainExplosionFxName", cfg.ChainExplosionFxName, false)
	validateNumber(errors, "ChainExplosionKnockback", cfg.ChainExplosionKnockback, false, 0, true)
	validateNumber(errors, "ChainExplosionCount", cfg.ChainExplosionCount, false, 0, true)

	-- Legacy compatibility keys.
	validateNumber(errors, "lifetime", cfg.lifetime, false, 0, false)
	validateNumber(errors, "armDelay", cfg.armDelay, false, 0, true)
	validateNumber(errors, "maxHealth", cfg.maxHealth, false, 0, false)
	validateNumber(errors, "moveSpeed", cfg.moveSpeed, false, 0, true)
	validateNumber(errors, "detectionRadius", cfg.detectionRadius, false, 0, false)
	validateNumber(errors, "triggerRadius", cfg.triggerRadius, false, 0, false)

	validateBoolean(errors, "triggerOnTouch", cfg.triggerOnTouch, false)
	validateBoolean(errors, "autoAcquire", cfg.autoAcquire, false)
	validateBoolean(errors, "allowFriendlyFire", cfg.allowFriendlyFire, false)
	validateBoolean(errors, "allowFriendlyCollision", cfg.allowFriendlyCollision, false)

	validateNumber(errors, "explosionRadius", cfg.explosionRadius, false, 0, false)
	validateNumber(errors, "explosionMaxDamage", cfg.explosionMaxDamage, false, 0, true)
	validateNumber(errors, "explosionMinDamage", cfg.explosionMinDamage, false, 0, true)
	validateNumber(errors, "explosionFalloffExponent", cfg.explosionFalloffExponent, false, 0, false)
	validateNumber(errors, "explosionKnockback", cfg.explosionKnockback, false, 0, true)

	if cfg.fx ~= nil then
		if type(cfg.fx) ~= "table" then
			pushError(errors, "fx", "must be a table")
		else
			validateString(errors, "fx.armingFxName", cfg.fx.armingFxName, false)
			validateString(errors, "fx.explosionFxName", cfg.fx.explosionFxName, false)
			validateString(errors, "fx.chainExplosionFxName", cfg.fx.chainExplosionFxName, false)
			validateString(errors, "fx.chainExplosionEmittersPath", cfg.fx.chainExplosionEmittersPath, false)
			validateString(errors, "fx.armingEmittersPath", cfg.fx.armingEmittersPath, false)
			validateString(errors, "fx.spawnEmittersPath", cfg.fx.spawnEmittersPath, false)
			validateString(errors, "fx.explosionEmittersPath", cfg.fx.explosionEmittersPath, false)
		end
	end

	if cfg.sfx ~= nil then
		if type(cfg.sfx) ~= "table" then
			pushError(errors, "sfx", "must be a table")
		else
			validateString(errors, "sfx.killBellSoundPath", cfg.sfx.killBellSoundPath, false)
			validateString(errors, "sfx.deploySoundName", cfg.sfx.deploySoundName, false)
			validateString(errors, "sfx.armingSoundName", cfg.sfx.armingSoundName, false)
			validateString(errors, "sfx.explosionSoundName", cfg.sfx.explosionSoundName, false)
			validateString(errors, "sfx.chainExplosionSoundName", cfg.sfx.chainExplosionSoundName, false)
			validateString(errors, "sfx.deploySoundPath", cfg.sfx.deploySoundPath, false)
			validateString(errors, "sfx.explodeSequenceSoundPath", cfg.sfx.explodeSequenceSoundPath, false)
			validateString(errors, "sfx.chainExplosionSoundPath", cfg.sfx.chainExplosionSoundPath, false)
			validateString(errors, "sfx.spawnSoundPath", cfg.sfx.spawnSoundPath, false)
			validateString(errors, "sfx.explosionSoundPath", cfg.sfx.explosionSoundPath, false)
		end
	end

	if type(cfg.explosionMaxDamage) == "number" and type(cfg.explosionMinDamage) == "number" then
		if cfg.explosionMaxDamage < cfg.explosionMinDamage then
			pushError(errors, "explosionMaxDamage", "must be >= explosionMinDamage")
		end
	end

	throwIfInvalid("Deployable", moduleName, errors)
end

local function validatePlantableConfig(moduleName: string, cfg: any, deployableById: {[string]: any}?)
	local errors: {string} = {}
	if type(cfg) ~= "table" then
		error(string.format("[ConfigValidator] Plantable config module '%s' must return a table", moduleName))
	end

	validateString(errors, "id", cfg.id, true)
	validateBoolean(errors, "isDefault", cfg.isDefault, false)
	validateString(errors, "displayName", cfg.displayName, false)
	validateString(errors, "deployableId", cfg.deployableId, true)
	validateString(errors, "spotType", cfg.spotType, false)

	validateBoolean(errors, "allowEnemySpots", cfg.allowEnemySpots, false)
	validateBoolean(errors, "requiresFreeSpot", cfg.requiresFreeSpot, false)
	validateBoolean(errors, "usePrototypeRunner", cfg.usePrototypeRunner, false)

	validateNumber(errors, "placeRange", cfg.placeRange, false, 0, false)
	validateNumber(errors, "selectionRadius", cfg.selectionRadius, false, 0, false)
	validateNumber(errors, "spawnForwardOffset", cfg.spawnForwardOffset, false, -50, true)
	validateNumber(errors, "spawnUpOffset", cfg.spawnUpOffset, false, -50, true)
	validateNumber(errors, "cooldown", cfg.cooldown, false, 0, true)
	validateNumber(errors, "maxActive", cfg.maxActive, false, 1, true)

	if type(cfg.deployableId) == "string" and deployableById ~= nil and deployableById[cfg.deployableId] == nil then
		pushError(errors, "deployableId", string.format("references unknown deployable id '%s'", cfg.deployableId))
	end

	throwIfInvalid("Plantable", moduleName, errors)
end

local function validateCharacterConfig(
	moduleName: string,
	cfg: any,
	abilityById: {[string]: any}?,
	weaponById: {[string]: any}?,
	animationProfileById: {[string]: any}?,
	plantableById: {[string]: any}?
)
	local errors: {string} = {}
	if type(cfg) ~= "table" then
		error(string.format("[ConfigValidator] Character config module '%s' must return a table", moduleName))
	end

	validateString(errors, "id", cfg.id, true)
	validateBoolean(errors, "isDefault", cfg.isDefault, false)
	validateString(errors, "weaponId", cfg.weaponId, true)
	validateString(errors, "animationProfileId", cfg.animationProfileId, true)

	if type(cfg.weaponId) == "string" and weaponById ~= nil and weaponById[cfg.weaponId] == nil then
		pushError(errors, "weaponId", string.format("references unknown weapon id '%s'", cfg.weaponId))
	end
	if type(cfg.animationProfileId) == "string" and animationProfileById ~= nil and animationProfileById[cfg.animationProfileId] == nil then
		pushError(errors, "animationProfileId", string.format("references unknown animation profile id '%s'", cfg.animationProfileId))
	end

	if cfg.abilities ~= nil then
		if type(cfg.abilities) ~= "table" then
			pushError(errors, "abilities", "must be an array table")
		else
			for index, slot in ipairs(cfg.abilities) do
				local basePath = string.format("abilities[%d]", index)
				if type(slot) ~= "table" then
					pushError(errors, basePath, "must be a table")
				else
					validateString(errors, basePath .. ".id", slot.id, true)
					validateString(errors, basePath .. ".key", slot.key, false)
					validateString(errors, basePath .. ".animationActionKey", slot.animationActionKey, false)
					if type(slot.id) == "string" and abilityById ~= nil and abilityById[slot.id] == nil then
						pushError(errors, basePath .. ".id", string.format("references unknown ability id '%s'", slot.id))
					end
				end
			end
		end
	end

	if cfg.plantables ~= nil then
		if type(cfg.plantables) ~= "table" then
			pushError(errors, "plantables", "must be an array table")
		else
			for index, slot in ipairs(cfg.plantables) do
				local basePath = string.format("plantables[%d]", index)
				if type(slot) ~= "table" then
					pushError(errors, basePath, "must be a table")
				else
					validateString(errors, basePath .. ".id", slot.id, true)
					validateString(errors, basePath .. ".key", slot.key, false)
					if type(slot.id) == "string" and plantableById ~= nil and plantableById[slot.id] == nil then
						pushError(errors, basePath .. ".id", string.format("references unknown plantable id '%s'", slot.id))
					end
				end
			end
		end
	end

	throwIfInvalid("Character", moduleName, errors)
end

local function runStaticAudit(
	abilityById: {[string]: any},
	weaponById: {[string]: any},
	animationProfileById: {[string]: any},
	characterById: {[string]: any},
	deployableById: {[string]: any}?,
	plantableById: {[string]: any}?
)
	for abilityId, abilityCfg in pairs(abilityById) do
		validateAbilityConfig(string.format("AbilityById[%s]", abilityId), abilityCfg)
	end
	for weaponId, weaponCfg in pairs(weaponById) do
		validateWeaponConfig(string.format("WeaponById[%s]", weaponId), weaponCfg)
	end
	for animationProfileId, animationProfileCfg in pairs(animationProfileById) do
		validateAnimationProfileConfig(string.format("AnimationProfileById[%s]", animationProfileId), animationProfileCfg)
	end
	for characterId, characterCfg in pairs(characterById) do
		validateCharacterConfig(string.format("CharacterById[%s]", characterId), characterCfg, abilityById, weaponById, animationProfileById, plantableById)
	end
	if deployableById then
		for deployableId, deployableCfg in pairs(deployableById) do
			validateDeployableConfig(string.format("DeployableById[%s]", deployableId), deployableCfg, animationProfileById)
		end
	end
	if plantableById then
		for plantableId, plantableCfg in pairs(plantableById) do
			validatePlantableConfig(string.format("PlantableById[%s]", plantableId), plantableCfg, deployableById)
		end
	end
end

return {
	validateWeaponConfig = validateWeaponConfig,
	validateCharacterConfig = validateCharacterConfig,
	validateAbilityConfig = validateAbilityConfig,
	validateAnimationProfileConfig = validateAnimationProfileConfig,
	validateDeployableConfig = validateDeployableConfig,
	validatePlantableConfig = validatePlantableConfig,
	runStaticAudit = runStaticAudit,
}

