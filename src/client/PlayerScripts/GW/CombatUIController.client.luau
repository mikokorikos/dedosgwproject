--!strict
-- HitConfirm + KillFeed usando SoldierCombatUI existente (si existe)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Net = require(RS.GW.Shared.Net)
local Weapons = require(RS.GW.Shared.WeaponRegistry)

local Sounds = RS.GW.Assets.Sounds

local ui, panel, entriesFrame, entryTemplate, hitmarker
local hmLines = {}
local token = 0

local function bind()
	local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
	ui = pg:FindFirstChild("SoldierCombatUI")
	if not ui then return end

	panel = ui:FindFirstChild("KillFeedPanel")
	entriesFrame = panel and panel:FindFirstChild("Entries")
	entryTemplate = entriesFrame and entriesFrame:FindFirstChild("EntryTemplate")
	local hmLayer = ui:FindFirstChild("HitmarkerLayer")
	hitmarker = hmLayer and hmLayer:FindFirstChild("Hitmarker")

	hmLines = {}
	if hitmarker then
		for _, n in ipairs({"L1","L2","L3","L4"}) do
			local line = hitmarker:FindFirstChild(n)
			if line and line:IsA("Frame") then table.insert(hmLines, line) end
		end
	end
end

local function playTemplate(name: string)
	local t = Sounds:FindFirstChild(name)
	if not (t and t:IsA("Sound")) then return end
	if t.SoundId == "" or t.SoundId == "rbxassetid://0" then return end
	local s = t:Clone()
	s.Parent = SoundService
	s.Looped = false
	s:Play()
	Debris:AddItem(s, 2.5)
end

local function showHitmarker(isKill: boolean)
	if not hitmarker then return end
	token += 1
	local my = token

	for _, line in ipairs(hmLines) do
		line.BackgroundTransparency = 0
	end
	hitmarker.Visible = true

	task.delay(0.10, function()
		if my ~= token then return end
		for _, line in ipairs(hmLines) do
			TweenService:Create(line, TweenInfo.new(0.08), {BackgroundTransparency = 1}):Play()
		end
		task.delay(0.1, function()
			if my ~= token then return end
			hitmarker.Visible = false
		end)
	end)
end

local function addKillEntry(payload: any)
	if not (entriesFrame and entryTemplate) then return end
	local killer = tostring(payload.killerName or "Unknown")
	local victim = tostring(payload.victimName or "Unknown")
	local wname = tostring(payload.weaponDisplayName or payload.weaponId or "Weapon")

	local e = entryTemplate:Clone()
	e.Name = "KillEntry"
	e.Visible = true
	e.TextTransparency = 0
	e.BackgroundTransparency = 0.92
	e.Text = string.format("%s eliminó a %s [%s]", killer, victim, wname)
	e.Parent = entriesFrame

	task.delay(7, function()
		if not e.Parent then return end
		TweenService:Create(e, TweenInfo.new(0.35), {TextTransparency=1, BackgroundTransparency=1}):Play()
		task.delay(0.4, function()
			if e.Parent then e:Destroy() end
		end)
	end)
end

Net.FXEvent.OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then return end

	if ev.type == "HitConfirm" then
		showHitmarker(ev.kill == true)
		local weapon = Weapons.Get(ev.weaponId)
		if ev.kill == true then
			playTemplate(weapon.sfx and weapon.sfx.killConfirmTemplate or "KillConfirmSoundTemplate")
		else
			playTemplate(weapon.sfx and weapon.sfx.hitConfirmTemplate or "HitConfirmSoundTemplate")
		end
	elseif ev.type == "KillFeed" then
		addKillEntry(ev)
	end
end)

player.CharacterAdded:Connect(function()
	task.defer(bind)
end)

task.defer(function()
	bind()
	print("[GW] CombatUIController listo.")
end)
