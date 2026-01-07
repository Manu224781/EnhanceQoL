-- luacheck: globals EnhanceQoL
local addonName, addon = ...
local L = addon.L

local AceGUI = addon.AceGUI
local db
local stream

local function getOptionsHint()
	if addon.DataPanel and addon.DataPanel.GetOptionsHintText then
		local text = addon.DataPanel.GetOptionsHintText()
		if text ~= nil then return text end
		return nil
	end
	return L["Right-Click for options"]
end

local function ensureDB()
	addon.db.datapanel = addon.db.datapanel or {}
	addon.db.datapanel.gold = addon.db.datapanel.gold or {}
	db = addon.db.datapanel.gold
	db.fontSize = db.fontSize or 14
	db.displayMode = db.displayMode or "character"
	if db.displayMode == "account" then db.displayMode = "warband" end
end
local function RestorePosition(frame)
	if db.point and db.x and db.y then
		frame:ClearAllPoints()
		frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
	end
end

local aceWindow
local function createAceWindow()
	if aceWindow then
		aceWindow:Show()
		return
	end
	ensureDB()
	local frame = AceGUI:Create("Window")
	aceWindow = frame.frame
	frame:SetTitle(GAMEMENU_OPTIONS)
	frame:SetWidth(300)
	frame:SetHeight(200)
	frame:SetLayout("List")

	frame.frame:SetScript("OnShow", function(self) RestorePosition(self) end)
	frame.frame:SetScript("OnHide", function(self)
		local point, _, _, xOfs, yOfs = self:GetPoint()
		db.point = point
		db.x = xOfs
		db.y = yOfs
	end)

	local fontSize = AceGUI:Create("Slider")
	fontSize:SetLabel(FONT_SIZE)
	fontSize:SetSliderValues(8, 32, 1)
	fontSize:SetValue(db.fontSize)
	fontSize:SetCallback("OnValueChanged", function(_, _, val)
		db.fontSize = val
		addon.DataHub:RequestUpdate(stream)
	end)
	frame:AddChild(fontSize)

	frame.frame:Show()
end

local floor = math.floor
local GetMoney = GetMoney

local COPPER_PER_GOLD = 10000

local function formatGoldString(copper)
	local g = floor(copper / COPPER_PER_GOLD)
	local s = floor((copper % COPPER_PER_GOLD) / 100)
	local c = copper % 100
	local gText = (BreakUpLargeNumbers and BreakUpLargeNumbers(g)) or tostring(g)
	return gText, s, c
end

local function formatMoney(value)
	if addon.functions and addon.functions.formatMoney then return addon.functions.formatMoney(value or 0, "tracker") end
	return tostring(value or 0)
end

local function collectCharacterMoney()
	local list, total = {}, 0
	if addon.db and type(addon.db.moneyTracker) == "table" then
		for _, info in pairs(addon.db.moneyTracker) do
			if type(info) == "table" and type(info.money) == "number" then
				total = total + info.money
				list[#list + 1] = info
			end
		end
	end
	table.sort(list, function(a, b)
		local am = a.money or 0
		local bm = b.money or 0
		if am == bm then return (a.name or "") < (b.name or "") end
		return am > bm
	end)
	return list, total
end

local function getDisplayLabel()
	if db and db.displayMode == "warband" then return L["warbandGold"] or "Warband gold" end
	return L["goldPanelDisplayCharacter"] or "Character"
end

local function toggleDisplayMode()
	ensureDB()
	if db.displayMode == "warband" then
		db.displayMode = "character"
	else
		db.displayMode = "warband"
	end
	addon.DataHub:RequestUpdate(stream)
end

local function checkMoney(stream)
	ensureDB()
	if db.displayMode == "account" then db.displayMode = "warband" end
	local money = GetMoney() or 0
	if db.displayMode == "warband" then money = addon.db and addon.db.warbandGold or 0 end
	local gText, s, c = formatGoldString(money)
	local size = db and db.fontSize or 12
	stream.snapshot.fontSize = size
	stream.snapshot.text = ("|TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d:0:0|t %s"):format(size, size, gText)
	stream.snapshot.tooltip = nil
end

local provider = {
	id = "gold",
	version = 1,
	title = WORLD_QUEST_REWARD_FILTERS_GOLD,
	update = checkMoney,
	events = {
		PLAYER_MONEY = function(stream) addon.DataHub:RequestUpdate(stream) end,
		PLAYER_LOGIN = function(stream) addon.DataHub:RequestUpdate(stream) end,
		ACCOUNT_MONEY = function(stream) addon.DataHub:RequestUpdate(stream) end,
	},
	OnClick = function(_, btn)
		if btn == "LeftButton" then
			toggleDisplayMode()
		elseif btn == "RightButton" then
			createAceWindow()
		end
	end,
	OnMouseEnter = function(btn)
		local tip = GameTooltip
		tip:ClearLines()
		tip:SetOwner(btn, "ANCHOR_TOPLEFT")

		local warband = addon.db and addon.db.warbandGold
		if warband ~= nil then tip:AddDoubleLine(L["warbandGold"] or "Warband gold", formatMoney(warband)) end

		local list, total = collectCharacterMoney()
		if #list > 0 then
			if warband ~= nil then tip:AddLine(" ") end
			tip:AddLine((L["goldPanelDisplayCharacter"] or "Character") .. ":")
			for _, info in ipairs(list) do
				local name = info.name or UNKNOWN
				local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[info.class]
				if color then name = string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name) end
				tip:AddDoubleLine(name, formatMoney(info.money))
			end
			tip:AddLine(" ")
			tip:AddDoubleLine(TOTAL or "Total", formatMoney(total))
		end

		local clickHint = L["goldPanelClickHint"] or "Left-click to toggle warband/character gold"
		local modeHint = (L["goldPanelDisplay"] or "Gold display") .. ": " .. getDisplayLabel()
		local hint = getOptionsHint()
		if clickHint or modeHint or hint then
			tip:AddLine(" ")
			if clickHint then tip:AddLine(clickHint, 0.7, 0.7, 0.7) end
			if modeHint then tip:AddLine(modeHint, 0.7, 0.7, 0.7) end
			if hint then tip:AddLine(hint, 0.7, 0.7, 0.7) end
		end
		tip:Show()
	end,
}

stream = EnhanceQoL.DataHub.RegisterStream(provider)

return provider
