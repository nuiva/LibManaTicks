
if LibManaTicks ~= nil then return end
local _, playerClass = UnitClass("player")
local playerGUID = UnitGUID("player")

local batchWindow = 0.4 -- seconds, spell batch length
local batchError = 0.1 -- seconds, error tolerance for batch delays
local tickInterval = 2.03 -- seconds, mana tick interval

local energizeRejectUntil = 0
local predictedTick = 1/0 -- = inf
local triggers = {}

LibManaTicks = {
	version = "1.0",
}

function LibManaTicks.RegisterCallback(self, e, f)
	if triggers[e] == nil then
		triggers[e] = {}
	end
	table.insert(triggers[e], f)
end

if playerClass == "WARRIOR" or playerClass == "ROGUE" then
	LibManaTicks
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

local batch = {
	spellCast = false,
	lostMana = false,
}

local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, e, ...)
	if e == "COMBAT_LOG_EVENT_UNFILTERED" then
		local a = {CombatLogGetCurrentEventInfo()}
		if a[2] == "SPELL_ENERGIZE" or a[2] == "SPELL_PERIODIC_ENERGIZE" then
			if a[8] == playerGUID and a[17] == 0 then -- a[17] is powerType
				energizeRejectUntil = GetTime() + batchWindow + batchError -- based on Life Tap test
			end
		elseif a[2] == "SPELL_LEECH" or a[2] == "SPELL_PERIODIC_LEECH" then
			if a[4] == playerGUID and a[16] == 0 then -- a[16] is powerType
				energizeRejectUntil = GetTime() + 3 * batchWindow + batchError -- based on Dark Pact test
			end
		elseif a[2] == "SPELL_CAST_SUCCESS" then
			if a[4] == playerGUID then
				batch.spellCast = true
			end
		end
	elseif e == "UNIT_POWER_UPDATE" then
		if ... ~= "player" then return end
		local manadiff = UpdateMana()
		if manadiff < 0 then batch.lostMana = true end
		if manadiff <= 0 then return end
		if GetTime() <= energizeRejectUntil then return end
		ManaTick(true)
	end
end)

f:SetScript("OnUpdate", function()
	local t = GetTime()
	if batch.spellCast and batch.lostMana then
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
f:RegisterEvent("UNIT_POWER_UPDATE")
