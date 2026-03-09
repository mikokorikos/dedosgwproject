--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type AbilityConfig = Types.AbilityConfig

local config: AbilityConfig = {
	id = "BackRocket",
	isDefault = true,
	cooldown = 8,

	characterRocketName = "BackRocketVisual",
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

	launchSoundName = "RocketLaunchSound",
	flightLoopSoundName = "RocketFlightLoop",

	clientAnimId = "rbxassetid://81601740746075",
	useMarker = true,
	launchMarkerName = "Launch",
	fallbackLaunchDelay = 0.35,

	explosionRadius = 12,
	explosionMaxDamage = 45,
	explosionMinDamage = 10,
	explosionFalloffExponent = 1.0,
	friendlyFire = false,
	selfDamage = false,

	fx = {
		explosionEmittersFolderName = "RocketExplosionEmitters",
	},
	sfx = {
		explosionSoundName = "RocketExplosionSound",
	},
}

return config

