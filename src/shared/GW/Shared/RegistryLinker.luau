--!strict

type AbilityMap = {[string]: any}
type WeaponMap = {[string]: any}
type CharacterMap = {[string]: any}
type AbilityToCharacterIds = {[string]: {string}}

local function fail(message: string)
	error(string.format("[RegistryLinker] %s", message))
end

local function buildAbilityToCharacterIds(abilityById: AbilityMap, weaponById: WeaponMap, characterById: CharacterMap): AbilityToCharacterIds
	local abilityToCharacterIds: AbilityToCharacterIds = {}

	for characterId, characterCfg in pairs(characterById) do
		local weaponId = characterCfg.weaponId
		if type(weaponId) ~= "string" or weaponById[weaponId] == nil then
			fail(string.format("Character '%s' references missing weaponId '%s'", tostring(characterId), tostring(weaponId)))
		end

		local seenAbilityIds: {[string]: true} = {}
		local abilities = characterCfg.abilities
		if abilities ~= nil then
			for slotIndex, slot in ipairs(abilities) do
				if type(slot) ~= "table" then
					fail(string.format("Character '%s' has invalid ability slot at index %d", tostring(characterId), slotIndex))
				end

				local abilityId = slot.id
				if type(abilityId) ~= "string" or abilityById[abilityId] == nil then
					fail(string.format("Character '%s' references missing abilityId '%s' at abilities[%d]", tostring(characterId), tostring(abilityId), slotIndex))
				end

				if seenAbilityIds[abilityId] then
					fail(string.format("Character '%s' has duplicated abilityId '%s'", tostring(characterId), abilityId))
				end
				seenAbilityIds[abilityId] = true

				local owners = abilityToCharacterIds[abilityId]
				if owners == nil then
					owners = {}
					abilityToCharacterIds[abilityId] = owners
				end
				table.insert(owners, characterId)
			end
		end
	end

	for _, characterIds in pairs(abilityToCharacterIds) do
		table.sort(characterIds)
	end

	return abilityToCharacterIds
end

local function link(abilityById: AbilityMap, weaponById: WeaponMap, characterById: CharacterMap)
	return {
		abilityToCharacterIds = buildAbilityToCharacterIds(abilityById, weaponById, characterById),
	}
end

return {
	link = link,
}

