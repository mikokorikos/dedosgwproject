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
		-- Compat aliases for server-side origin validation offsets.
		originOffsetTolerance: number?,
		maxOriginOffsetFromHead: number?,
		originMaxOffsetFromHead: number?,
		muzzleMaxOffset: number?,
		rofTolerance: number?,
		maxConeAngle: number?,
		losTolerance: number?,
		allowFriendlyFire: boolean?,
	}?,
}

export type CharacterAbilitySlot = {
	id: string,
	key: string?,
	animationActionKey: string?,
}

export type CharacterPlantableSlot = {
	id: string,
	key: string?,
}

export type CharacterConfig = {
	id: string,
	isDefault: boolean?,
	weaponId: string,
	animationProfileId: string,
	abilities: {CharacterAbilitySlot}?,
	plantables: {CharacterPlantableSlot}?,
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
	deployableId: string?,
	deployableSpawnForwardOffset: number?,
	deployableSpawnUpOffset: number?,
	deployableUsePrototypeRunner: boolean?,

	fx: {
		explosionEmittersFolderName: string?,
	}?,
	sfx: {
		explosionSoundName: string?,
	}?,
}

export type DeployableConfig = {
	id: string,
	isDefault: boolean?,
	displayName: string?,
	kind: string?,
	animationProfileId: string?,

	-- Canonical / legacy model keys.
	ModelAssetName: string?,
	templateName: string?,
	bodyPartName: string?,
	fallbackShape: string?,
	fallbackSize: {
		x: number?,
		y: number?,
		z: number?,
	}?,
	fallbackColor: {
		r: number?,
		g: number?,
		b: number?,
	}?,

	-- Canonical keys.
	Lifetime: number?,
	KillBellEnabled: boolean?,
	KillBellSoundName: string?,
	CanDamageAllies: boolean?,
	CanDamageOwner: boolean?,
	DeploySoundName: string?,
	MaxHealth: number?,
	MoveSpeed: number?,
	DetectionRadius: number?,
	RetargetInterval: number?,
	PatrolEnabled: boolean?,
	PatrolRadius: number?,
	PatrolStepInterval: number?,
	LoseTargetDistance: number?,
	TriggerRadius: number?,
	TriggerOnTouch: boolean?,
	ArmDelay: number?,
	StopOnArm: boolean?,
	ArmingSoundName: string?,
	ArmingFxName: string?,
	ExplosionDamage: number?,
	ExplosionRadius: number?,
	ExplosionSoundName: string?,
	ExplosionFxName: string?,
	ExplosionKnockback: number?,
	ChainEnabled: boolean?,
	ChainDuration: number?,
	ChainInterval: number?,
	ChainAreaHalfSize: number?,
	ChainExplosionDamage: number?,
	ChainExplosionRadius: number?,
	ChainExplosionSoundName: string?,
	ChainExplosionFxName: string?,
	ChainExplosionKnockback: number?,
	ChainExplosionCount: number?,

	-- Legacy keys kept for compatibility.
	lifetime: number?,
	armDelay: number?,
	maxHealth: number?,
	moveSpeed: number?,
	detectionRadius: number?,
	triggerRadius: number?,
	triggerOnTouch: boolean?,
	autoAcquire: boolean?,
	allowFriendlyFire: boolean?,
	allowFriendlyCollision: boolean?,

	explosionRadius: number?,
	explosionMaxDamage: number?,
	explosionMinDamage: number?,
	explosionFalloffExponent: number?,
	explosionKnockback: number?,

	fx: {
		armingFxName: string?,
		explosionFxName: string?,
		chainExplosionFxName: string?,
		chainExplosionEmittersPath: string?,
		armingEmittersPath: string?,
		spawnEmittersPath: string?,
		explosionEmittersPath: string?,
	}?,
	sfx: {
		killBellSoundPath: string?,
		deploySoundName: string?,
		armingSoundName: string?,
		explosionSoundName: string?,
		chainExplosionSoundName: string?,
		deploySoundPath: string?,
		explodeSequenceSoundPath: string?,
		chainExplosionSoundPath: string?,
		spawnSoundPath: string?,
		explosionSoundPath: string?,
	}?,
}

export type AnimationEntryConfig = {
	animationId: string,
	priority: string?,
	looped: boolean?,
	fadeTime: number?,
	speed: number?,
	weight: number?,
	referenceSpeed: number?,
	triggerMode: string?,
	triggerMarkerName: string?,
	triggerDelay: number?,
}

export type AnimationProfileConfig = {
	id: string,
	isDefault: boolean?,
	defaults: {
		fadeTime: number?,
		speed: number?,
		weight: number?,
		triggerDelay: number?,
		runThresholdRatio: number?,
	}?,
	locomotion: {[string]: AnimationEntryConfig}?,
	actions: {[string]: AnimationEntryConfig}?,
}

export type PlantableConfig = {
	id: string,
	isDefault: boolean?,
	displayName: string?,

	deployableId: string,
	spotType: string?,
	allowEnemySpots: boolean?,
	requiresFreeSpot: boolean?,

	placeRange: number?,
	selectionRadius: number?,
	spawnForwardOffset: number?,
	spawnUpOffset: number?,

	cooldown: number?,
	maxActive: number?,
	usePrototypeRunner: boolean?,
}

return nil
