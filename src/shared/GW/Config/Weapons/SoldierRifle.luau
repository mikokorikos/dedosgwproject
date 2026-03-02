--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type WeaponConfig = Types.WeaponConfig

local config: WeaponConfig = {
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
		beamTemplatePath = "Weapons/SoldierRifle/TracerBeamTemplate",

		tracer = {
			mode = "Snapshot",
			speed = 3200,
			persist = 0.035,
			fade = 0.8,
			width0 = 0.16,
			width1 = 0.10,
			brightness = 1.0,
		},
	},

	sfx = {
		shotPath = "Weapons/SoldierRifle/ShotSoundTemplate",
		hitConfirmPath = "Weapons/SoldierRifle/HitConfirmSoundTemplate",
		killConfirmPath = "Weapons/SoldierRifle/KillConfirmSoundTemplate",
	},

	net = {
		-- Aliases de offset de origen (equivalentes entre sí para compatibilidad).
		originOffsetTolerance = 20,
		maxOriginOffsetFromHead = 20,
		originMaxOffsetFromHead = 20,
		muzzleMaxOffset = 14,

		-- Nuevos campos de tuning de red.
		rofTolerance = 0.12,
		maxConeAngle = 6,
		losTolerance = 12,

		-- Equivalencias con los campos net actuales del servidor:
		-- * originOffsetTolerance/maxOriginOffsetFromHead ~= originMaxOffsetFromHead
		-- * losTolerance ~= recastHitPosTolerance
		-- * maxConeAngle reemplaza la tolerancia lineal de "claimedHitLineTolerance"
		allowFriendlyFire = false,
	},
}

return config
