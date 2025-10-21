local addonName, addon = ...

addon.MovementSpeedStat = addon.MovementSpeedStat or {}
local mod = addon.MovementSpeedStat

local MOVEMENT_STAT_KEY = "EQOL_MOVEMENT_SPEED"
local CATEGORY_ID = "ENHANCEMENTS"
local BASE_MS = _G.BASE_MOVEMENT_SPEED or 7
local MOVEMENT_STAT_ENTRY = {
	stat = MOVEMENT_STAT_KEY,
	hideAt = 0,
}
local SPEED_EVENTS = {
	"PLAYER_MOUNT_DISPLAY_CHANGED",
	"UPDATE_SHAPESHIFT_FORM",
	"PLAYER_STARTED_MOVING",
	"PLAYER_STOPPED_MOVING",
}
local SPEED_UNIT_EVENTS = {
	"UNIT_ENTERED_VEHICLE",
	"UNIT_EXITED_VEHICLE",
	"UNIT_AURA",
}

local MOVING_TICK = 0.2
local IDLE_TICK = 0.8
local MOVEMENT_THRESHOLD_YPS = 0.5
local CACHE_EPSILON_PCT = 0.5
local CACHE_EPSILON_YPS = 0.1

local cache = { yps = BASE_MS, pct = 100 }
local tickInterval = MOVING_TICK
local accum = MOVING_TICK
local active = false
local installed = false
local eventsRegistered = false
local statFrameRef

local ticker = CreateFrame("Frame")
ticker:Hide()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

local function CharacterUIReady()
	return type(PAPERDOLL_STATINFO) == "table" and type(PAPERDOLL_STATCATEGORIES) == "table"
end

local function GetStatCategory()
	if not CharacterUIReady() then return nil end

	for _, category in ipairs(PAPERDOLL_STATCATEGORIES) do
		if category.categoryFrame == "EnhancementsCategory" or category.id == CATEGORY_ID then return category end
	end
end

local function StatEntryMatches(entry)
	if type(entry) == "table" then return entry.stat == MOVEMENT_STAT_KEY end
	return entry == MOVEMENT_STAT_KEY
end

local function EnsureCategoryReady()
	local category = GetStatCategory()
	if category and category.stats then return category end

	if PaperDoll_InitStatCategories then
		PaperDoll_InitStatCategories(PAPERDOLL_STATCATEGORY_DEFAULTORDER, "statCategoryOrder", "statCategoriesCollapsed", "player")
	end

	return GetStatCategory()
end

local function AddStatToCategory()
	local category = EnsureCategoryReady()
	if not category or not category.stats then return false end

	for _, entry in ipairs(category.stats) do
		if StatEntryMatches(entry) then
			installed = true
			return false
		end
	end

	table.insert(category.stats, MOVEMENT_STAT_ENTRY)
	installed = true
	return true
end

local function RemoveStatFromCategory()
	local category = GetStatCategory()
	if not category or not category.stats then return end

	for index = #category.stats, 1, -1 do
		if StatEntryMatches(category.stats[index]) then table.remove(category.stats, index) end
	end

	installed = false
	statFrameRef = nil
end

local function RebuildPaperDoll()
	if not CharacterUIReady() then return end

	if PaperDoll_InitStatCategories then
		PaperDoll_InitStatCategories(PAPERDOLL_STATCATEGORY_DEFAULTORDER, "statCategoryOrder", "statCategoriesCollapsed", "player")
	end

	if PaperDollFrame_UpdateStats then PaperDollFrame_UpdateStats() end
end

local function Compute(unit)
	unit = unit or "player"

	if unit == "player" and UnitInVehicle("player") then unit = "vehicle" end

	local rawSpeed, runSpeed = GetUnitSpeed(unit)
	rawSpeed = rawSpeed or 0
	runSpeed = runSpeed or 0
	local speed = rawSpeed

	if speed < runSpeed then speed = runSpeed end

	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		local advanced, _, glideSpeed = C_PlayerInfo.GetGlidingInfo()
		if advanced and glideSpeed then
			if glideSpeed > speed then speed = glideSpeed end
			if glideSpeed > rawSpeed then rawSpeed = glideSpeed end
		end
	end

	if speed <= 0 then
		if runSpeed > 0 then
			speed = runSpeed
		else
			speed = BASE_MS
		end
	end

	local pct = (speed / BASE_MS) * 100
	return speed, pct, rawSpeed
end

local function PercentText(p)
	return string.format("%.0f", p)
end

local function ApplyDisplay(yps, pct)
	cache.yps = yps
	cache.pct = pct

	if not statFrameRef then return end

	statFrameRef.numericValue = pct
	PaperDollFrame_SetLabelAndText(statFrameRef, STAT_MOVEMENT_SPEED, PercentText(pct), true, pct)
	statFrameRef.tooltip = HIGHLIGHT_FONT_COLOR_CODE .. STAT_MOVEMENT_SPEED .. FONT_COLOR_CODE_CLOSE
	statFrameRef.tooltip2 = string.format("~%.2f yards/sec", yps)
	statFrameRef:Show()
end

local function StatUpdate(statFrame, unit)
	statFrameRef = statFrame

	if not addon.db or not addon.db.movementSpeedStatEnabled then
		statFrame:Hide()
		return
	end

	unit = unit or "player"

	local yps, pct = Compute(unit)
	ApplyDisplay(yps, pct)
end

local function EnsureStatInfo()
	if not CharacterUIReady() then return end
	if PAPERDOLL_STATINFO[MOVEMENT_STAT_KEY] then return end

	PAPERDOLL_STATINFO[MOVEMENT_STAT_KEY] = {
		category = CATEGORY_ID,
		updateFunc = StatUpdate,
	}
end

local function ShouldUpdate()
	return active and ticker:IsShown()
end

local function ForceTick()
	accum = tickInterval
end

local function OnUpdate(_, elapsed)
	if not ShouldUpdate() then
		accum = tickInterval
		return
	end

	accum = accum + elapsed
	if accum < tickInterval then return end
	accum = 0

	local yps, pct, raw = Compute("player")
	local moving = raw > MOVEMENT_THRESHOLD_YPS
	local desiredInterval = moving and MOVING_TICK or IDLE_TICK
	if desiredInterval ~= tickInterval then
		tickInterval = desiredInterval
		accum = 0
	end

	if math.abs(pct - cache.pct) > CACHE_EPSILON_PCT or math.abs(yps - cache.yps) > CACHE_EPSILON_YPS then
		ApplyDisplay(yps, pct)
	end
end

ticker:SetScript("OnUpdate", OnUpdate)

local function RegisterSpeedEvents()
	if eventsRegistered then return end
	for _, eventName in ipairs(SPEED_EVENTS) do
		eventFrame:RegisterEvent(eventName)
	end
	for _, eventName in ipairs(SPEED_UNIT_EVENTS) do
		eventFrame:RegisterUnitEvent(eventName, "player")
	end
	eventsRegistered = true
end

local function UnregisterSpeedEvents()
	if not eventsRegistered then return end
	for _, eventName in ipairs(SPEED_EVENTS) do
		eventFrame:UnregisterEvent(eventName)
	end
	for _, eventName in ipairs(SPEED_UNIT_EVENTS) do
		eventFrame:UnregisterEvent(eventName)
	end
	eventsRegistered = false
end

local function StartTicker()
	if ticker:IsShown() or not active then return end
	RegisterSpeedEvents()
	tickInterval = MOVING_TICK
	accum = tickInterval
	ForceTick()
	ticker:Show()
end

local function StopTicker()
	if not ticker:IsShown() then return end
	ticker:Hide()
	accum = tickInterval
	UnregisterSpeedEvents()
end

local function HookCharacterFrame()
	if mod._hookedCharacterFrame or not CharacterFrame then return end

	CharacterFrame:HookScript("OnShow", function()
		if active then
			if not statFrameRef and PaperDollFrame_UpdateStats then PaperDollFrame_UpdateStats() end
			StartTicker()
			if statFrameRef then
				local yps, pct = Compute("player")
				ApplyDisplay(yps, pct)
			end
		end
	end)

	CharacterFrame:HookScript("OnHide", function() StopTicker() end)

	mod._hookedCharacterFrame = true

	if CharacterFrame:IsShown() then StartTicker() end
end

local function TryInstall()
	if not active then return end

	if not CharacterUIReady() then return end

	EnsureStatInfo()
	local added = AddStatToCategory()
	HookCharacterFrame()

	if added then RebuildPaperDoll() end

	if CharacterFrame and CharacterFrame:IsShown() then
		if not statFrameRef and PaperDollFrame_UpdateStats then PaperDollFrame_UpdateStats() end
		StartTicker()
		if statFrameRef then
			local yps, pct = Compute("player")
			ApplyDisplay(yps, pct)
		end
	end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name == "Blizzard_CharacterUI" or name == "Blizzard_UIPanels_Game" then TryInstall() end
		return
	end
	if event == "PLAYER_LOGIN" then
		TryInstall()
		return
	end

	if not active or not ticker:IsShown() then return end
	ForceTick()
end)

function mod.Enable()
	if active then return end
	active = true
	tickInterval = MOVING_TICK
	accum = tickInterval
	cache.yps, cache.pct = Compute("player")
	TryInstall()
end

function mod.Disable()
	if not active then return end
	active = false
	StopTicker()

	if installed then
		RemoveStatFromCategory()
		RebuildPaperDoll()
	end

	statFrameRef = nil
end

function mod.Refresh()
	if not addon.db then return end
	if addon.db.movementSpeedStatEnabled then
		mod.Enable()
	else
		mod.Disable()
	end
end
