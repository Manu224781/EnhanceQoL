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

local framePool = {}
local activeBars = {}
local activeOrder = {}
local anchor

local function AcquireBar()
	local bar = table.remove(framePool)
	if not bar then
		bar = CreateFrame("Frame", nil, anchor)
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
	bar:Show()
	return bar
end

local function ReleaseBar(bar)
	if not bar then return end
	bar:SetScript("OnUpdate", nil)
	bar:Hide()
	activeBars[bar.owner] = nil
	for i, b in ipairs(activeOrder) do
		if b == bar then
			table.remove(activeOrder, i)
			break
		end
	end
	table.insert(framePool, bar)
	CastTracker.functions.LayoutBars()
end

local function BarUpdate(self)
	local now = GetTime()
	if now >= self.finish then
		ReleaseBar(self)
		return
	end
	self.status:SetValue(now - self.start)
	self.time:SetFormattedText("%.1f", self.finish - now)
end

function CastTracker.functions.LayoutBars()
	for i, bar in ipairs(activeOrder) do
		bar:ClearAllPoints()
		if i == 1 then
			bar:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
		else
			bar:SetPoint("TOPLEFT", activeOrder[i - 1], "BOTTOMLEFT", 0, -2)
		end
	end
end

function CastTracker.functions.StartBar(spellId, sourceGUID)
	local name, _, icon, castTime = GetSpellInfo(spellId)
	castTime = (castTime or 0) / 1000
	if castTime <= 0 then return end
	local db = addon.db.castTracker or {}
	local bar = activeBars[sourceGUID]
	if bar then ReleaseBar(bar) end
	bar = AcquireBar()
	activeBars[sourceGUID] = bar
	bar.owner = sourceGUID
	bar.spellId = spellId
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
	table.insert(activeOrder, bar)
	CastTracker.functions.LayoutBars()
	if db.sound then PlaySound(db.sound) end
end

CastTracker.functions.AcquireBar = AcquireBar
CastTracker.functions.ReleaseBar = ReleaseBar
CastTracker.functions.BarUpdate = BarUpdate

local function HandleCLEU()
	local _, subevent, _, sourceGUID, _, sourceFlags, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
	if subevent == "SPELL_CAST_START" then
		if bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0 then CastTracker.functions.StartBar(spellId, sourceGUID) end
	elseif subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_FAILED" or subevent == "SPELL_INTERRUPT" then
		local bar = activeBars[sourceGUID]
		if bar and bar.spellId == spellId then ReleaseBar(bar) end
	elseif subevent == "UNIT_DIED" then
		ReleaseBar(activeBars[destGUID])
	end
end

local eventFrame = CreateFrame("Frame")

function CastTracker.functions.Refresh()
	local db = addon.db.castTracker or {}
	if not anchor then
		anchor = CreateFrame("Frame", nil, UIParent)
		anchor:SetPoint(db.anchor.point, UIParent, db.anchor.point, db.anchor.x, db.anchor.y)
	end
	eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	eventFrame:SetScript("OnEvent", HandleCLEU)
	CastTracker.functions.LayoutBars()
end

function CastTracker.functions.addCastTrackerOptions(container)
	local label = addon.functions.createLabelAce("Cast Tracker options are not implemented yet.")
	container:AddChild(label)
end

CastTracker.functions.Refresh()
