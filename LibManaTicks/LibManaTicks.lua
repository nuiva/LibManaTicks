
if LibManaTicks ~= nil then return end
local _, playerClass = UnitClass("player")
local playerGUID = UnitGUID("player")

local batchWindow = 0.4053 -- seconds, spell batch length
local batchError = 0.1 -- seconds, error tolerance for batch delays
local tickInterval = 5 * batchWindow -- seconds, mana tick interval

local energizeRejectUntil = 0
local healRejectUntil = 0
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

local batch = {
	spellCast = false,
	lostMana = false,
}

local playerPower = {}
local function UpdatePower(powerType)
	local power = UnitPower("player", powerType)
	local diff = power - (playerPower[powerType] or power)
	playerPower[powerType] = power
	if diff < 0 and powerType == 0 then
		batch.lostMana = true
	end
	return diff > 0
end
local function UpdateHealth()
	local health = UnitHealth("player")
	local diff = health - (playerPower["hp"] or health)
	playerPower["hp"] = health
	return diff > 0
end

local function ManaTick(isReal)
	TriggerEvent("ManaTickAlways")
	if isReal then TriggerEvent("ManaTick") end
	predictedTick = GetTime() + tickInterval
end

local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, e, ...)
	if e == "COMBAT_LOG_EVENT_UNFILTERED" then
		local a = {CombatLogGetCurrentEventInfo()}
		if a[2] == "SPELL_ENERGIZE" or a[2] == "SPELL_PERIODIC_ENERGIZE" then
			if a[8] == playerGUID --[[and a[17] == 0]] then -- a[17] is powerType
				energizeRejectUntil = GetTime() + batchWindow + batchError -- based on Life Tap test
			end
		elseif a[2] == "SPELL_LEECH" or a[2] == "SPELL_PERIODIC_LEECH" then
			if a[4] == playerGUID --[[and a[16] == 0]] then -- a[16] is powerType
				energizeRejectUntil = GetTime() + 3 * batchWindow + batchError -- based on Dark Pact test
			end
		elseif a[2] == "SPELL_CAST_SUCCESS" then
			if a[4] == playerGUID then
				batch.spellCast = true
			end
		elseif a[2] == "SPELL_HEAL" or a[2] == "SPELL_PERIODIC_HEAL" then
			if a[8] == playerGUID then
				healRejectUntil = GetTime() + batchWindow + batchError
			end
		end
	elseif e == "UNIT_POWER_UPDATE" then
		if ... ~= "player" then return end
		local gainedPower = UpdatePower(0) or UpdatePower(3)
		if not gainedPower or GetTime() <= energizeRejectUntil then return end
		ManaTick(true)
	elseif e == "UNIT_HEALTH_FREQUENT" then
		if ... ~= "player" then return end
		local gainedHealth = UpdateHealth()
		if not gainedHealth or GetTime() <= healRejectUntil then return end
		ManaTick(false)
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
f:RegisterEvent("UNIT_HEALTH_FREQUENT")
