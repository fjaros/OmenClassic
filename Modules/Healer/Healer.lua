
local columns = {}
local Threat = LibStub("LibThreatClassic2")
local table_sort = _G.table.sort
local math_abs = _G.math.abs
local OL = LibStub("AceLocale-3.0"):GetLocale("Omen")
local L = LibStub("AceLocale-3.0"):GetLocale("Omen_Healer")
local GetTime = _G.GetTime
local pairs, select = _G.pairs, _G.select
local tremove, tinsert = _G.tremove, _G.tinsert

local Healer = Omen:NewModule("Healer", Omen.ModuleBase, "AceEvent-3.0", "AceTimer-3.0")
local tankGuids = {}

local configOptions = {
	Column = {
		Spacing = 4
	}
}

local options = {
	type = "group",
	name = L["Healer Mode"],
	desc = L["Healer Mode"],
	args = {
		test = {
			type = "execute",
			name = OL["Show test bars"],
			desc = OL["Show test bars"],
			func = function() Omen:EnableModule("Healer") Healer:Test() end
		},
		spacing = {
			type = "range",
			name = L["Column Spacing"],
			desc = L["Column Spacing"],
			min = 0,
			max = 25,
			step = 1,
			bigStep = 1,
			get = function(info) return Healer:GetOption("Column.Spacing") end,
			set = function(info, v)
				Healer:SetOption("Column.Spacing", v)
				Healer:SetColumnSpacing(v)
				Omen:UpdateDisplay()
			end
		}
	}
}

local tankPositions, tankGUIDs = {}, {}
	
local function sortBars(a, b)
	if a.isTitle then return true end
	if b.isTitle then return false end
	return a.value > b.value
end

function Healer:OnInitialize()
	self:Super("OnInitialize")
	self.icon = select(3, GetSpellInfo(71))
	self:RegisterConfigDefaults(configOptions)
	self:RegisterOptions(options)
	self:SetColumnSpacing(self:GetOption("Column.Spacing"))
end

function Healer:Hint()
	return L["Healer Mode\n|cffffffffShows an overview of threat for mobs tagged by Main Tank roles|r"]
end

function Healer:UpdateLayout()
	self:ArrangeBars()
end

function Healer:OnEnable()
	self:Super("OnEnable")
	Threat.RegisterCallback(self, "ThreatUpdated")
	Omen:SetTitle(L["Healer Mode"] .. ": " .. UnitName("player"))
	self:ClearBars()
	self:ClearColumns()
	self:RegisterEvent("UNIT_TARGET")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:WatchBlizzard()
end

function Healer:OnDisable()
	self:Super("OnDisable")
	Threat.UnregisterCallback(self, "ThreatUpdated")
end

function Healer:ClearColumns()
	for k, v in pairs(columns) do
		for k2, v2 in pairs(v) do
			v[k2] = nil
		end
	end
end

local lastUpdateTime = 0
function Healer:UpdateBar(srcGUID, tankGUID, dstGUID, threat, column, overrideMax)
	-- Ignore if blacklisted
	if GuidBlacklist:Has(dstGUID) then
		return
	end
	
	-- Ignore if creature guid is not resolvable
	if not Threat.GUIDNameLookup[dstGuid] or Threat.GUIDNameLookup[dstGuid] == "<unknown>" then
		return
	end
	
	-- If unit is in range and not in combat, but reporting a guid, then blacklist it
	if UnitInRange(Threat.GUIDNameLookup[srcGUID]) and not UnitAffectingCombat(Threat.GUIDNameLookup[srcGUID]) then
		GuidBlacklist:Add(dstGUID)
		self:RemoveTank(dstGUID)
		return
	end

	-- If threat comes from a creature we definitely know is not in the zone, ignore it.
	if string.sub(dstGUID, 1, 9) == "Creature-" then
		local pInstanceId, _ = select(8, GetInstanceInfo())
		local cInstanceId, _ = select(4, strsplit("-", dstGUID))
		if tonumber(pInstanceId) ~= tonumber(cInstanceId) then
			-- Creature initiating is not in the same instance as the player. Ignore
			return
		end
	end

	local bar, isNew = self:AcquireBar(srcGUID .. "-" .. tankGUID)
	columns[column] = columns[column] or {}

	if isNew then
		bar:SetLabels(
			"Name", "LEFT", 70,
			"%Max", "RIGHT", 30
		)
		local pName= Threat.GUIDNameLookup[srcGUID]
		bar:SetLabel("Name", pName or "<unknown>")
		if pName then
			bar:SetClass(select(2, UnitClass(pName)))
		end
		tinsert(columns[column], bar)
	end
	local tankThreat = Threat:GetThreat(tankGUID, dstGUID)
	local pct
	if tankThreat then
		pct = threat / (overrideMax or tankThreat)
	else
		pct = 0
	end

	bar.value = pct
	if GetTime() - lastUpdateTime > 0.1 then
		lastUpdateTime = GetTime()
		self:ArrangeBars()
	end
end

function Healer:SetColumnHeader(column, header)
	local bar, isNew = self:AcquireBar("HealerColumn" .. column)
	columns[column] = columns[column] or {}
	if isNew then
		bar:SetLabels(
			"Name", "CENTER", 100
		)	
		bar:SetColor(0,0,0,0)
		bar.isTitle = true
		bar.value = 0
		tinsert(columns[column], bar)
	end
	bar:SetLabel("Name", header)
	self:ArrangeBars()
end

function Healer:ArrangeBars()
	for k = 1, #columns do
		self:ArrangeColumn(k)
	end
end

function Healer:ArrangeColumn(col)
	local v = columns[col]
	self:ResetBars(col)

	-- Clean up unused bars
	for i = #v, 1, -1 do
		local bar = v[i]
		if (bar.value ~= bar.value or bar.value <= 0) and not bar.isTitle then
			tremove(v, i)
			self:ReleaseBar(bar)
		end
	end

	table_sort(v, sortBars)
	local flag = true
	for i = 1, #v do
		local bar = v[i]
		if flag and self:AddBar(bar, col) then
			if not bar.isTitle then
				local pct = bar.value
				bar:SetPercent(pct)
				bar:SetLabel("%Max", ("%.0f%%"):format(pct*100))
			end
		else
			flag = false
			bar.frame:Hide()
		end
	end
end

function Healer:ThreatUpdated(event, srcGUID, dstGUID, threat)
	if self.testing then
		self:ReleaseBars()
		self.testing = false
		self:GetBlizzardTanks()
	end
	for k, v in pairs(tankPositions) do
		if dstGUID == UnitGUID(tankGUIDs[k] .. "-target") then
			self:UpdateBar(srcGUID, k, dstGUID, threat, v)
		end
	end
end

function Healer:UpdateThreatOnTank(unit)
	local tankGUID = UnitGUID(unit)
	local pos = tankPositions[tankGUID]
	if not pos then return end
	
	self:SetColumnHeader(pos, UnitName(unit .. "-target") or "<none>")
	
	if not columns[pos] then return end
	
	for k, v in pairs(columns[pos]) do
		v.value = 0
	end
	
	local dstGUID = UnitGUID(unit .. "-target")
	if dstGUID then
		for k, v in Threat:IterateGroupThreatForTarget(dstGUID) do
			self:UpdateBar(k, tankGUID, dstGUID, v, pos)
		end
	end
	self:ArrangeColumn(pos)
end

function Healer:AddTank(unitID)
	local ct = 0
	for k, v in pairs(tankPositions) do
		ct = ct + 1
	end
	local uid = UnitGUID(unitID)
	if not uid then return end
	-- if not tankPositions[uid] then
		tankPositions[uid] = ct + 1
	-- end
	tankGUIDs[uid] = unitID
	self:SetNumColumns(ct + 1)
	self:ClearColumns()
	self:UNIT_TARGET(nil, unitID)
	self:UpdateThreatOnTank(unitID)
	self:ArrangeBars()
end

function Healer:RemoveTank(unitID)
	local uid = UnitGUID(unitID)
	tankGUIDs[uid] = nil
	tankPositions[uid] = nil
	local ct = 0
	for k, v in pairs(tankGUIDs) do
		ct = ct + 1
	end
	self:SetNumColumns(ct)
	self:ClearColumns()
	self:ArrangeBars()
	
	-- TODO: Refresh display
end

function Healer:ClearTanks()
	for k, v in pairs(tankGUIDs) do
		tankGUIDs[k] = nil
		tankPositions[k] = nil
	end
	self:SetNumColumns(1)
	self:ClearColumns()
	self:ArrangeBars()
end

function Healer:Test()
	self.testing = true
	self:ReleaseBars()
	self:ClearColumns()
	self:SetNumColumns(4)
	local pGUID = UnitGUID("player")
	for j = 1, 4 do
		for i = 1, math.random(10) do
			local temp = string.format("0x%02x", i)
			local temp2 = string.format("0x%02x", j)
			if i == 5 then
				self:UpdateBar(pGUID, temp2, temp, i, j, 11)
			else
				self:UpdateBar(temp, temp2, temp, i, j, 11)
			end
		end
	end
	self:ArrangeBars()
end

function Healer:UNIT_TARGET(event, unit)
	if self.testing then
		self:ReleaseBars()
		self.testing = false
		self:GetBlizzardTanks()
	end
	if tankPositions[UnitGUID(unit)] then
		self:UpdateThreatOnTank(unit)
	end
end

function Healer:WatchBlizzard()
	self:RegisterEvent("RAID_ROSTER_UPDATE")
	self:GetBlizzardTanks()
end

function Healer:RAID_ROSTER_UPDATE()
	self:GetBlizzardTanks()
end

-- Permanently blacklist any creature that dies. Unless it is resurrected, then whitelist it. Although I have no idea how/if that works.
function Healer:COMBAT_LOG_EVENT_UNFILTERED()
	local _, event, _, _, _, _, _, guid, name = CombatLogGetCurrentEventInfo()
	if not string.sub(guid, 1, 9) == "Creature-" then
		return
	end
	if event == "UNIT_DIED" then
		GuidBlacklist:Add(guid)
	elseif event == "SPELL_RESURRECT" then
		GuidBlacklist:Rem(guid)
	end
end

function Healer:GetBlizzardTanks()
	self:ClearTanks()
	local numRaidMembers = GetNumGroupMembers()
	local cols = 0
	
	if numRaidMembers > 0 then
		for i=1, MAX_RAID_MEMBERS do
			if i > numRaidMembers then break end
			local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, loot = GetRaidRosterInfo(i)
			if role == "MAINTANK" then
				self:AddTank(name)
				cols = cols + 1
			end
		end
	end
	self:SetNumColumns(cols)
end
