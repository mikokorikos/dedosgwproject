--!strict

export type WeaponConfig = {
	id: string,
	isDefault: boolean?,
	displayName: string,
	kind: string,

	mount: {
		gunModelName: string,
		muzzleAttachmentName: string,
	}?,

	fire: {
		rpm: number,
		auto: boolean,
	}?,

	ammo: {
		magSize: number,
		reserve: number,
		reloadTime: number,
	}?,

	hitscan: {
		range: number,
		damage: number,
	}?,

	fx: {
		muzzleEmittersPath: string?,
		impactEmittersPath: string?,
		beamTemplatePath: string?,
		tracer: {
			mode: string?,
			speed: number?,
			persist: number?,
			fade: number?,
			width0: number?,
			width1: number?,
			brightness: number?,
		}?,
	}?,

	sfx: {
		shotPath: string?,
		hitConfirmPath: string?,
		killConfirmPath: string?,
	}?,

	net: {
		originMaxOffsetFromHead: number?,
		muzzleMaxOffset: number?,
		allowFriendlyFire: boolean?,
	}?,
}

export type CharacterAbilitySlot = {
	id: string,
	key: string?,
}

export type CharacterConfig = {
	id: string,
	isDefault: boolean?,
	weaponId: string,
	abilities: {CharacterAbilitySlot}?,
}

export type AbilityConfig = {
	id: string,
	isDefault: boolean?,
	cooldown: number?,

	characterRocketName: string?,
	regrowStartScale: number?,
	regrowDelay: number?,
	regrowTime: number?,
	spawnForwardOffset: number?,
	spawnUpOffset: number?,

	projectileTemplateName: string?,
	projectileBodyName: string?,
	projectileFlightAttachmentName: string?,
	projectileSpeed: number?,
	maxDistance: number?,
	lifetime: number?,

	launchSoundName: string?,
	flightLoopSoundName: string?,

	explosionRadius: number?,
	explosionMaxDamage: number?,
	explosionMinDamage: number?,
	explosionFalloffExponent: number?,
	friendlyFire: boolean?,
	selfDamage: boolean?,

	fx: {
		explosionEmittersFolderName: string?,
	}?,
	sfx: {
		explosionSoundName: string?,
	}?,
}

return nil
