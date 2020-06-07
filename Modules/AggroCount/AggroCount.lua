
local bars
local Threat = LibStub("LibThreatClassic2")
local table_sort = _G.table.sort
local math_abs = _G.math.abs
local OL = LibStub("AceLocale-3.0"):GetLocale("Omen")
local L = LibStub("AceLocale-3.0"):GetLocale("Omen_AggroCount")
local GetTime = _G.GetTime
local select = _G.select
local unpack = _G.unpack

local AggroCount = Omen:NewModule("AggroCount", Omen.ModuleBase, "AceEvent-3.0", "AceTimer-3.0")
local currentTanks = {}
local tanks = {}

local configOptions = {
}
local options = {
	type = "group",
	name = L["Aggro Count Mode"],
	desc = L["Aggro Count Mode"],
	args = {
		test = {
			type = "execute",
			name = OL["Show test bars"],
			desc = OL["Show test bars"],
			func = function() Omen:EnableModule("AggroCount"); AggroCount:Test() end
		}
	}
}

local function sortBars(a, b)
	return a.value > b.value
end

function AggroCount:OnInitialize()
	self:Super("OnInitialize")
	self:RegisterConfigDefaults(configOptions)
	self:RegisterOptions(options)
	--self.icon = select(3, GetSpellInfo(3045))
	self.icon = select(3, GetSpellInfo(1130))
end

function AggroCount:OnEnable()
	self:Super("OnEnable")
	bars = self.bars
	self:ClearBars()
	Threat.RegisterCallback(self, "ThreatUpdated")
	Omen:SetTitle(L["Aggro Count Mode"] .. ": " .. UnitName("player"))
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function AggroCount:OnDisable()
	self:Super("OnDisable")
	Threat.UnregisterCallback(self, "ThreatUpdated")
end

local labelsNoIcons = {
	"Player", "LEFT", 60,
	"Count", "RIGHT", 10
}

local lastUpdateTime = 0
function AggroCount:UpdateBar(srcGuid, dstGuid, threat, overrideMax)
	-- Ignore if blacklisted
	if GuidBlacklist:Has(dstGuid) then
		self:RemoveTank(dstGuid)
		return
	end
	
	-- Ignore if creature guid is not resolvable
	if not Threat.GUIDNameLookup[dstGuid] or Threat.GUIDNameLookup[dstGuid] == "<unknown>" then
		return
	end
	
	-- If unit is in range and not in combat, but reporting a guid, then blacklist it
	if UnitInRange(Threat.GUIDNameLookup[srcGuid]) and not UnitAffectingCombat(Threat.GUIDNameLookup[srcGuid]) then
		GuidBlacklist:Add(dstGuid)
		self:RemoveTank(dstGuid)
		return
	end

	-- If threat comes from a creature we definitely know is not in the zone, ignore it.
	if string.sub(dstGuid, 1, 9) == "Creature-" then
		local pInstanceId, _ = select(8, GetInstanceInfo())
		local cInstanceId, _ = select(4, strsplit("-", dstGuid))
		if tonumber(pInstanceId) ~= tonumber(cInstanceId) then
			-- Creature initiating is not in the same instance as the player. Ignore
			return
		end
	end

	local maxThreat = overrideMax or Threat:GetMaxThreatOnTarget(dstGuid)
	-- In a crude way, just guess that whoever has max threat is tanking.
	if threat > 0 and threat >= maxThreat then
		if currentTanks[dstGuid] == srcGuid then
			return
		end
		self:RemoveTank(dstGuid)
		currentTanks[dstGuid] = srcGuid

		-- Add new tank
		local bar, isNew = self:AcquireBar(srcGuid)
		if isNew then
			tanks[srcGuid] = {}
			bar:SetLabels(unpack(labelsNoIcons))
			local pName = Threat.GUIDNameLookup[srcGuid]
			bar:SetLabel("Player", pName or "<unknown>")
			if pName then
				bar:SetClass(select(2, UnitClass(pName)))
			end
		end
		
		table.insert(tanks[srcGuid], dstGuid)
		bar.value = #tanks[srcGuid]
	else
		-- if threat is not max, just try to remove the tank
		if currentTanks[dstGuid] == srcGuid then
			self:RemoveTank(dstGuid)
		end
	end

	if GetTime() - lastUpdateTime > 0.1 then
		lastUpdateTime = GetTime()
		self:ArrangeBars()
	end
end

function AggroCount:RemoveTank(dstGuid)
	local currentTank = currentTanks[dstGuid]
	if currentTank then
		for i, v in ipairs(tanks[currentTank]) do
			if v == dstGuid then
				table.remove(tanks[currentTank], i)
				break
			end
		end	
		local bar, isNew = self:AcquireBar(currentTank, true)
		if bar then
			bar.value = #tanks[currentTank]
		end
		currentTanks[dstGuid] = nil
	end
end

function AggroCount:ArrangeBars()
	self:ResetBars()

	-- Clean up unused bars
	for i = #bars, 1, -1 do
		local bar = bars[i]
		if bar.value ~= bar.value or bar.value <= 0 then
			self:ReleaseBar(bar)
		end
	end
	
	-- Find max value
	local maxCount = 0
	for i = 1, #bars do
		local bar = bars[i]
		if bar.value > maxCount then
			maxCount = bar.value
		end
	end

	table_sort(bars, sortBars)
	local flag = true
	for i = 1, #bars do
		local bar = bars[i]
		if flag and self:AddBar(bar) then
			local pct = bar.value / maxCount
			bar:SetPercent(pct)
			bar:SetLabel("Count", bar.value)
		else
			flag = false
			bar.frame:Hide()
		end
	end
end

function AggroCount:ThreatUpdated(event, srcGUID, dstGUID, threat)
	if self.testing then
		self:ReleaseBars()
		self.testing = false
	end
	
	self:UpdateBar(srcGUID, dstGUID, threat)
end

function AggroCount:Test()
	self:ReleaseBars()
	self.testing = true

	local maxThreat = random() * 45 + 5
	for i = 1, 100 do
		local threat = random() * 100
		local temp = string.format("0x%02x", i)
		if i % 8 == 0 then
			self:UpdateBar(UnitGUID("player"), temp, threat, maxThreat)
		else
			self:UpdateBar(tostring(i % 8), temp, threat, maxThreat)
		end
	end
	self:ArrangeBars()
end

function AggroCount:PLAYER_REGEN_ENABLED()
	currentTanks = {}
	tanks = {}
	self:ReleaseBars()
end

function AggroCount:Hint()
	return L["Aggro Count Mode\n|cffffffffShows number of mobs aggroed per player|r"]
end

function AggroCount:UpdateLayout()
	self:ArrangeBars()
end

-- Permanently blacklist any creature that dies.
function AggroCount:COMBAT_LOG_EVENT_UNFILTERED()
	local _, event, _, _, _, _, _, guid, name = CombatLogGetCurrentEventInfo()
	if not string.sub(guid, 1, 9) == "Creature-" then
		return
	end
	if event == "UNIT_DIED" then
		GuidBlacklist:Add(guid)
		self:RemoveTank(guid)
	end
end
