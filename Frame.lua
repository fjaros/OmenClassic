
local L = LibStub("AceLocale-3.0"):GetLocale("Omen")
local module_icons = {}
local Threat = LibStub("LibThreatClassic2")
local math_abs = math.abs
local Media = LibStub("LibSharedMedia-3.0")

local table_sort = _G.table.sort

local module_order = {
	SingleTarget = 1,
	Overview = 2,
	AOE = 3,
	Healer = 4,
	AggroCount = 5
}

local sizing = function()
	if Omen.activeModule then Omen.activeModule:UpdateLayout() end
	Omen:ResizeBars()
end

function Omen:CreateFrame()
	self.Anchor = CreateFrame("Frame", "OmenAnchor", UIParent)
	self.Anchor:SetResizable(true)
	self.Anchor:SetMinResize(90, 120)
	self.Anchor:SetMovable(true)
	self.Anchor:SetPoint("CENTER", UIParent, "CENTER")
	self.Anchor:SetWidth(225)
	self.Anchor:SetHeight(150)
	self.Anchor:SetScript("OnSizeChanged", nil)
	
	------------------------------------------------------------------
	-- Title
	------------------------------------------------------------------
	self.Title = CreateFrame("Frame", "OmenTitle", self.Anchor)
	self.Title:SetPoint("TOPLEFT", self.Anchor, "TOPLEFT")
	self.Title:SetPoint("TOPRIGHT", self.Anchor, "TOPRIGHT")
	self.Title:SetHeight(self.Options["Skin.Title.Height"])
	self.Title:EnableMouse(true)
	
	self.TitleText = self.Title:CreateFontString(nil, nil, "GameFontNormal")
	self.TitleText:SetPoint("LEFT", self.Title, "LEFT", 10, 0)
	self.defaultTitle = "Omen |cffffcc00Classic|r"
	self:SetTitle()
	-- self:ScheduleRepeatingTimer("SetTitleInternal", 10)
	self.TitleText:SetJustifyH("LEFT")
	self.TitleText:SetTextColor(1,1,1,0.95)

	self.VersionText = self.Title:CreateFontString(nil, nil, "GameFontNormal")
	self.VersionText:SetPoint("TOPRIGHT", self.Title, "TOPRIGHT", -6, -4)
	self.VersionText:SetText(("r|cffffffff%s|r"):format(Omen.LTC_MINOR))
	local f, s, p = self.VersionText:GetFont()
	self.VersionText:SetFont(f, 8, p)

	self.OutOfDateText = self.Title:CreateFontString(nil, nil, "GameFontNormal")
	self.OutOfDateText:SetPoint("TOPRIGHT", self.VersionText, "BOTTOMRIGHT", 0, 0)
	self.OutOfDateText:SetText("")
	
	local f, s, p = self.VersionText:GetFont()
	self.OutOfDateText:SetFont(f, 8, p)
	
	self.TitleText:SetPoint("RIGHT", self.VersionText, "LEFT", -5, 0)
	
	self.Title:SetScript("OnMouseDown", function() if not Omen.Options["Lock"] then Omen.Anchor:StartMoving(); end end)
	self.Title:SetScript("OnMouseUp", function()
		Omen.Anchor:StopMovingOrSizing();		
		Omen:SetAnchors()
	end)
	Omen:InjectFrameOptions("Title", Omen.configOptions.args.display.args.title)
	
	------------------------------------------------------------------
	-- BarList
	------------------------------------------------------------------
	self.ModuleList = CreateFrame("Frame", "OmenModuleButtons", self.Anchor)
	self.ModuleList:SetHeight(self.Options["Skin.Modules.Height"])
	self.ModuleList:SetPoint("BOTTOMLEFT", self.Anchor, "BOTTOMLEFT")
	self.ModuleList:SetPoint("BOTTOMRIGHT", self.Anchor, "BOTTOMRIGHT")
	local configButton = CreateFrame("Button", nil, self.ModuleList)
	configButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Wrench_01")
	configButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	configButton:SetScript("OnClick", Omen.ShowConfig)
	configButton:SetPoint("RIGHT", self.ModuleList, "RIGHT", -7, 0)
	configButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:AddLine(L["Configure Omen"])
		GameTooltip:Show()
	end)
	configButton:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
	
	configButton:SetWidth(self.ModuleList:GetHeight() - 12)
	configButton:SetHeight(self.ModuleList:GetHeight() - 12)
	
	self.ModuleList.Config = configButton
	
	
	Omen:InjectFrameOptions("ModuleList", Omen.configOptions.args.display.args.moduleList)
	
	------------------------------------------------------------------
	-- BarList
	------------------------------------------------------------------
	self.BarList = CreateFrame("Frame", "OmenBarList", self.Anchor)
	self.BarList:SetResizable(true)
	self.BarList:EnableMouse(true)
	self.BarList:SetPoint("TOPLEFT", self.Title, "BOTTOMLEFT")
	self.BarList:SetPoint("TOPRIGHT", self.Title, "BOTTOMRIGHT")
	self.BarList:SetPoint("BOTTOMLEFT", self.ModuleList, "TOPLEFT")
	self.BarList:SetPoint("BOTTOMRIGHT", self.ModuleList, "TOPRIGHT")
	self.BarList:SetScript("OnMouseDown", function() if not Omen.Options["Lock"] then Omen.Anchor:StartMoving(); end end)
	self.BarList:SetScript("OnMouseUp", function()
		Omen.Anchor:StopMovingOrSizing();		
		Omen:SetAnchors()
	end)
	
	Omen:InjectFrameOptions("BarList", Omen.configOptions.args.display.args.barList)
	
	Omen:InjectFrameOptions("Frames", Omen.configOptions.args.display.args.defaults)
	
	------------------------------------------------------------------
	-- Grip
	------------------------------------------------------------------
	local grip = CreateFrame("Button", "OmenResizeGrip", self.BarList)
	grip:SetNormalTexture("Interface\\AddOns\\Omen\\ResizeGrip")
	grip:SetHighlightTexture("Interface\\AddOns\\Omen\\ResizeGrip")
	grip:SetWidth(16)
	grip:SetHeight(16)
	grip:SetScript("OnMouseDown", function()
		if not Omen.db.profile.Locked then
			Omen.Anchor.IsMovingOrSizing = true
			Omen.Anchor:SetScript("OnSizeChanged", sizing)
			Omen.Anchor:StartSizing()
		end
	end)
	grip:SetScript("OnMouseUp", function()
		Omen.Anchor:SetScript("OnSizeChanged", nil)
		Omen.Anchor:StopMovingOrSizing()
		Omen:SetAnchors()
		sizing()
		Omen.Anchor.IsMovingOrSizing = nil
	end)
	grip:SetPoint("BOTTOMRIGHT", self.BarList, "BOTTOMRIGHT", 0, 1)
	self.Grip = grip
	self:UpdateVisible()	
	self:UpdateDisplay()
	
	Threat.RegisterCallback(self, "OutOfDateNotice", "SetOutOfDate")
end

function Omen:SetAnchors(useDB)
	local t = Omen.Options["Skin.Bars.GrowUp"]
	local x, y, w, h

	-- Set the scale, since the scaling affects the position
	self.Anchor:SetScale(Omen.Options["Skin.Scale"] / 100.0)

	-- Get position
	if useDB then
		x, y = self.db.profile.PositionX, self.db.profile.PositionY
		if not x and not y then
			Omen.Anchor:ClearAllPoints()
			Omen.Anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			if t then
				x, y = self.Anchor:GetLeft(), self.Anchor:GetBottom()
			else
				x, y = self.Anchor:GetLeft(), self.Anchor:GetTop()
			end
		end
	elseif t then
		x, y = self.Anchor:GetLeft(), self.Anchor:GetBottom()
	else
		x, y = self.Anchor:GetLeft(), self.Anchor:GetTop()
	end

	-- Get width/height
	if useDB then
		w = self.db.profile.PositionW or Omen.Anchor:GetWidth()
		h = self.db.profile.PositionH or Omen.Anchor:GetHeight()
	else
		w, h = Omen.Anchor:GetWidth(), Omen.Anchor:GetHeight()
	end

	-- Set the anchors and size
	Omen.Anchor:ClearAllPoints()
	if t then
		Omen.Anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
	else
		Omen.Anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	end
	Omen.Anchor:SetWidth(w)
	Omen.Anchor:SetHeight(h)

	-- Save the data
	self.db.profile.PositionX, self.db.profile.PositionY = x, y
	self.db.profile.PositionW, self.db.profile.PositionH = w, h
end

function Omen:SetTitle(t)
	self.currentTitle = t and strlen(t) > 0 and t or self.defaultTitle
	-- self:SetTitleInternal()
	self.TitleText:SetText(self.currentTitle)
end

local lastUsageUpdate = 0
function Omen:SetTitleInternal()
	-- self.TitleText:SetText(("%s"):format(self.currentTitle, GetAddOnMemoryUsage("Omen")))
	if GetTime() - lastUsageUpdate > 8 then
		UpdateAddOnMemoryUsage()
		lastUsageUpdate = GetTime()
	end
	local a, b = Threat:TableStats()
	self.TitleText:SetText(("%s [%2.1fkb, %2.1fkb, %s/%s t used/alloc]"):format(self.currentTitle, GetAddOnMemoryUsage("Omen"), GetAddOnMemoryUsage("Threat-2.0"), a, b))
end

local frames = {"BarList", "Title", "ModuleList"}

local bgFrame = {
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4}
}

function Omen:_SetFrameBackdrop(frame, optionPrefix)
	frame:SetAlpha(self.Options["Skin.".. optionPrefix .. ".Opacity"] or self.Options["Skin.Frames.Opacity"])
	
	bgFrame.bgFile = Media:Fetch("background", self.Options["Skin." .. optionPrefix .. ".Background.Texture"] or self.Options["Skin.Frames.Background.Texture"])
	bgFrame.edgeFile = Media:Fetch("border", self.Options["Skin." .. optionPrefix .. ".Border.Texture"] or self.Options["Skin.Frames.Border.Texture"])
	frame:SetBackdrop(bgFrame)
	
	local c = self.Options["Skin." .. optionPrefix .. ".Background.Color"] or self.Options["Skin.Frames.Background.Color"]
	frame:SetBackdropColor(c.r, c.g, c.b, c.a)
	local c = self.Options["Skin." .. optionPrefix .. ".Border.Color"] or self.Options["Skin.Frames.Border.Color"]
	frame:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
end

function Omen:UpdateDisplay()
	-- UpdateDisplay() is the SML registration callback. make sure we're set up before attempting to do anything
	if not self.Anchor then return end

	self.Anchor:SetScale(Omen.Options["Skin.Scale"] / 100.0)
	
	for _, f in pairs(frames) do
		self:_SetFrameBackdrop(self[f], f)
	end

	local clamp = self.Options["Skin.Clamp"]
	self.BarList:SetClampedToScreen(clamp)
	self.BarList:Show()

	-- Title
	if self.Options["Skin.Title.Hide"] then
		self.Title:Hide()
		self.Title:SetClampedToScreen(false)
	else
		self.Title:SetHeight(self.Options["Skin.Title.Height"])
		self.Title:SetClampedToScreen(clamp)
		if self.Options["Skin.Title.HideVersion"] then
			self.VersionText:Hide()
		else
			self.VersionText:Show()
		end
		local p, s, v = self.TitleText:GetFont()
		self.TitleText:SetFont(Media:Fetch("font", Omen.Options["Skin.Title.Font"]), s, v)
		self.Title:Show()
	end
	
	if self.Options["Skin.Modules.Hide"] then
		self.ModuleList:Hide()
		self.ModuleList:SetClampedToScreen(false)
	else
		self.ModuleList:Show()
		self.ModuleList:SetClampedToScreen(clamp)
	end

	self:UpdateBarLayouts()
	
	if self.Options["Lock"] then
		self.Grip:Hide()
	else
		self.Grip:Show()
	end
	
	if self.activeModule then self.activeModule:UpdateLayout() end
	self:ResizeBars()
end

function Omen:LayoutModuleIcons()
	local anchor, anchorPoint, offset = self.ModuleList, "LEFT", 6
	self.ModuleList:SetHeight(Omen.Options["Skin.Modules.Height"])
	
	local sortedModules = {}
	for k, v in self:IterateModules() do
		table.insert(sortedModules, {k, v})
	end
	table.sort(sortedModules, function(a, b) return module_order[a[1]] and module_order[b[1]] and module_order[a[1]] < module_order[b[1]] end)
	
	for _, element in ipairs(sortedModules) do
		local k = element[1]
		local v = element[2]
		local icon = module_icons[k]
		if not icon then
			icon = CreateFrame("Button", nil, self.ModuleList)
			module_icons[k] = icon
		end
		icon:SetWidth(self.ModuleList:GetHeight() - 12)
		icon:SetHeight(self.ModuleList:GetHeight() - 12)
		icon:SetNormalTexture(v.icon)
		icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		icon.module = v
		v.button = icon
		icon:SetScript("OnClick", function(self)
			self.module:Enable()
		end)
		icon:SetScript("OnEnter", function(self)
			GameTooltip:ClearLines();
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:AddLine(self.module:Hint())
			GameTooltip:Show()
		end)
		icon:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		icon:GetNormalTexture():SetDesaturated(not v:IsEnabled())
		
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", anchor, anchorPoint, offset, 0)
		anchor, anchorPoint, offset = icon, "RIGHT", 4
	end
	self.ModuleList.Config:SetWidth(self.ModuleList:GetHeight() - 12)
	self.ModuleList.Config:SetHeight(self.ModuleList:GetHeight() - 12)
end

function Omen:UpdateVisible()
	if self.Options["Standby"] then
		self.Anchor:Hide()
		return
	end
	local inInstance, instanceType = IsInInstance()
	local show
	if (not Omen.Options["ShowWith.Resting"] and IsResting()) then
		show = false
	end
	if (not Omen.Options["ShowWith.PVP"] and inInstance and (instanceType == "pvp" or instanceType == "arena")) then
		show = false
	end
	if (not Omen.Options["ShowWith.Dungeon"] and inInstance and (instanceType == "party" or instanceType == "raid")) then
		show = false
	end
	if show == nil then
		show =	(Omen.Options["ShowWith.Pet"] and UnitExists("pet")) or
				(Omen.Options["ShowWith.Alone"] and GetNumGroupMembers() == 0 and not UnitExists("pet")) or
				(Omen.Options["ShowWith.Party"] and not IsInRaid() and GetNumGroupMembers() > 0) or
				(Omen.Options["ShowWith.Raid"] and IsInRaid() and GetNumGroupMembers() > 0)
	end
	if self.Options["ShowWith.Alone"] then
		Threat:RequestActiveOnSolo(true)
	end
	if show and not Omen.Options["HardOff"] then
		self.Anchor:Show()
	else
		self.Anchor:Hide()
	end
end

function Omen:SetOutOfDate(callback, minor, revision, sender, incompatible)
	self.OutOfDateText:SetFormattedText("|cffff0000new!|r r|cffffffff%s|r%s", revision, incompatible and " |cffff0000incompatible!|r" or "")
end
