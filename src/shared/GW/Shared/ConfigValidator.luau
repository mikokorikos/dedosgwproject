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

	if type(cfg.explosionMaxDamage) == "number" and type(cfg.explosionMinDamage) == "number" then
		if cfg.explosionMaxDamage < cfg.explosionMinDamage then
			pushError(errors, "explosionMaxDamage", "must be >= explosionMinDamage")
		end
	end

	throwIfInvalid("Ability", moduleName, errors)
end

local function validateCharacterConfig(moduleName: string, cfg: any, abilityById: {[string]: any}?, weaponById: {[string]: any}?)
	local errors: {string} = {}
	if type(cfg) ~= "table" then
		error(string.format("[ConfigValidator] Character config module '%s' must return a table", moduleName))
	end

	validateString(errors, "id", cfg.id, true)
	validateBoolean(errors, "isDefault", cfg.isDefault, false)
	validateString(errors, "weaponId", cfg.weaponId, true)

	if type(cfg.weaponId) == "string" and weaponById ~= nil and weaponById[cfg.weaponId] == nil then
		pushError(errors, "weaponId", string.format("references unknown weapon id '%s'", cfg.weaponId))
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
					if type(slot.id) == "string" and abilityById ~= nil and abilityById[slot.id] == nil then
						pushError(errors, basePath .. ".id", string.format("references unknown ability id '%s'", slot.id))
					end
				end
			end
		end
	end

	throwIfInvalid("Character", moduleName, errors)
end

local function runStaticAudit(abilityById: {[string]: any}, weaponById: {[string]: any}, characterById: {[string]: any})
	for abilityId, abilityCfg in pairs(abilityById) do
		validateAbilityConfig(string.format("AbilityById[%s]", abilityId), abilityCfg)
	end
	for weaponId, weaponCfg in pairs(weaponById) do
		validateWeaponConfig(string.format("WeaponById[%s]", weaponId), weaponCfg)
	end
	for characterId, characterCfg in pairs(characterById) do
		validateCharacterConfig(string.format("CharacterById[%s]", characterId), characterCfg, abilityById, weaponById)
	end
end

return {
	validateWeaponConfig = validateWeaponConfig,
	validateCharacterConfig = validateCharacterConfig,
	validateAbilityConfig = validateAbilityConfig,
	runStaticAudit = runStaticAudit,
}
