
if LibManaTicks ~= nil then return end
local blockedClasses = {
	["WARRIOR"] = true,
	["ROGUE"] = true,
}
if blockedClasses[select(2, UnitClass("player"))] then return end

local batchWindow = 0.5 -- seconds, must include padding for batch timing error
local tickInterval = 2.03 -- seconds, mana tick interval
local spellcastBlockLength = 5 -- seconds, time until ticks are allowed after spellcast

local energizeRejectUntil = 0
local castBlockUntil = 0
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

function TriggerEvent(e)
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

local function IsRegenBlocked()
	local t = GetTime()
	return t < energizeRejectUntil or t < castBlockUntil
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
