--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type AbilityConfig = Types.AbilityConfig

local config: AbilityConfig = {
	id = "BackRocket",
	isDefault = true,
	cooldown = 8,

	characterRocketName = "BackRocket",
	regrowStartScale = 0.06,
	regrowDelay = 0.2,
	regrowTime = 3.0,
	spawnForwardOffset = 2.2,
	spawnUpOffset = 0.35,

	projectileTemplateName = "BackRocketProjectile",
	projectileBodyName = "Rocket",
	projectileFlightAttachmentName = "Flight",
	projectileSpeed = 80,
	maxDistance = 220,
	lifetime = 2.8,

	launchSoundName = "BackRocketLaunch",
	flightLoopSoundName = "BackRocketFlightLoop",

	explosionRadius = 12,
	explosionMaxDamage = 45,
	explosionMinDamage = 10,
	explosionFalloffExponent = 1.0,
	friendlyFire = false,
	selfDamage = false,

	fx = {
		explosionEmittersFolderName = "BackRocketExplosion",
	},
	sfx = {
		explosionSoundName = "BackRocketExplosion",
	},
}

return config
