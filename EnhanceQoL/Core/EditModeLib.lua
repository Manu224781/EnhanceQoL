local _, addon = ...

-- Lightweight replacement for LibEditMode with the bits we actually use
local lib = addon.EditModeLib or {}
addon.EditModeLib = lib

if lib.__initialized then return end
lib.__initialized = true

lib.internal = lib.internal or {}
local internal = lib.internal

local layoutNames = setmetatable({ "Modern", "Classic" }, {
	__index = function(t, key)
		if key > 2 then
			local layouts = C_EditMode.GetLayouts().layouts
			if (key - 2) > #layouts then
				error("index is out of bounds")
			else
				return layouts[key - 2].layoutName
			end
		else
			return rawget(t, key)
		end
	end,
})

lib.frameSelections = lib.frameSelections or {}
lib.frameCallbacks = lib.frameCallbacks or {}
lib.frameDefaults = lib.frameDefaults or {}
lib.frameSettings = lib.frameSettings or {}
lib.frameButtons = lib.frameButtons or {}

lib.anonCallbacksEnter = lib.anonCallbacksEnter or {}
lib.anonCallbacksExit = lib.anonCallbacksExit or {}
lib.anonCallbacksLayout = lib.anonCallbacksLayout or {}

-- Pools -----------------------------------------------------------------------
local pools = {}
local PoolAcquire = CreateUnsecuredObjectPool().Acquire
local function poolAcquire(self, parent)
	local obj, new = PoolAcquire(self)
	if parent then obj:SetParent(parent) end
	return obj, new
end

function internal:CreatePool(kind, creationFunc, resetterFunc)
	local pool = CreateUnsecuredObjectPool(creationFunc, resetterFunc)
	pool.Acquire = poolAcquire
	pools[kind] = pool
end

function internal:GetPool(kind) return pools[kind] end

function internal:ReleaseAllPools()
	for _, pool in next, pools do
		pool:ReleaseAll()
	end
end

lib.SettingType = CopyTable(Enum.EditModeSettingDisplayType)

-- Widgets ---------------------------------------------------------------------
local checkboxMixin = {}
function checkboxMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.name)

	local value = data.get(lib.activeLayoutName)
	if value == nil then value = data.default end

	self.checked = value
	self.Button:SetChecked(not not value)
end

function checkboxMixin:OnCheckButtonClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	self.checked = not self.checked
	self.setting.set(lib.activeLayoutName, not not self.checked)
end

internal:CreatePool(lib.SettingType.Checkbox, function()
	local frame = CreateFrame("Frame", nil, UIParent, "EditModeSettingCheckboxTemplate")
	return Mixin(frame, checkboxMixin)
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)

local function dropdownGet(data) return data.get(lib.activeLayoutName) == data.value end

local function dropdownSet(data) data.set(lib.activeLayoutName, data.value) end

local dropdownMixin = {}
function dropdownMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.name)

	if data.generator then
		self.Dropdown:SetupMenu(function(owner, rootDescription) pcall(data.generator, owner, rootDescription, data) end)
	elseif data.values then
		self.Dropdown:SetupMenu(function(_, rootDescription)
			if data.height then rootDescription:SetScrollMode(data.height) end

			for _, value in next, data.values do
				if value.isRadio then
					rootDescription:CreateRadio(value.text, dropdownGet, dropdownSet, {
						get = data.get,
						set = data.set,
						value = value.text,
					})
				else
					rootDescription:CreateCheckbox(value.text, dropdownGet, dropdownSet, {
						get = data.get,
						set = data.set,
						value = value.text,
					})
				end
			end
		end)
	end
end

internal:CreatePool(lib.SettingType.Dropdown, function()
	local frame = CreateFrame("Frame", nil, UIParent, "ResizeLayoutFrame")
	frame.fixedHeight = 32
	Mixin(frame, dropdownMixin)

	local label = frame:CreateFontString(nil, nil, "GameFontHighlightMedium")
	label:SetPoint("LEFT")
	label:SetWidth(100)
	label:SetJustifyH("LEFT")
	frame.Label = label

	local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	dropdown:SetPoint("LEFT", label, "RIGHT", 5, 0)
	dropdown:SetSize(200, 30)
	frame.Dropdown = dropdown

	return frame
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)

local sliderMixin = {}
function sliderMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.name)

	self.initInProgress = true
	self.formatters = {}
	self.formatters[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, data.formatter)

	local stepSize = data.valueStep or 1
	local steps = (data.maxValue - data.minValue) / stepSize
	self.Slider:Init(data.get(lib.activeLayoutName) or data.default, data.minValue or 0, data.maxValue or 1, steps, self.formatters)
	self.initInProgress = false
end

function sliderMixin:OnSliderValueChanged(value)
	if not self.initInProgress then self.setting.set(lib.activeLayoutName, value) end
end

internal:CreatePool(lib.SettingType.Slider, function()
	local frame = CreateFrame("Frame", nil, UIParent, "EditModeSettingSliderTemplate")
	Mixin(frame, sliderMixin)

	frame:SetHeight(32)
	frame.Slider:SetWidth(200)
	frame.Slider.MinText:Hide()
	frame.Slider.MaxText:Hide()
	frame.Label:SetPoint("LEFT")

	frame:OnLoad()
	return frame
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)

internal:CreatePool("button", function() return CreateFrame("Button", nil, UIParent, "EditModeSystemSettingsDialogExtraButtonTemplate") end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)

-- Dialog ----------------------------------------------------------------------
local dialogMixin = {}
function dialogMixin:Update(selection)
	self.selection = selection

	self.Title:SetText(selection.parent.editModeName or selection.parent:GetName())
	self:UpdateSettings()
	self:UpdateButtons()

	if not self:IsShown() then
		self:ClearAllPoints()
		self:SetPoint("BOTTOMRIGHT", UIParent, -250, 250)
	end

	self:Show()
	self:Layout()
end

function dialogMixin:UpdateSettings()
	internal:ReleaseAllPools()

	local settings, num = internal:GetFrameSettings(self.selection.parent)
	if num > 0 then
		for index, data in next, settings do
			local pool = internal:GetPool(data.kind)
			if pool then
				local setting = pool:Acquire(self.Settings)
				setting.layoutIndex = index
				setting:Setup(data)
				setting:Show()
			end
		end
	end

	self.Settings.ResetButton.layoutIndex = num + 1
	self.Settings.Divider.layoutIndex = num + 2
	self.Settings.ResetButton:SetEnabled(num > 0)
end

function dialogMixin:UpdateButtons()
	local buttons, num = internal:GetFrameButtons(self.selection.parent)
	if num > 0 then
		for index, data in next, buttons do
			local button = internal:GetPool("button"):Acquire(self.Buttons)
			button.layoutIndex = index
			button:SetText(data.text)
			button:SetOnClickHandler(data.click)
			button:Show()
		end
	end

	local resetPosition = internal:GetPool("button"):Acquire(self.Buttons)
	resetPosition.layoutIndex = num + 1
	resetPosition:SetText(HUD_EDIT_MODE_RESET_POSITION)
	resetPosition:SetOnClickHandler(GenerateClosure(self.ResetPosition, self))
	resetPosition:Show()
end

function dialogMixin:ResetSettings()
	local settings, num = internal:GetFrameSettings(self.selection.parent)
	if num > 0 then
		for _, data in next, settings do
			data.set(lib.activeLayoutName, data.default)
		end

		self:Update(self.selection)
	end
end

function dialogMixin:ResetPosition()
	local parent = self.selection.parent
	local pos = lib:GetFrameDefaultPosition(parent)
	if not pos then pos = {
		point = "CENTER",
		x = 0,
		y = 0,
	} end

	parent:ClearAllPoints()
	parent:SetPoint(pos.point, pos.x, pos.y)

	internal:TriggerCallback(parent, pos.point, pos.x, pos.y)
end

function internal:CreateDialog()
	local dialog = Mixin(CreateFrame("Frame", nil, UIParent, "ResizeLayoutFrame"), dialogMixin)
	dialog:SetSize(300, 350)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetFrameLevel(200)
	dialog:Hide()
	dialog.widthPadding = 40
	dialog.heightPadding = 40

	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:SetClampedToScreen(true)
	dialog:SetDontSavePosition(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", function() dialog:StartMoving() end)
	dialog:SetScript("OnDragStop", function() dialog:StopMovingOrSizing() end)

	local dialogTitle = dialog:CreateFontString(nil, nil, "GameFontHighlightLarge")
	dialogTitle:SetPoint("TOP", 0, -15)
	dialog.Title = dialogTitle

	local dialogBorder = CreateFrame("Frame", nil, dialog, "DialogBorderTranslucentTemplate")
	dialogBorder.ignoreInLayout = true
	dialog.Border = dialogBorder

	local dialogClose = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
	dialogClose:SetPoint("TOPRIGHT")
	dialogClose.ignoreInLayout = true
	dialog.Close = dialogClose

	local dialogSettings = CreateFrame("Frame", nil, dialog, "VerticalLayoutFrame")
	dialogSettings:SetPoint("TOP", dialogTitle, "BOTTOM", 0, -12)
	dialogSettings.spacing = 2
	dialog.Settings = dialogSettings

	local resetSettingsButton = CreateFrame("Button", nil, dialogSettings, "EditModeSystemSettingsDialogButtonTemplate")
	resetSettingsButton:SetText(RESET_TO_DEFAULT)
	resetSettingsButton:SetOnClickHandler(GenerateClosure(dialog.ResetSettings, dialog))
	dialogSettings.ResetButton = resetSettingsButton

	local divider = dialogSettings:CreateTexture(nil, "ARTWORK")
	divider:SetSize(330, 16)
	divider:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])
	dialogSettings.Divider = divider

	local dialogButtons = CreateFrame("Frame", nil, dialog, "VerticalLayoutFrame")
	dialogButtons:SetPoint("TOP", dialogSettings, "BOTTOM", 0, -12)
	dialogButtons.spacing = 2
	dialog.Buttons = dialogButtons

	return dialog
end

-- Core ------------------------------------------------------------------------
local function resetSelection()
	if internal.dialog then internal.dialog:Hide() end

	for frame, selection in next, lib.frameSelections do
		if selection.isSelected then frame:SetMovable(false) end

		if not lib.isEditing then
			selection:Hide()
			selection.isSelected = false
		else
			selection:ShowHighlighted()
		end
	end
end

local function onDragStart(self) self.parent:StartMoving() end

local function normalizePosition(frame)
	local parent = frame:GetParent()
	if not parent then return end

	local scale = frame:GetScale()
	if not scale then return end

	local left = frame:GetLeft() * scale
	local top = frame:GetTop() * scale
	local right = frame:GetRight() * scale
	local bottom = frame:GetBottom() * scale

	local parentWidth, parentHeight = parent:GetSize()

	local x, y, point
	if left < (parentWidth - right) and left < math.abs((left + right) / 2 - parentWidth / 2) then
		x = left
		point = "LEFT"
	elseif (parentWidth - right) < math.abs((left + right) / 2 - parentWidth / 2) then
		x = right - parentWidth
		point = "RIGHT"
	else
		x = (left + right) / 2 - parentWidth / 2
		point = ""
	end

	if bottom < (parentHeight - top) and bottom < math.abs((bottom + top) / 2 - parentHeight / 2) then
		y = bottom
		point = "BOTTOM" .. point
	elseif (parentHeight - top) < math.abs((bottom + top) / 2 - parentHeight / 2) then
		y = top - parentHeight
		point = "TOP" .. point
	else
		y = (bottom + top) / 2 - parentHeight / 2
		point = "" .. point
	end

	if point == "" then point = "CENTER" end

	return point, x / scale, y / scale
end

local function onDragStop(self)
	local parent = self.parent
	parent:StopMovingOrSizing()

	local point, x, y = normalizePosition(parent)
	parent:ClearAllPoints()
	parent:SetPoint(point, x, y)

	internal:TriggerCallback(parent, point, x, y)
end

local function onMouseDown(self)
	resetSelection()
	if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then EditModeManagerFrame:ClearSelectedSystem() end

	if not self.isSelected then
		self.parent:SetMovable(true)
		self:ShowSelected(true)
		if internal.dialog then internal.dialog:Update(self) end
	end
end

local function onEditModeEnter()
	lib.isEditing = true

	resetSelection()

	for _, callback in next, lib.anonCallbacksEnter do
		securecallfunction(callback)
	end
end

local function onEditModeExit()
	lib.isEditing = false

	resetSelection()

	for _, callback in next, lib.anonCallbacksExit do
		securecallfunction(callback)
	end
end

local function onEditModeChanged(_, layoutInfo)
	local layoutName = layoutNames[layoutInfo.activeLayout]
	if layoutName ~= lib.activeLayoutName then
		lib.activeLayoutName = layoutName

		for _, callback in next, lib.anonCallbacksLayout do
			securecallfunction(callback, layoutName)
		end
	end
end

function lib:AddFrame(frame, callback, default)
	local selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
	selection:SetAllPoints()
	selection:SetScript("OnMouseDown", onMouseDown)
	selection:SetScript("OnDragStart", onDragStart)
	selection:SetScript("OnDragStop", onDragStop)
	selection:Hide()

	if select(4, GetBuildInfo()) >= 110200 then
		selection.system = {}
		selection.system.GetSystemName = function() return frame.editModeName or frame:GetName() end
	else
		selection.Label:SetText(frame.editModeName or frame:GetName())
	end

	lib.frameSelections[frame] = selection
	lib.frameCallbacks[frame] = callback
	lib.frameDefaults[frame] = default

	if not internal.dialog then
		internal.dialog = internal:CreateDialog()
		internal.dialog:HookScript("OnHide", function() resetSelection() end)

		EventRegistry:RegisterFrameEventAndCallback("EDIT_MODE_LAYOUTS_UPDATED", onEditModeChanged)

		EditModeManagerFrame:HookScript("OnShow", onEditModeEnter)
		EditModeManagerFrame:HookScript("OnHide", onEditModeExit)

		hooksecurefunc(EditModeManagerFrame, "SelectSystem", function() resetSelection() end)
	end
end

function lib:AddFrameSettings(frame, settings)
	if not lib.frameSelections[frame] then error("frame must be registered") end

	lib.frameSettings[frame] = settings
end

function lib:AddFrameSettingsButton(frame, data)
	if not lib.frameButtons[frame] then lib.frameButtons[frame] = {} end

	table.insert(lib.frameButtons[frame], data)
end

function lib:RegisterCallback(event, callback)
	assert(event and type(event) == "string", "event must be a string")
	assert(callback and type(callback) == "function", "callback must be a function")

	if event == "enter" then
		table.insert(lib.anonCallbacksEnter, callback)
	elseif event == "exit" then
		table.insert(lib.anonCallbacksExit, callback)
	elseif event == "layout" then
		table.insert(lib.anonCallbacksLayout, callback)
	else
		error('invalid callback event "' .. event .. '"')
	end
end

function lib:GetActiveLayoutName() return lib.activeLayoutName end

function lib:IsInEditMode() return not not lib.isEditing end

function lib:GetFrameDefaultPosition(frame) return lib.frameDefaults[frame] end

function internal:TriggerCallback(frame, ...)
	if lib.frameCallbacks[frame] then securecallfunction(lib.frameCallbacks[frame], frame, lib.activeLayoutName, ...) end
end

function internal:GetFrameSettings(frame)
	if lib.frameSettings[frame] then
		return lib.frameSettings[frame], #lib.frameSettings[frame]
	else
		return nil, 0
	end
end

function internal:GetFrameButtons(frame)
	if lib.frameButtons[frame] then
		return lib.frameButtons[frame], #lib.frameButtons[frame]
	else
		return nil, 0
	end
end
