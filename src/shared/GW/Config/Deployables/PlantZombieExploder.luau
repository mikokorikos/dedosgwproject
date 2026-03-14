--!strict
local Types = require(script.Parent.Parent.Parent.Shared.Types)
type DeployableConfig = Types.DeployableConfig

local config: DeployableConfig = {
	id = "PlantZombieExploder",
	isDefault = true,
	displayName = "Plant Zombie (Legendary Exploder)",
	kind = "ExploderLegendary",
	animationProfileId = "PlantZombieExploderAnimationProfile",

	ModelAssetName = "PlantZombieExploderModel",
	bodyPartName = "HumanoidRootPart",

	-- General.
	Lifetime = 14,
	KillBellEnabled = true,
	KillBellSoundName = "Combat/KillBell",
	CanDamageAllies = false,
	CanDamageOwner = false,
	MaxHealth = 70,

	-- Deploy.
	DeploySoundName = "Deployables/PlantZombieExploder/Deploy",

	-- Movement / patrol / chase.
	MoveSpeed = 13,
	DetectionRadius = 180,
	RetargetInterval = 0.25,
	PatrolEnabled = true,
	PatrolRadius = 22,
	PatrolStepInterval = 0.85,
	LoseTargetDistance = 250,
	TriggerRadius = 4.5,
	TriggerOnTouch = true,

	-- Arming.
	ArmDelay = 2.0,
	StopOnArm = true,
	ArmingSoundName = "Deployables/PlantZombieExploder/Arming",
	ArmingFxName = "Deployables/PlantZombieExploder/Arming",

	-- Main explosion.
	ExplosionDamage = 25,
	ExplosionRadius = 13,
	ExplosionSoundName = "Deployables/PlantZombieExploder/Explosion",
	ExplosionFxName = "Deployables/PlantZombieExploder/Explosion",
	ExplosionKnockback = 70,

	-- Chain explosions.
	ChainEnabled = true,
	ChainDuration = 10.0,
	ChainInterval = 0.25,
	ChainAreaHalfSize = 16,
	ChainExplosionDamage = 60,
	ChainExplosionRadius = 8,
	ChainExplosionSoundName = "Deployables/PlantZombieExploder/Explosion",
	ChainExplosionFxName = "Deployables/PlantZombieExploder/ChainExplosion",
	ChainExplosionKnockback = 40,
	ChainExplosionCount = 0, -- 0 = unlimited by count; limited by duration/interval.
}

return config
