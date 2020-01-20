
if LibManaTicks ~= nil then return end
local _, playerClass = UnitClass("player")
if playerClass == "WARRIOR" or playerClass == "ROGUE" then return end

local batchWindow = 0.5 -- seconds, must include padding for batch timing error
local tickInterval = 2.03 -- seconds, mana tick interval
local spellcastBlockLength = 5 -- seconds, time until ticks are allowed after spellcast

local energizeRejectUntil = 0
local castBlockUntil = 0
local predictedTick = 1/0 -- = inf
local meditationTalent = false
local meditationGear = false
local meditationBuffs
local triggers = {}
local meditation = {
	talents = {
		["PRIEST"] = {1,8}, -- Meditation, verify!
		["DRUID"] = {3,6}, -- Reflection, verify!
		["MAGE"] = {1,12}, -- Arcane Meditation, verify!
	},
	buffs = {
		[15271] = true, -- Spirit Tap
		[18371] = true, -- Soul Siphon from Improved Drain Soul talent
		[23684] = true, -- Aura of the Blue Dragon from Darkmoon Card: Blue Dragon
		[29166] = true, -- Innervate
	},
	state = {
		talent = false,
		buff = false,
		gear = false,
	}
}

LibManaTicks = {
	version = "1.0",
}

function LibManaTicks.RegisterCallback(self, e, f)
	if triggers[e] == nil then
		triggers[e] = {}
	end
	table.insert(triggers[e], f)
end

local function TriggerEvent(e)
	if triggers[e] == nil then return end
	for _,f in pairs(triggers[e]) do
		f(e)
	end
end

local playerMana = nil
local function UpdateMana()
	local mana = UnitPower("player", 0)
	local diff = mana - (playerMana or mana)
	playerMana = mana
	return diff
end

local function ManaTick(isReal)
	TriggerEvent("ManaTickAlways")
	if isReal then TriggerEvent("ManaTick") end
	predictedTick = GetTime() + tickInterval
end

local function CheckTalents()
	local t = meditation.talents[playerClass]
	if t == nil then return end
	local points = select(5, GetTalentInfo(unpack(t)))
	meditation.state.talent = points > 0
	return meditation.state.talent
end

local function CheckBuffs()
	local i = 1
	while true do
		local buffId = select(10, UnitBuff("player", i))
		if buffId == nil then return false end
		if meditation.buffs[buffId] then
			meditation.state.buff = true
			return true
		end
		i = i + 1
	end
end

local function CheckGear()
	for i = 1,19 do
		local item = GetInventoryItemLink("player", i)
		if item then
			local stats = GetItemStats(item)
			if stats then
				local mp5 = stats["ITEM_MOD_POWER_REGEN0_SHORT"]
				if mp5 and mp5 > 0 then
					meditation.state.gear = true
					return true
				end
			end
		end
	end
	meditation.state.gear = false
	return false
end

local function IsRegenBlocked()
	if meditation.state.talent or meditation.state.gear then return false end
	if CheckBuffs() then return false end
	local t = GetTime()
	return t < energizeRejectUntil or t < castBlockUntil
end

local batch = {
	spellCast = false,
	lostMana = false,
}

local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, e, ...)
	if e == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, a, _, _, _, _, _, targetGUID = CombatLogGetCurrentEventInfo()
		if a ~= "SPELL_ENERGIZE" or targetGUID ~= UnitGUID("player") then return end
		local t = GetTime()
		energizeRejectUntil = t + batchWindow
	elseif e == "UNIT_SPELLCAST_SUCCEEDED" then
		batch.spellCast = true
	elseif e == "UNIT_POWER_UPDATE" then
		local manadiff = UpdateMana()
		if manadiff < 0 then batch.lostMana = true end
		if manadiff <= 0 then return end
		if IsRegenBlocked() then return end
		ManaTick(true)
	elseif e == "CHARACTER_POINTS_CHANGED" or e == "PLAYER_ENTERING_WORLD" then
		CheckTalents()
	end
end)

f:SetScript("OnUpdate", function()
	local t = GetTime()
	if batch.spellCast and batch.lostMana then
		castBlockUntil = t + spellcastBlockLength
		TriggerEvent("Spellcast")
	end
	batch = {
		spellCast = false,
		lostMana = false,
	}
	if predictedTick <= t then
		ManaTick(false)
	end
end)

f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("UNIT_POWER_UPDATE")
f:RegisterEvent("CHARACTER_POINTS_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
