local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.GCDBar = addon.GCDBar or {}
local GCDBar = addon.GCDBar

local L = LibStub("AceLocale-3.0"):GetLocale(parentAddonName)
local EditMode = addon.EditMode
local SettingType = EditMode and EditMode.lib and EditMode.lib.SettingType
local LSM = LibStub("LibSharedMedia-3.0", true)

local EDITMODE_ID = "gcdBar"
local GCD_SPELL_ID = 61304

GCDBar.defaults = GCDBar.defaults
	or {
		width = 200,
		height = 18,
		texture = "DEFAULT",
		color = { r = 1, g = 0.82, b = 0.2, a = 1 },
		bgEnabled = false,
		bgTexture = "SOLID",
		bgColor = { r = 0, g = 0, b = 0, a = 0 },
		borderEnabled = false,
		borderTexture = "DEFAULT",
		borderColor = { r = 0, g = 0, b = 0, a = 0.8 },
		borderSize = 1,
		borderOffset = 0,
		progressMode = "REMAINING",
		fillDirection = "LEFT",
	}

local defaults = GCDBar.defaults

local DB_ENABLED = "gcdBarEnabled"
local DB_WIDTH = "gcdBarWidth"
local DB_HEIGHT = "gcdBarHeight"
local DB_TEXTURE = "gcdBarTexture"
local DB_COLOR = "gcdBarColor"
local DB_BG_ENABLED = "gcdBarBackgroundEnabled"
local DB_BG_TEXTURE = "gcdBarBackgroundTexture"
local DB_BG_COLOR = "gcdBarBackgroundColor"
local DB_BORDER_ENABLED = "gcdBarBorderEnabled"
local DB_BORDER_TEXTURE = "gcdBarBorderTexture"
local DB_BORDER_COLOR = "gcdBarBorderColor"
local DB_BORDER_SIZE = "gcdBarBorderSize"
local DB_BORDER_OFFSET = "gcdBarBorderOffset"
local DB_PROGRESS_MODE = "gcdBarProgressMode"
local DB_FILL_DIRECTION = "gcdBarFillDirection"

local DEFAULT_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local GetSpellCooldownInfo = (C_Spell and C_Spell.GetSpellCooldown) or GetSpellCooldown
local GetTime = GetTime

local function getValue(key, fallback)
	if not addon.db then return fallback end
	local value = addon.db[key]
	if value == nil then return fallback end
	return value
end

local function clamp(value, minValue, maxValue)
	value = tonumber(value) or minValue
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

local function normalizeColor(value, fallback)
	if type(value) == "table" then
		local r = value.r or value[1] or 1
		local g = value.g or value[2] or 1
		local b = value.b or value[3] or 1
		local a = value.a or value[4]
		return r, g, b, a
	elseif type(value) == "number" then
		return value, value, value
	end
	local d = fallback or defaults.color or {}
	return d.r or 1, d.g or 1, d.b or 1, d.a
end

local function resolveTexture(key)
	if key == "SOLID" then return "Interface\\Buttons\\WHITE8x8" end
	if not key or key == "DEFAULT" then return DEFAULT_TEX end
	if LSM and LSM.Fetch then
		local tex = LSM:Fetch("statusbar", key, true)
		if tex then return tex end
	end
	return key
end

local function resolveBorderTexture(key)
	if key == "SOLID" then return "Interface\\Buttons\\WHITE8x8" end
	if not key or key == "DEFAULT" then return "Interface\\Buttons\\WHITE8x8" end
	if LSM and LSM.Fetch then
		local tex = LSM:Fetch("border", key, true)
		if tex then return tex end
	end
	return key
end

local function textureOptions()
	local list = {}
	local seen = {}
	local function add(value, label)
		local lv = tostring(value or ""):lower()
		if lv == "" or seen[lv] then return end
		seen[lv] = true
		list[#list + 1] = { value = value, label = label }
	end
	add("DEFAULT", _G.DEFAULT)
	add("SOLID", "Solid")
	if LSM and LSM.HashTable then
		for name, path in pairs(LSM:HashTable("statusbar") or {}) do
			if type(path) == "string" and path ~= "" then add(name, tostring(name)) end
		end
	end
	table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
	return list
end

local function borderOptions()
	local list = {}
	local seen = {}
	local function add(value, label)
		local lv = tostring(value or ""):lower()
		if lv == "" or seen[lv] then return end
		seen[lv] = true
		list[#list + 1] = { value = value, label = label }
	end
	add("DEFAULT", _G.DEFAULT)
	add("SOLID", "Solid")
	if LSM and LSM.HashTable then
		for name, path in pairs(LSM:HashTable("border") or {}) do
			if type(path) == "string" and path ~= "" then add(name, tostring(name)) end
		end
	end
	table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
	return list
end

local function normalizeProgressMode(value)
	if value == "ELAPSED" then return "ELAPSED" end
	return "REMAINING"
end

local function normalizeFillDirection(value)
	if value == "RIGHT" then return "RIGHT" end
	return "LEFT"
end

function GCDBar:GetWidth() return clamp(getValue(DB_WIDTH, defaults.width), 50, 800) end

function GCDBar:GetHeight() return clamp(getValue(DB_HEIGHT, defaults.height), 6, 200) end

function GCDBar:GetTextureKey()
	local key = getValue(DB_TEXTURE, defaults.texture)
	if not key or key == "" then key = defaults.texture end
	return key
end

function GCDBar:GetColor() return normalizeColor(getValue(DB_COLOR, defaults.color), defaults.color) end

function GCDBar:GetBackgroundEnabled() return getValue(DB_BG_ENABLED, defaults.bgEnabled) == true end

function GCDBar:GetBackgroundTextureKey()
	local key = getValue(DB_BG_TEXTURE, defaults.bgTexture)
	if not key or key == "" then key = defaults.bgTexture end
	return key
end

function GCDBar:GetBackgroundColor() return normalizeColor(getValue(DB_BG_COLOR, defaults.bgColor), defaults.bgColor) end

function GCDBar:GetBorderEnabled() return getValue(DB_BORDER_ENABLED, defaults.borderEnabled) == true end

function GCDBar:GetBorderTextureKey()
	local key = getValue(DB_BORDER_TEXTURE, defaults.borderTexture)
	if not key or key == "" then key = defaults.borderTexture end
	return key
end

function GCDBar:GetBorderColor() return normalizeColor(getValue(DB_BORDER_COLOR, defaults.borderColor), defaults.borderColor) end

function GCDBar:GetBorderSize() return clamp(getValue(DB_BORDER_SIZE, defaults.borderSize), 1, 20) end

function GCDBar:GetBorderOffset() return clamp(getValue(DB_BORDER_OFFSET, defaults.borderOffset), -20, 20) end

function GCDBar:GetProgressMode() return normalizeProgressMode(getValue(DB_PROGRESS_MODE, defaults.progressMode)) end

function GCDBar:GetFillDirection() return normalizeFillDirection(getValue(DB_FILL_DIRECTION, defaults.fillDirection)) end

function GCDBar:ApplyAppearance()
	if not self.frame then return end
	local texture = resolveTexture(self:GetTextureKey())
	self.frame:SetStatusBarTexture(texture)
	local r, g, b, a = self:GetColor()
	self.frame:SetStatusBarColor(r, g, b, a or 1)
	if self.frame.SetReverseFill then self.frame:SetReverseFill(self:GetFillDirection() == "RIGHT") end

	if self.frame.bg then
		if self:GetBackgroundEnabled() then
			local bgTex = resolveTexture(self:GetBackgroundTextureKey())
			self.frame.bg:SetTexture(bgTex)
			local br, bg, bb, ba = self:GetBackgroundColor()
			local alpha = (ba == nil) and 1 or ba
			self.frame.bg:SetVertexColor(br or 0, bg or 0, bb or 0, alpha)
			self.frame.bg:Hide()
			if alpha > 0 then self.frame.bg:Show() end
		else
			self.frame.bg:Hide()
		end
	end

	if self.frame.border then
		if not self:GetBorderEnabled() then
			self.frame.border:SetBackdrop(nil)
			self.frame.border:Hide()
		else
			local size = self:GetBorderSize()
			local offset = self:GetBorderOffset()
			local borderTex = resolveBorderTexture(self:GetBorderTextureKey())
			self.frame.border:SetBackdrop({
				edgeFile = borderTex,
				edgeSize = size,
				insets = { left = 0, right = 0, top = 0, bottom = 0 },
			})
			local br, bg, bb, ba = self:GetBorderColor()
			self.frame.border:SetBackdropBorderColor(br or 0, bg or 0, bb or 0, ba or 1)
			self.frame.border:SetBackdropColor(0, 0, 0, 0)
			self.frame.border:ClearAllPoints()
			self.frame.border:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -offset, offset)
			self.frame.border:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", offset, -offset)
			self.frame.border:Show()
		end
	end
end

function GCDBar:ApplySize()
	if not self.frame then return end
	self.frame:SetSize(self:GetWidth(), self:GetHeight())
	if self.frame.bg then self.frame.bg:SetAllPoints(self.frame) end
	if self.frame.editBg then self.frame.editBg:SetAllPoints(self.frame) end
	if self.frame.border then self.frame.border:SetAllPoints(self.frame) end
end

function GCDBar:EnsureFrame()
	if self.frame then return self.frame end

	local bar = CreateFrame("StatusBar", "EQOL_GCDBar", UIParent)
	bar:SetMinMaxValues(0, 1)
	bar:SetClampedToScreen(true)
	bar:Hide()

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(bar)
	bar.bg = bg

	local editBg = bar:CreateTexture(nil, "BORDER")
	editBg:SetAllPoints(bar)
	editBg:SetColorTexture(0.1, 0.6, 0.6, 0.2)
	editBg:Hide()
	bar.editBg = editBg

	local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
	border:SetAllPoints(bar)
	border:SetFrameLevel((bar:GetFrameLevel() or 0) + 2)
	border:Hide()
	bar.border = border

	local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER")
	label:SetText(L["GCDBar"] or "GCD Bar")
	label:Hide()
	bar.label = label

	self.frame = bar
	self:ApplyAppearance()
	self:ApplySize()

	return bar
end

function GCDBar:ShowEditModeHint(show)
	if not self.frame then return end
	if show then
		if self.frame.editBg then self.frame.editBg:Show() end
		self.frame.label:Show()
		self.previewing = true
		self.frame:SetMinMaxValues(0, 1)
		self.frame:SetValue(1)
		self.frame:Show()
	else
		if self.frame.editBg then self.frame.editBg:Hide() end
		self.frame.label:Hide()
		self.previewing = nil
		self:UpdateGCD()
	end
end

function GCDBar:StopTimer()
	if self.frame and self.frame.SetScript then self.frame:SetScript("OnUpdate", nil) end
	self._gcdActive = nil
	self._gcdStart = nil
	self._gcdDuration = nil
	self._gcdRate = nil
	if self.frame then self.frame:Hide() end
end

function GCDBar:UpdateTimer()
	if self.previewing then return end
	if not self.frame then return end
	if not self._gcdActive then return end
	local start = self._gcdStart
	local duration = self._gcdDuration
	if not start or not duration or duration <= 0 then
		self:StopTimer()
		return
	end
	local now = GetTime and GetTime() or 0
	local rate = self._gcdRate or 1
	local elapsed = (now - start) * rate
	if elapsed >= duration then
		self:StopTimer()
		return
	end
	local progress = elapsed / duration
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	local value = progress
	if self:GetProgressMode() ~= "ELAPSED" then value = 1 - progress end
	self.frame:SetMinMaxValues(0, 1)
	self.frame:SetValue(value)
	self.frame:Show()
end

function GCDBar:UpdateGCD()
	if self.previewing then return end
	if not self.frame then return end
	if not GetSpellCooldownInfo then return end

	local start, duration, enabled, modRate
	local info, info2, info3, info4 = GetSpellCooldownInfo(GCD_SPELL_ID)
	if type(info) == "table" then
		start = info.startTime
		duration = info.duration
		enabled = info.isEnabled
		modRate = info.modRate or 1
	else
		start, duration, enabled, modRate = info, info2, info3, info4
	end
	if not enabled or not duration or duration <= 0 or not start or start <= 0 then
		self:StopTimer()
		return
	end
	self._gcdActive = true
	self._gcdStart = start
	self._gcdDuration = duration
	self._gcdRate = modRate or 1
	if self.frame.SetScript then self.frame:SetScript("OnUpdate", function() GCDBar:UpdateTimer() end) end
	self:UpdateTimer()
end

function GCDBar:OnEvent(event, spellID, baseSpellID)
	if event ~= "SPELL_UPDATE_COOLDOWN" then return end
	self:UpdateGCD()
end

function GCDBar:RegisterEvents()
	if self.eventsRegistered then return end
	local frame = self:EnsureFrame()
	frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	frame:SetScript("OnEvent", function(_, event, ...) GCDBar:OnEvent(event, ...) end)
	self.eventsRegistered = true
end

function GCDBar:UnregisterEvents()
	if not self.eventsRegistered or not self.frame then return end
	self.frame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
	self.frame:SetScript("OnEvent", nil)
	self.eventsRegistered = false
end

local editModeRegistered = false

function GCDBar:ApplyLayoutData(data)
	if not data or not addon.db then return end

	local width = clamp(data.width or defaults.width, 50, 800)
	local height = clamp(data.height or defaults.height, 6, 200)
	local texture = data.texture or defaults.texture
	local r, g, b, a = normalizeColor(data.color or defaults.color, defaults.color)
	local bgEnabled = data.bgEnabled == true
	local bgTexture = data.bgTexture or defaults.bgTexture
	local bgr, bgg, bgb, bga = normalizeColor(data.bgColor or defaults.bgColor, defaults.bgColor)
	local borderEnabled = data.borderEnabled == true
	local borderTexture = data.borderTexture or defaults.borderTexture
	local bdr, bdg, bdb, bda = normalizeColor(data.borderColor or defaults.borderColor, defaults.borderColor)
	local borderSize = clamp(data.borderSize or defaults.borderSize, 1, 20)
	local borderOffset = clamp(data.borderOffset or defaults.borderOffset, -20, 20)
	local progressMode = normalizeProgressMode(data.progressMode or defaults.progressMode)
	local fillDirection = normalizeFillDirection(data.fillDirection or defaults.fillDirection)

	addon.db[DB_WIDTH] = width
	addon.db[DB_HEIGHT] = height
	addon.db[DB_TEXTURE] = texture
	addon.db[DB_COLOR] = { r = r, g = g, b = b, a = a }
	addon.db[DB_BG_ENABLED] = bgEnabled
	addon.db[DB_BG_TEXTURE] = bgTexture
	addon.db[DB_BG_COLOR] = { r = bgr, g = bgg, b = bgb, a = bga }
	addon.db[DB_BORDER_ENABLED] = borderEnabled
	addon.db[DB_BORDER_TEXTURE] = borderTexture
	addon.db[DB_BORDER_COLOR] = { r = bdr, g = bdg, b = bdb, a = bda }
	addon.db[DB_BORDER_SIZE] = borderSize
	addon.db[DB_BORDER_OFFSET] = borderOffset
	addon.db[DB_PROGRESS_MODE] = progressMode
	addon.db[DB_FILL_DIRECTION] = fillDirection

	self:ApplySize()
	self:ApplyAppearance()
	self:UpdateGCD()
end

local function applySetting(field, value)
	if not addon.db then return end

	if field == "width" then
		local width = clamp(value, 50, 800)
		addon.db[DB_WIDTH] = width
		value = width
	elseif field == "height" then
		local height = clamp(value, 6, 200)
		addon.db[DB_HEIGHT] = height
		value = height
	elseif field == "texture" then
		local tex = value or defaults.texture
		addon.db[DB_TEXTURE] = tex
		value = tex
	elseif field == "color" then
		local r, g, b, a = normalizeColor(value, defaults.color)
		addon.db[DB_COLOR] = { r = r, g = g, b = b, a = a }
		value = addon.db[DB_COLOR]
	elseif field == "bgEnabled" then
		local enabled = value == true
		addon.db[DB_BG_ENABLED] = enabled
		value = enabled
	elseif field == "bgTexture" then
		local tex = value or defaults.bgTexture
		addon.db[DB_BG_TEXTURE] = tex
		value = tex
	elseif field == "bgColor" then
		local r, g, b, a = normalizeColor(value, defaults.bgColor)
		addon.db[DB_BG_COLOR] = { r = r, g = g, b = b, a = a }
		value = addon.db[DB_BG_COLOR]
	elseif field == "borderEnabled" then
		local enabled = value == true
		addon.db[DB_BORDER_ENABLED] = enabled
		value = enabled
	elseif field == "borderTexture" then
		local tex = value or defaults.borderTexture
		addon.db[DB_BORDER_TEXTURE] = tex
		value = tex
	elseif field == "borderColor" then
		local r, g, b, a = normalizeColor(value, defaults.borderColor)
		addon.db[DB_BORDER_COLOR] = { r = r, g = g, b = b, a = a }
		value = addon.db[DB_BORDER_COLOR]
	elseif field == "borderSize" then
		local size = clamp(value, 1, 20)
		addon.db[DB_BORDER_SIZE] = size
		value = size
	elseif field == "borderOffset" then
		local offset = clamp(value, -20, 20)
		addon.db[DB_BORDER_OFFSET] = offset
		value = offset
	elseif field == "progressMode" then
		local mode = normalizeProgressMode(value)
		addon.db[DB_PROGRESS_MODE] = mode
		value = mode
	elseif field == "fillDirection" then
		local dir = normalizeFillDirection(value)
		addon.db[DB_FILL_DIRECTION] = dir
		value = dir
	end

	if EditMode and EditMode.SetValue then EditMode:SetValue(EDITMODE_ID, field, value, nil, true) end
	GCDBar:ApplySize()
	GCDBar:ApplyAppearance()
	GCDBar:UpdateGCD()
end

function GCDBar:RegisterEditMode()
	if editModeRegistered or not EditMode or not EditMode.RegisterFrame then return end

	local settings
	if SettingType then
		settings = {
			{
				name = L["gcdBarWidth"] or "Bar width",
				kind = SettingType.Slider,
				field = "width",
				default = defaults.width,
				minValue = 50,
				maxValue = 800,
				valueStep = 1,
				get = function() return GCDBar:GetWidth() end,
				set = function(_, value) applySetting("width", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["gcdBarHeight"] or "Bar height",
				kind = SettingType.Slider,
				field = "height",
				default = defaults.height,
				minValue = 6,
				maxValue = 200,
				valueStep = 1,
				get = function() return GCDBar:GetHeight() end,
				set = function(_, value) applySetting("height", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["gcdBarTexture"] or "Bar texture",
				kind = SettingType.Dropdown,
				field = "texture",
				height = 180,
				get = function() return GCDBar:GetTextureKey() end,
				set = function(_, value) applySetting("texture", value) end,
				generator = function(_, root)
					for _, option in ipairs(textureOptions()) do
						root:CreateRadio(option.label, function() return GCDBar:GetTextureKey() == option.value end, function() applySetting("texture", option.value) end)
					end
				end,
			},
			{
				name = L["gcdBarColor"] or "Bar color",
				kind = SettingType.Color,
				field = "color",
				default = defaults.color,
				hasOpacity = true,
				get = function()
					local r, g, b, a = GCDBar:GetColor()
					return { r = r, g = g, b = b, a = a }
				end,
				set = function(_, value) applySetting("color", value) end,
			},
			{
				name = L["gcdBarBackgroundEnabled"] or "Use background",
				kind = SettingType.Checkbox,
				field = "bgEnabled",
				default = defaults.bgEnabled == true,
				get = function() return GCDBar:GetBackgroundEnabled() end,
				set = function(_, value) applySetting("bgEnabled", value) end,
			},
			{
				name = L["gcdBarBackgroundTexture"] or "Background texture",
				kind = SettingType.Dropdown,
				field = "bgTexture",
				height = 180,
				get = function() return GCDBar:GetBackgroundTextureKey() end,
				set = function(_, value) applySetting("bgTexture", value) end,
				generator = function(_, root)
					for _, option in ipairs(textureOptions()) do
						root:CreateRadio(option.label, function() return GCDBar:GetBackgroundTextureKey() == option.value end, function() applySetting("bgTexture", option.value) end)
					end
				end,
				isEnabled = function() return GCDBar:GetBackgroundEnabled() end,
			},
			{
				name = L["gcdBarBackgroundColor"] or "Background color",
				kind = SettingType.Color,
				field = "bgColor",
				default = defaults.bgColor,
				hasOpacity = true,
				get = function()
					local r, g, b, a = GCDBar:GetBackgroundColor()
					return { r = r, g = g, b = b, a = a }
				end,
				set = function(_, value) applySetting("bgColor", value) end,
				isEnabled = function() return GCDBar:GetBackgroundEnabled() end,
			},
			{
				name = L["gcdBarBorderEnabled"] or "Use border",
				kind = SettingType.Checkbox,
				field = "borderEnabled",
				default = defaults.borderEnabled == true,
				get = function() return GCDBar:GetBorderEnabled() end,
				set = function(_, value) applySetting("borderEnabled", value) end,
			},
			{
				name = L["gcdBarBorderTexture"] or "Border texture",
				kind = SettingType.Dropdown,
				field = "borderTexture",
				height = 180,
				get = function() return GCDBar:GetBorderTextureKey() end,
				set = function(_, value) applySetting("borderTexture", value) end,
				generator = function(_, root)
					for _, option in ipairs(borderOptions()) do
						root:CreateRadio(option.label, function() return GCDBar:GetBorderTextureKey() == option.value end, function() applySetting("borderTexture", option.value) end)
					end
				end,
				isEnabled = function() return GCDBar:GetBorderEnabled() end,
			},
			{
				name = L["gcdBarBorderSize"] or "Border size",
				kind = SettingType.Slider,
				field = "borderSize",
				default = defaults.borderSize,
				minValue = 1,
				maxValue = 20,
				valueStep = 1,
				get = function() return GCDBar:GetBorderSize() end,
				set = function(_, value) applySetting("borderSize", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isEnabled = function() return GCDBar:GetBorderEnabled() end,
			},
			{
				name = L["gcdBarBorderOffset"] or "Border offset",
				kind = SettingType.Slider,
				field = "borderOffset",
				default = defaults.borderOffset,
				minValue = -20,
				maxValue = 20,
				valueStep = 1,
				get = function() return GCDBar:GetBorderOffset() end,
				set = function(_, value) applySetting("borderOffset", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isEnabled = function() return GCDBar:GetBorderEnabled() end,
			},
			{
				name = L["gcdBarBorderColor"] or "Border color",
				kind = SettingType.Color,
				field = "borderColor",
				default = defaults.borderColor,
				hasOpacity = true,
				get = function()
					local r, g, b, a = GCDBar:GetBorderColor()
					return { r = r, g = g, b = b, a = a }
				end,
				set = function(_, value) applySetting("borderColor", value) end,
				isEnabled = function() return GCDBar:GetBorderEnabled() end,
			},
			{
				name = L["gcdBarProgressMode"] or "Progress mode",
				kind = SettingType.Dropdown,
				field = "progressMode",
				height = 100,
				get = function() return GCDBar:GetProgressMode() end,
				set = function(_, value) applySetting("progressMode", value) end,
				generator = function(_, root)
					local opts = {
						{ value = "REMAINING", label = L["gcdBarProgressDeplete"] or "Deplete (remaining time)" },
						{ value = "ELAPSED", label = L["gcdBarProgressFill"] or "Fill (elapsed time)" },
					}
					for _, option in ipairs(opts) do
						root:CreateRadio(option.label, function() return GCDBar:GetProgressMode() == option.value end, function() applySetting("progressMode", option.value) end)
					end
				end,
			},
			{
				name = L["gcdBarFillDirection"] or "Fill direction",
				kind = SettingType.Dropdown,
				field = "fillDirection",
				height = 100,
				get = function() return GCDBar:GetFillDirection() end,
				set = function(_, value) applySetting("fillDirection", value) end,
				generator = function(_, root)
					local opts = {
						{ value = "LEFT", label = L["gcdBarFillLeft"] or "Left to right" },
						{ value = "RIGHT", label = L["gcdBarFillRight"] or "Right to left" },
					}
					for _, option in ipairs(opts) do
						root:CreateRadio(option.label, function() return GCDBar:GetFillDirection() == option.value end, function() applySetting("fillDirection", option.value) end)
					end
				end,
			},
		}
	end

	EditMode:RegisterFrame(EDITMODE_ID, {
		frame = self:EnsureFrame(),
		title = L["GCDBar"] or "GCD Bar",
		layoutDefaults = {
			point = "CENTER",
			relativePoint = "CENTER",
			x = 0,
			y = -120,
			width = self:GetWidth(),
			height = self:GetHeight(),
			texture = self:GetTextureKey(),
			bgEnabled = self:GetBackgroundEnabled(),
			bgTexture = self:GetBackgroundTextureKey(),
			bgColor = (function()
				local r, g, b, a = self:GetBackgroundColor()
				return { r = r, g = g, b = b, a = a }
			end)(),
			borderEnabled = self:GetBorderEnabled(),
			borderTexture = self:GetBorderTextureKey(),
			borderColor = (function()
				local r, g, b, a = self:GetBorderColor()
				return { r = r, g = g, b = b, a = a }
			end)(),
			borderSize = self:GetBorderSize(),
			borderOffset = self:GetBorderOffset(),
			progressMode = self:GetProgressMode(),
			fillDirection = self:GetFillDirection(),
			color = (function()
				local r, g, b, a = self:GetColor()
				return { r = r, g = g, b = b, a = a }
			end)(),
		},
		onApply = function(_, _, data) GCDBar:ApplyLayoutData(data) end,
		onEnter = function() GCDBar:ShowEditModeHint(true) end,
		onExit = function() GCDBar:ShowEditModeHint(false) end,
		isEnabled = function() return addon.db and addon.db[DB_ENABLED] end,
		settings = settings,
		showOutsideEditMode = false,
		showReset = false,
		showSettingsReset = false,
		enableOverlayToggle = true,
	})

	editModeRegistered = true
end

function GCDBar:OnSettingChanged(enabled)
	if enabled then
		self:EnsureFrame()
		self:RegisterEditMode()
		self:RegisterEvents()
		self:ApplySize()
		self:ApplyAppearance()
		self:UpdateGCD()
	else
		self:UnregisterEvents()
		self:StopTimer()
		if self.frame then self.frame:Hide() end
	end

	if EditMode and EditMode.RefreshFrame then EditMode:RefreshFrame(EDITMODE_ID) end
end

return GCDBar
