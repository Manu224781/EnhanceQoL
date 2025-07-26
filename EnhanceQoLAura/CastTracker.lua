local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Aura = addon.Aura or {}
addon.Aura.CastTracker = addon.Aura.CastTracker or {}
local CastTracker = addon.Aura.CastTracker
CastTracker.functions = CastTracker.functions or {}
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")
local AceGUI = addon.AceGUI

local anchors = {}
local ensureAnchor
local framePools = {}
local activeBars = {}
local activeOrder = {}
local selectedCategory = addon.db["castTrackerSelectedCategory"] or 1

local function UpdateActiveBars(catId)
	local cat = addon.db.castTrackerCategories and addon.db.castTrackerCategories[catId] or {}
	local anchor = ensureAnchor(catId)
	if anchor then anchor:SetSize(cat.width or 200, cat.height or 20) end
	for _, bar in pairs(activeBars[catId] or {}) do
		bar.status:SetStatusBarColor(unpack(cat.color or { 1, 0.5, 0, 1 }))
		bar.icon:SetSize(cat.height or 20, cat.height or 20)
		bar:SetSize(cat.width or 200, cat.height or 20)
	end
	CastTracker.functions.LayoutBars(catId)
end

ensureAnchor = function(id)
	if anchors[id] then return anchors[id] end

	local cat = addon.db.castTrackerCategories[id]
	if not cat then return nil end

	local anchor = CreateFrame("Frame", "EQOLCastTrackerAnchor" .. id, UIParent, "BackdropTemplate")
	anchor:SetSize(cat.width or 200, cat.height or 20)
	anchor:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
	anchor:SetBackdropColor(0, 0, 0, 0.6)
	anchor:SetMovable(true)
	anchor:EnableMouse(true)
	anchor:RegisterForDrag("LeftButton")

	anchor.text = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	anchor.text:SetPoint("CENTER", anchor, "CENTER")
	anchor.text:SetText(L["DragToPosition"]:format("|cffffd700" .. (cat.name or "") .. "|r"))

	anchor:SetScript("OnDragStart", anchor.StartMoving)
	anchor:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, xOfs, yOfs = self:GetPoint()
		cat.anchor.point = point
		cat.anchor.x = xOfs
		cat.anchor.y = yOfs
	end)

	anchor:SetScript("OnShow", function()
		if cat.anchor then
			anchor:ClearAllPoints()
			anchor:SetPoint(cat.anchor.point, UIParent, cat.anchor.point, cat.anchor.x, cat.anchor.y)
		end
	end)

	if cat.anchor then
		anchor:ClearAllPoints()
		anchor:SetPoint(cat.anchor.point, UIParent, cat.anchor.point, cat.anchor.x, cat.anchor.y)
	end

	anchors[id] = anchor
	return anchor
end

local function applyLockState()
	for id, anchor in pairs(anchors) do
		local cat = addon.db.castTrackerCategories[id]
		if not addon.db.castTrackerEnabled[id] then
			anchor:Hide()
		elseif addon.db.castTrackerLocked[id] then
			anchor:RegisterForDrag()
			anchor:SetMovable(false)
			anchor:EnableMouse(false)
			anchor:SetScript("OnDragStart", nil)
			anchor:SetScript("OnDragStop", nil)
			anchor:SetBackdropColor(0, 0, 0, 0)
			if anchor.text then anchor.text:Hide() end
			anchor:Show()
		else
			anchor:RegisterForDrag("LeftButton")
			anchor:SetMovable(true)
			anchor:EnableMouse(true)
			anchor:SetScript("OnDragStart", anchor.StartMoving)
			anchor:SetScript("OnDragStop", function(self)
				self:StopMovingOrSizing()
				local point, _, _, xOfs, yOfs = self:GetPoint()
				cat.anchor.point = point
				cat.anchor.x = xOfs
				cat.anchor.y = yOfs
			end)
			anchor:SetBackdropColor(0, 0, 0, 0.6)
			if anchor.text then
				anchor.text:SetText(L["DragToPosition"]:format("|cffffd700" .. (cat.name or "") .. "|r"))
				anchor.text:Show()
			end
			anchor:Show()
		end
	end
end

local function AcquireBar(catId)
	framePools[catId] = framePools[catId] or {}
	local pool = framePools[catId]
	local bar = table.remove(pool)
	if not bar then
		bar = CreateFrame("Frame", nil, ensureAnchor(catId))
		bar.status = CreateFrame("StatusBar", nil, bar)
		bar.status:SetAllPoints()
		bar.status:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		bar.icon = bar:CreateTexture(nil, "ARTWORK")
		bar.text = bar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		bar.text:SetPoint("LEFT", 4, 0)
		bar.time = bar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		bar.time:SetPoint("RIGHT", -4, 0)
		bar.time:SetJustifyH("RIGHT")
	end
	bar:SetParent(ensureAnchor(catId))
	bar:Show()
	return bar
end

local function ReleaseBar(catId, bar)
	if not bar then return end
	bar:SetScript("OnUpdate", nil)
	bar:Hide()
	activeBars[catId][bar.owner] = nil
	for i, b in ipairs(activeOrder[catId]) do
		if b == bar then
			table.remove(activeOrder[catId], i)
			break
		end
	end
	table.insert(framePools[catId], bar)
	CastTracker.functions.LayoutBars(catId)
end

local function BarUpdate(self)
	local now = GetTime()
	if now >= self.finish then
		ReleaseBar(self.catId, self)
		return
	end
	self.status:SetValue(now - self.start)
	self.time:SetFormattedText("%.1f", self.finish - now)
end

function CastTracker.functions.LayoutBars(catId)
	local order = activeOrder[catId] or {}
	local anchor = ensureAnchor(catId)
	for i, bar in ipairs(order) do
		bar:ClearAllPoints()
		if i == 1 then
			bar:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
		else
			bar:SetPoint("TOPLEFT", order[i - 1], "BOTTOMLEFT", 0, -2)
		end
	end
end

function CastTracker.functions.StartBar(spellId, sourceGUID, catId)
	local name, _, icon, castTime = GetSpellInfo(spellId)
	castTime = (castTime or 0) / 1000
	local db = addon.db.castTrackerCategories and addon.db.castTrackerCategories[catId] or {}
	if db.duration and db.duration > 0 then castTime = db.duration end
	if castTime <= 0 then return end
	activeBars[catId] = activeBars[catId] or {}
	activeOrder[catId] = activeOrder[catId] or {}
	framePools[catId] = framePools[catId] or {}
	local bar = activeBars[catId][sourceGUID]
	if bar then ReleaseBar(catId, bar) end
	bar = AcquireBar(catId)
	activeBars[catId][sourceGUID] = bar
	bar.owner = sourceGUID
	bar.spellId = spellId
	bar.catId = catId
	bar.icon:SetTexture(icon)
	bar.text:SetText(name)
	bar.status:SetMinMaxValues(0, castTime)
	bar.status:SetValue(0)
	bar.status:SetStatusBarColor(unpack(db.color or { 1, 0.5, 0, 1 }))
	bar.icon:SetSize(db.height or 20, db.height or 20)
	bar.icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
	bar:SetSize(db.width or 200, db.height or 20)
	bar.start = GetTime()
	bar.finish = bar.start + castTime
	bar:SetScript("OnUpdate", BarUpdate)
	table.insert(activeOrder[catId], bar)
	CastTracker.functions.LayoutBars(catId)
	if db.sound then PlaySound(db.sound) end
end

CastTracker.functions.AcquireBar = AcquireBar
CastTracker.functions.ReleaseBar = ReleaseBar
CastTracker.functions.BarUpdate = BarUpdate
CastTracker.functions.UpdateActiveBars = UpdateActiveBars

local function HandleCLEU()
	local _, subevent, _, sourceGUID, _, sourceFlags, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
	if subevent == "SPELL_CAST_START" then
		for catId, cat in pairs(addon.db.castTrackerCategories or {}) do
			if addon.db.castTrackerEnabled[catId] and cat.spells and cat.spells[spellId] and bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0 then
				CastTracker.functions.StartBar(spellId, sourceGUID, catId)
			end
		end
	elseif subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_FAILED" or subevent == "SPELL_INTERRUPT" then
		for id, bars in pairs(activeBars) do
			local bar = bars[sourceGUID]
			if bar and bar.spellId == spellId then ReleaseBar(id, bar) end
		end
	elseif subevent == "UNIT_DIED" then
		for id, bars in pairs(activeBars) do
			local bar = bars[destGUID]
			if bar then ReleaseBar(id, bar) end
		end
	end
end

local eventFrame = CreateFrame("Frame")

function CastTracker.functions.Refresh()
	for id, cat in pairs(addon.db.castTrackerCategories or {}) do
		local a = ensureAnchor(id)
		a:ClearAllPoints()
		a:SetPoint(cat.anchor.point, UIParent, cat.anchor.point, cat.anchor.x, cat.anchor.y)
		UpdateActiveBars(id)
	end
	eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	eventFrame:SetScript("OnEvent", HandleCLEU)
	applyLockState()
end

function CastTracker.functions.addCastTrackerOptions(container)
	local db = addon.db.castTrackerCategories[selectedCategory] or {}
	db.spells = db.spells or {}

	local function rebuild()
		container:ReleaseChildren()
		CastTracker.functions.addCastTrackerOptions(container)
	end

	local wrapper = addon.functions.createContainer("SimpleGroup", "Flow")
	container:AddChild(wrapper)

	local drop = addon.functions.createDropdownAce("Category", {}, nil, function(self, _, val)
		selectedCategory = val
		addon.db.castTrackerSelectedCategory = val
		rebuild()
	end)
	local catlist, order = {}, {}
	for id, cat in pairs(addon.db.castTrackerCategories or {}) do
		catlist[id] = cat.name or tostring(id)
		table.insert(order, id)
	end
	table.sort(order)
	drop:SetList(catlist, order)
	drop:SetValue(selectedCategory)
	wrapper:AddChild(drop)

	local enableCB = addon.functions.createCheckboxAce(_G.ENABLE, addon.db.castTrackerEnabled[selectedCategory], function(self, _, val)
		addon.db.castTrackerEnabled[selectedCategory] = val
		applyLockState()
	end)
	wrapper:AddChild(enableCB)

	local lockCB = addon.functions.createCheckboxAce(L["buffTrackerLocked"], addon.db.castTrackerLocked[selectedCategory], function(self, _, val)
		addon.db.castTrackerLocked[selectedCategory] = val
		applyLockState()
	end)
	wrapper:AddChild(lockCB)

	local groupCore = addon.functions.createContainer("InlineGroup", "List")
	groupCore:SetTitle(L["CastTracker"])
	wrapper:AddChild(groupCore)

	local sw = addon.functions.createSliderAce(L["CastTrackerWidth"] .. ": " .. (db.width or 200), db.width or 200, 50, 400, 1, function(self, _, val)
		db.width = val
		self:SetLabel(L["CastTrackerWidth"] .. ": " .. val)
		UpdateActiveBars(selectedCategory)
	end)
	groupCore:AddChild(sw)

	local sh = addon.functions.createSliderAce(L["CastTrackerHeight"] .. ": " .. (db.height or 20), db.height or 20, 10, 60, 1, function(self, _, val)
		db.height = val
		self:SetLabel(L["CastTrackerHeight"] .. ": " .. val)
		UpdateActiveBars(selectedCategory)
	end)
	groupCore:AddChild(sh)

	local dur = addon.functions.createSliderAce(L["CastTrackerDuration"] .. ": " .. (db.duration or 0), db.duration or 0, 0, 10, 0.5, function(self, _, val)
		db.duration = val
		self:SetLabel(L["CastTrackerDuration"] .. ": " .. val)
	end)
	groupCore:AddChild(dur)

	local col = AceGUI:Create("ColorPicker")
	col:SetLabel(L["CastTrackerColor"])
	local c = db.color or { 1, 0.5, 0, 1 }
	col:SetColor(c[1], c[2], c[3], c[4])
	col:SetCallback("OnValueChanged", function(_, _, r, g, b, a)
		db.color = { r, g, b, a }
		UpdateActiveBars(selectedCategory)
	end)
	groupCore:AddChild(col)

	local soundList = {}
	for sname in pairs(addon.Aura.sounds or {}) do
		soundList[sname] = sname
	end
	local list, soundOrder = addon.functions.prepareListForDropdown(soundList)
	local dropSound = addon.functions.createDropdownAce(L["SoundFile"], list, soundOrder, function(self, _, val)
		db.sound = val
		self:SetValue(val)
		local file = addon.Aura.sounds and addon.Aura.sounds[val]
		if file then PlaySoundFile(file, "Master") end
	end)
	dropSound:SetValue(db.sound)
	groupCore:AddChild(dropSound)

	wrapper:AddChild(addon.functions.createSpacerAce())

	local groupSpells = addon.functions.createContainer("InlineGroup", "Flow")
	groupSpells:SetTitle(L["CastTrackerSpells"])
	wrapper:AddChild(groupSpells)

	local addEdit = addon.functions.createEditboxAce(L["AddSpellID"], nil, function(self, _, text)
		local id = tonumber(text)
		if id then
			db.spells[id] = true
			self:SetText("")
			rebuild()
		end
	end)
	groupSpells:AddChild(addEdit)

	for spellId in pairs(db.spells) do
		local line = addon.functions.createContainer("SimpleGroup", "Flow")
		line:SetFullWidth(true)
		local name = GetSpellInfo(spellId) or tostring(spellId)
		local label = addon.functions.createLabelAce(name .. " (" .. spellId .. ")")
		label:SetRelativeWidth(0.7)
		line:AddChild(label)
		local btn = addon.functions.createButtonAce(L["Remove"], 80, function()
			db.spells[spellId] = nil
			for id, bars in pairs(activeBars) do
				for owner, b in pairs(bars) do
					if b.spellId == spellId then ReleaseBar(id, b) end
				end
			end
			rebuild()
		end)
		line:AddChild(btn)
		groupSpells:AddChild(line)
	end
end

CastTracker.functions.Refresh()
