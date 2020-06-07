
local bars
local Threat = LibStub("LibThreatClassic2")
local table_sort = _G.table.sort
local math_abs = _G.math.abs
local OL = LibStub("AceLocale-3.0"):GetLocale("Omen")
local L = LibStub("AceLocale-3.0"):GetLocale("Omen_Overview")
local GetTime = _G.GetTime
local select = _G.select
local unpack = _G.unpack

local Overview = Omen:NewModule("Overview", Omen.ModuleBase, "AceEvent-3.0", "AceTimer-3.0")
local raidTargets, raidTargetsReverse = {}, {}
local dstGuids = {}
local maxThreats = {}

local configOptions = {
	RaidIcons = true,
	ShowUnknown = false
}
local options = {
	type = "group",
	name = L["Overview Mode"],
	desc = L["Overview Mode"],
	args = {
		test = {
			type = "execute",
			name = OL["Show test bars"],
			desc = OL["Show test bars"],
			func = function() Omen:EnableModule("Overview"); Overview:Test() end
		},
		raidIcons = {
			type = "toggle",
			name = L["Show raid icons"],
			desc = L["Show raid icons"],
			get = function(info) return Overview:GetOption("RaidIcons") end,
			set = function(info, v)
				Overview:SetOption("RaidIcons", v)
				Overview:ReleaseBars()
			end
		},
		showUnknown = {
			type = "toggle",
			name = L["Show unknown creature threat"],
			desc = L["Show unknown creature threat"],
			get = function(info) return Overview:GetOption("ShowUnknown") end,
			set = function(info, v)
				Overview:SetOption("ShowUnknown", v)
			end
		}
	}
}

local function sortBars(a, b)
	return a.value > b.value
end

function Overview:OnInitialize()
	self:Super("OnInitialize")
	self:RegisterConfigDefaults(configOptions)
	self:RegisterOptions(options)
	self.icon = select(3, GetSpellInfo(18960))
end

function Overview:Hint()
	return L["Overview Mode\n|cffffffffShows an overview of high-threat raid members|r"]
end

function Overview:UpdateLayout()
	self:ArrangeBars()
end

function Overview:OnEnable()
	self:Super("OnEnable")
	bars = self.bars
	self:ClearBars()
	Threat.RegisterCallback(self, "ThreatUpdated")
	Omen:SetTitle(L["Overview Mode"] .. ": " .. UnitName("player"))
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("RAID_TARGET_UPDATE")
end

function Overview:OnDisable()
	self:Super("OnDisable")
	Threat.UnregisterCallback(self, "ThreatUpdated")
end

function Overview:RAID_TARGET_UPDATE()
	local numRaidMembers = GetNumGroupMembers()
	if numRaidMembers > 0 then
		for i=1, MAX_RAID_MEMBERS do
			if i > numRaidMembers then break end
			local unitId = "raid" .. i .. "target"
			if UnitExists(unitId) then
				local iconId = GetRaidTargetIndex(unitId)
				if iconId then
					if raidTargetsReverse[iconId] then
						raidTargets[raidTargetsReverse[iconId]] = nil
					end
					local unitGuid = UnitGUID(unitId)
					raidTargets[unitGuid] = iconId
					raidTargetsReverse[iconId] = unitGuid
				end
			end
		end
	end
end

function Overview.RaidTargetGUIDSet(lib, guid, name, target, unitID)
	if raidTargetsReverse[target] then
		raidTargets[raidTargetsReverse[target]] = nil
	end
	raidTargets[guid] = target
	raidTargetsReverse[target] = guid
end

local labelsWithIcons = {
	"Player", "LEFT", 27,
	"Icon", "LEFT", 6,
	"Enemy", "LEFT", 47,
	"%Max", "RIGHT", 20
}
local labelsNoIcons = {
	"Player", "LEFT", 30,
	"Enemy", "LEFT", 50,
	"%Max", "RIGHT", 20
}

local lastUpdateTime = 0
function Overview:UpdateBar(srcGuid, dstGuid, threat, overrideMax)
	-- Ignore if blacklisted
	if GuidBlacklist:Has(dstGuid) then
		return
	end
	
	-- Ignore if we do not show unknown and creature guid is not resolvable
	if not self:GetOption("ShowUnknown") and (not Threat.GUIDNameLookup[dstGuid] or Threat.GUIDNameLookup[dstGuid] == "<unknown>") then
		return
	end
	
	-- If unit is in range and not in combat, but reporting a guid, then blacklist it
	if UnitInRange(Threat.GUIDNameLookup[srcGuid]) and not UnitAffectingCombat(Threat.GUIDNameLookup[srcGuid]) then
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

	local bar, isNew = self:AcquireBar(srcGuid .. dstGuid)
	if isNew then
		if not dstGuids[dstGuid] then
			dstGuids[dstGuid] = {}
		end
		table.insert(dstGuids[dstGuid], srcGuid)
		bar:SetLabels( unpack(self:GetOption("RaidIcons") and labelsWithIcons or labelsNoIcons) )
		bar:SetLabel("Enemy", Threat.GUIDNameLookup[dstGuid])
		local pName= Threat.GUIDNameLookup[srcGuid]
		bar:SetLabel("Player", pName or "<unknown>")
		if pName then
			bar:SetClass(select(2, UnitClass(pName)))
		end
	end
	if raidTargets[dstGuid] then
		bar:SetLabel("Icon", raidTargets[dstGuid])
	elseif bar.hasIcon then
		bar:SetLabel("Icon", nil)
	end
	local maxThreat = Threat:GetMaxThreatOnTarget(dstGuid)
	if maxThreats[dstGuid] and maxThreat > maxThreats[dstGuid] then
		self:UpdateBarsForUnit(dstGuid)
	else
		local pct = threat / (overrideMax or maxThreat)
		bar.value = pct
	end
	maxThreats[dstGuid] = maxThreat
	if GetTime() - lastUpdateTime > 0.1 then
		lastUpdateTime = GetTime()
		self:ArrangeBars()
	end
end

function Overview:ArrangeBars()
	self:ResetBars()

	-- Clean up unused bars
	for i = #bars, 1, -1 do
		local bar = bars[i]
		if bar.value ~= bar.value or bar.value <= 0 then
			self:ReleaseBar(bar)
		end
	end

	table_sort(bars, sortBars)
	local flag = true
	for i = 1, #bars do
		local bar = bars[i]
		if flag and self:AddBar(bar) then
			local pct = bar.value
			bar:SetPercent(pct)
			bar:SetLabel("%Max", ("%.0f%%"):format(pct*100))
		else
			flag = false
			bar.frame:Hide()
		end
	end
end

function Overview:ThreatUpdated(event, srcGUID, dstGUID, threat)
	if self.testing then
		self:ReleaseBars()
		self.testing = false
	end

	self:UpdateBar(srcGUID, dstGUID, threat)
end

function Overview:Test()
	self:ReleaseBars()
	self.testing = true

	local pGUID = UnitGUID("player")
	for i = 1, 25 do
		raidTargets[i] = mod(i,8) + 1
		local temp = string.format("0x%02x", i)
		if random() > 0.8 then
			self:UpdateBar(pGUID, temp, i, 25)
		else
			self:UpdateBar(temp, temp, i, 25)
		end
	end
	self:ArrangeBars()
end

function Overview:PLAYER_REGEN_ENABLED()
	self:ReleaseBars()
end

function Overview:UpdateBarsForUnit(guid)
	if not dstGuids[guid] then
		return
	end
	local maxThreat = Threat:GetMaxThreatOnTarget(guid)
	for _, v in ipairs(dstGuids[guid]) do
		local bar = self:AcquireBar(v .. guid, true)
		if bar then
			bar.value = (Threat:GetThreat(v, guid) or 0) / (overrideMax or maxThreat)
		end
	end
end

function Overview:WipeBarsForUnit(guid)
	if not dstGuids[guid] then
		return
	end
	for _, v in ipairs(dstGuids[guid]) do
		local bar = self:AcquireBar(v .. guid, true)
		if bar then
			bar.value = 0
		end
	end
	dstGuids[guid] = nil
	self:ArrangeBars()
end

-- Permanently blacklist any creature that dies. Unless it is resurrected, then whitelist it. Although I have no idea how/if that works.
function Overview:COMBAT_LOG_EVENT_UNFILTERED()
	local _, event, _, _, _, _, _, guid, name = CombatLogGetCurrentEventInfo()
	if not string.sub(guid, 1, 9) == "Creature-" then
		return
	end
	if event == "UNIT_DIED" then
		GuidBlacklist:Add(guid)
		self:WipeBarsForUnit(guid)
	elseif event == "SPELL_RESURRECT" then
		GuidBlacklist:Rem(guid)
	end
end
