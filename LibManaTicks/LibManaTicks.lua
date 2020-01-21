
if LibManaTicks ~= nil then return end
local _, playerClass = UnitClass("player")
if playerClass == "WARRIOR" or playerClass == "ROGUE" then return end
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
		local _, a, _, sourceGUID, _, _, _, targetGUID = CombatLogGetCurrentEventInfo()
		if a == "SPELL_ENERGIZE" and targetGUID == playerGUID then
			energizeRejectUntil = GetTime() + batchWindow + batchError
		elseif a == "SPELL_LEECH" and sourceGUID == playerGUID then
			energizeRejectUntil = GetTime() + 3 * batchWindow + batchError
		elseif a == "SPELL_CAST_SUCCESS" and sourceGUID == playerGUID then
			batch.spellCast = true
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
