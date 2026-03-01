--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local CharacterRegistry = require(RS.GW.Shared.CharacterRegistry)
local WeaponRegistry = require(RS.GW.Shared.WeaponRegistry)
local Net = require(RS.GW.Shared.Net)

local function applyDefaults(player: Player)
	local charCfg = CharacterRegistry.Get(nil)
	player:SetAttribute("CharacterId", charCfg.id)
	player:SetAttribute("WeaponId", charCfg.weaponId or WeaponRegistry.DefaultId)
end

Players.PlayerAdded:Connect(function(player)
	applyDefaults(player)
	player.CharacterAdded:Connect(function()
		-- re-aplica en respawn
		applyDefaults(player)

		-- manda ammo inicial (lo envía CombatService también, pero aquí aseguramos)
		Net.FXEvent:FireClient(player, { type="Init", weaponId = player:GetAttribute("WeaponId") })
	end)
end)

for _, p in ipairs(Players:GetPlayers()) do
	applyDefaults(p)
end

print("[GW] CharacterService activo.")
