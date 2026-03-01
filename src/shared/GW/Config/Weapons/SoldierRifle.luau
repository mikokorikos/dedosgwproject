return {
	id = "SoldierRifle",
	isDefault = true,
	displayName = "Soldier Rifle",
	kind = "Hitscan",

	mount = { gunModelName = "SoldierGun", muzzleAttachmentName = "Muzzle" },
	fire = { rpm = 420, auto = true },
	ammo = { magSize = 30, reserve = 120, reloadTime = 1.9 },
	hitscan = { range = 800, damage = 10 },

	fx = {
		muzzleEmittersPath = "Weapons/SoldierRifle/MuzzleEmitters",
		impactEmittersPath = "Weapons/SoldierRifle/ImpactEmitters",
		beamTemplatePath   = "Weapons/SoldierRifle/TracerBeamTemplate",

		tracer = {
			mode = "Snapshot",
			speed = 3200, persist = 0.035, fade = 0.8,
			width0 = 0.16, width1 = 0.10,
			brightness = 1.0,
		},
	},

	sfx = {
		shotPath        = "Weapons/SoldierRifle/ShotSoundTemplate",
		hitConfirmPath  = "Weapons/SoldierRifle/HitConfirmSoundTemplate",
		killConfirmPath = "Weapons/SoldierRifle/KillConfirmSoundTemplate",
	},

	net = { originMaxOffsetFromHead = 20, muzzleMaxOffset = 14, allowFriendlyFire = false },
}
