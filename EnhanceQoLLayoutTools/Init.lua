local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.LayoutTools = {}
addon.LayoutTools.functions = {}

addon.LayoutTools.variables = {}

addon.functions.InitDBValue("eqolLayoutTools", {})

function addon.LayoutTools.functions.InitDBValue(key, defaultValue)
	if addon.db["eqolLayoutTools"][key] == nil then addon.db["eqolLayoutTools"][key] = defaultValue end
end
-- General setting: which modifier enables wheel-scaling (SHIFT|CTRL|ALT)
addon.LayoutTools.functions.InitDBValue("uiScalerWheelModifier", "SHIFT")
-- Global toggles
addon.LayoutTools.functions.InitDBValue("uiScalerGlobalMoveEnabled", true)
addon.LayoutTools.functions.InitDBValue("uiScalerGlobalScaleEnabled", true)
addon.LayoutTools.functions.InitDBValue("uiScalerMoveRequireModifier", false)
-- Per-frame activation map (nil/true means active by default)
addon.LayoutTools.functions.InitDBValue("uiScalerFramesActive", {})
local db = addon.db["eqolLayoutTools"]

-- Helpers
addon.LayoutTools.variables.managedFrames = addon.LayoutTools.variables.managedFrames or {}
addon.LayoutTools.variables.mouseoverFrames = addon.LayoutTools.variables.mouseoverFrames or {}
addon.LayoutTools.variables.captureInitialized = addon.LayoutTools.variables.captureInitialized or false
addon.LayoutTools.variables.combatQueue = addon.LayoutTools.variables.combatQueue or {}
local function normalizeDbVarFromId(id)
	if not id or type(id) ~= "string" then return nil end
	return string.lower(string.sub(id, 1, 1)) .. string.sub(id, 2)
end

local function getKeys(id)
	return {
		enable = "uiScaler" .. id .. "Enabled",
		scale = "uiScaler" .. id .. "Frame",
		move = "uiScaler" .. id .. "Move",
	}
end

local function getIdForFrameName(fname)
	for _, entry in ipairs(addon.LayoutTools.variables.knownFrames or {}) do
		if entry.names then
			for _, n in ipairs(entry.names) do
				if n == fname then return entry.id end
			end
		end
	end
	return fname
end

local function findEntryById(id)
	for _, entry in ipairs(addon.LayoutTools.variables.knownFrames or {}) do
		if entry.id == id then return entry end
	end
end

local function resolveFramePath(path)
	if not path or type(path) ~= "string" then return nil end
	local first, rest = path:match("([^.]+)%.?(.*)")
	local obj = _G[first]
	if not obj then return nil end
	if rest and rest ~= "" then
		for seg in rest:gmatch("([^.]+)") do
			obj = obj and obj[seg]
			if not obj then return nil end
		end
	end
	return obj
end

-- Deferred application queue for combat-protected frames
addon.LayoutTools.variables.pendingApply = addon.LayoutTools.variables.pendingApply or {}

function addon.LayoutTools.functions.deferApply(frame)
	if not frame then return end
	addon.LayoutTools.variables.pendingApply[frame] = true
end

function addon.LayoutTools.functions.applyFrameSettings(frame)
	if not frame then return end
	local fname = frame:GetName() or ""
	local id = getIdForFrameName(fname)
	local keys = getKeys(id)
	local framesActive = db["uiScalerFramesActive"] or {}
	local active = framesActive[id]
	if active == nil then active = true end
	local globalMove = db["uiScalerGlobalMoveEnabled"]
	local globalScale = db["uiScalerGlobalScaleEnabled"]
	-- Apply scale
	if globalScale and active then
		-- migrate from any legacy per-frame key if group key empty
		if not db[keys.scale] then
			for _, entry in ipairs(addon.LayoutTools.variables.knownFrames or {}) do
				if entry.id == id and entry.names then
					for _, n in ipairs(entry.names) do
						local alt = "uiScaler" .. n .. "Frame"
						if db[alt] then
							db[keys.scale] = db[alt]
							break
						end
					end
					break
				end
			end
		end
		if db[keys.scale] then
			if InCombatLockdown() and frame:IsProtected() then
				addon.LayoutTools.functions.deferApply(frame)
			else
				frame:SetScale(db[keys.scale])
			end
		end
	end
	-- Apply position when moving is enabled and we have stored point
	local dbVar = normalizeDbVarFromId(id)
	if globalMove and active and dbVar and not db[dbVar] then
		-- Try migrate old per-frame position into grouped id
		for _, entry in ipairs(addon.LayoutTools.variables.knownFrames or {}) do
			if entry.id == id and entry.names then
				for _, n in ipairs(entry.names) do
					local oldVar = normalizeDbVarFromId(n)
					if db[oldVar] then
						db[dbVar] = db[oldVar]
						break
					end
				end
				break
			end
		end
	end
	if globalMove and active and dbVar and db[dbVar] and db[dbVar].point and db[dbVar].x and db[dbVar].y then
		if InCombatLockdown() and frame:IsProtected() then
			addon.LayoutTools.functions.deferApply(frame)
		else
			frame:ClearAllPoints()
			frame:SetPoint(db[dbVar].point, UIParent, db[dbVar].point, db[dbVar].x, db[dbVar].y)
		end
	end
end

function addon.LayoutTools.functions.createHooks(frame, dbVar)
	if frame then
		if InCombatLockdown() and frame:IsProtected() then
			addon.LayoutTools.variables.combatQueue[frame] = { dbVar = dbVar }
			return
		end

		if frame._eqolLayoutHooks then return end -- prevent double-hooking

		local fName = frame:GetName() or ""
		local id = getIdForFrameName(fName)
		local keys = getKeys(id)
		local derivedDbVar = normalizeDbVarFromId(id)
		dbVar = dbVar or derivedDbVar
		if dbVar and db[dbVar] == nil then db[dbVar] = {} end
		local function isActive()
			local framesActive = db["uiScalerFramesActive"] or {}
			local v = framesActive[id]
			if v == nil then return true end
			return v
		end

		-- forward declare for wheel handlers used in sub-handles
		local handleWheel

		-- shared drag start/stop for root and sub-handles
		local function onStartDrag()
			if not db["uiScalerGlobalMoveEnabled"] or not isActive() then return end
			if db["uiScalerMoveRequireModifier"] then
				local mod = db["uiScalerWheelModifier"] or "SHIFT"
				local pressed = (mod == "SHIFT" and IsShiftKeyDown()) or (mod == "CTRL" and IsControlKeyDown()) or (mod == "ALT" and IsAltKeyDown())
				if not pressed then return end
			end
			if InCombatLockdown() and frame:IsProtected() then return end
			frame._eqol_isDragging = true
			frame:StartMoving()
		end
		local function onStopDrag()
			if not db["uiScalerGlobalMoveEnabled"] or not isActive() then return end
			if InCombatLockdown() and frame:IsProtected() then return end
			frame:StopMovingOrSizing()
			frame._eqol_isDragging = nil
			local point, _, _, xOfs, yOfs = frame:GetPoint()
			if dbVar then
				db[dbVar].point = point
				db[dbVar].x = xOfs
				db[dbVar].y = yOfs
			end
		end

		frame:SetMovable(true)

		local function attachOverlay(anchor)
			if not anchor then return nil end
			local handle
			if pcall(function() handle = CreateFrame("Frame", nil, anchor, "PanelDragBarTemplate") end) and handle then
				handle.onDragStartCallback = function() return false end
				handle.target = frame
			else
				handle = CreateFrame("Frame", nil, anchor)
			end
			handle:SetAllPoints(anchor)
			handle:SetFrameLevel(anchor:GetFrameLevel() + 1)
			if handle.SetPropagateMouseMotion then handle:SetPropagateMouseMotion(true) end
			if handle.SetPropagateMouseClicks then handle:SetPropagateMouseClicks(true) end
			if handle.EnableMouse then handle:EnableMouse(true) end
			if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end
			handle:HookScript("OnDragStart", function() onStartDrag() end)
			handle:HookScript("OnDragStop", function() onStopDrag() end)
			handle:HookScript("OnMouseDown", function(_, btn)
				if btn == "LeftButton" then onStartDrag() end
			end)
			handle:HookScript("OnMouseUp", function(_, btn)
				if btn == "LeftButton" then onStopDrag() end
			end)
			if handle.EnableMouseWheel then handle:EnableMouseWheel(true) end
			handle:HookScript("OnMouseWheel", function(_, delta)
				if handleWheel then handleWheel(handle, delta) end
			end)
			handle:HookScript("OnMouseUp", function(_, btn)
				if btn ~= "RightButton" then return end
				if not db["uiScalerGlobalScaleEnabled"] or not isActive() then return end
				local mod = db["uiScalerWheelModifier"] or "SHIFT"
				local pressed = (mod == "SHIFT" and IsShiftKeyDown()) or (mod == "CTRL" and IsControlKeyDown()) or (mod == "ALT" and IsAltKeyDown())
				if not pressed then return end
				db[keys.scale] = 1
				if InCombatLockdown() and frame:IsProtected() then
					addon.LayoutTools.functions.deferApply(frame)
				else
					frame:SetScale(1)
				end
			end)
			return handle
		end

		if not frame._eqolMoveHandle then frame._eqolMoveHandle = attachOverlay(frame) end

		-- Add additional move handles for important subframes (e.g. Talents buttons parent)
		local entry = findEntryById(id)
		local createdSubs = frame._eqolMoveSubHandles or {}
		if entry and entry.handles then
			local function attachHandleToAnchor(anchor)
				if not anchor or createdSubs[anchor] then return end
				if anchor.IsForbidden and anchor:IsForbidden() then return end
				createdSubs[anchor] = attachOverlay(anchor)
			end
			for _, path in ipairs(entry.handles) do
				local a = resolveFramePath(path)
				if a then attachHandleToAnchor(a) end
			end
			-- also retry on show to catch late-created subframes
			frame:HookScript("OnShow", function()
				for _, path in ipairs(entry.handles) do
					local a = resolveFramePath(path)
					if a then attachHandleToAnchor(a) end
				end
			end)
		end
		frame._eqolMoveSubHandles = createdSubs

		-- Track for global wheel capture
		addon.LayoutTools.variables.managedFrames[frame] = true
		frame:HookScript("OnEnter", function(self) addon.LayoutTools.variables.mouseoverFrames[self] = true end)
		frame:HookScript("OnLeave", function(self) addon.LayoutTools.variables.mouseoverFrames[self] = nil end)

		-- Re-apply saved position when points change (only if Move enabled)
		hooksecurefunc(frame, "SetPoint", function(self)
			if not db["uiScalerGlobalMoveEnabled"] or not isActive() then return end
			if self._eqol_isDragging then return end
			if self.isRunningPoint then return end
			if dbVar and db[dbVar] and db[dbVar].point and db[dbVar].x and db[dbVar].y then
				if InCombatLockdown() and self:IsProtected() then
					addon.LayoutTools.functions.deferApply(self)
					return
				end
				self.isRunningPoint = true
				self:ClearAllPoints()
				self:SetPoint(db[dbVar].point, UIParent, db[dbVar].point, db[dbVar].x, db[dbVar].y)
				self.isRunningPoint = nil
			end
		end)

		-- Enforce saved scale when SetScale is called (only if scaling is enabled)
		hooksecurefunc(frame, "SetScale", function(self)
			if not db["uiScalerGlobalScaleEnabled"] or not isActive() then return end
			if self.isRunningScale then return end
			local val = db[keys.scale]
			if val then
				if InCombatLockdown() and self:IsProtected() then
					addon.LayoutTools.functions.deferApply(self)
					return
				end
				self.isRunningScale = true
				self:SetScale(val)
				self.isRunningScale = nil
			end
		end)

		-- Apply on show (with combat deferral for protected frames)
		frame:HookScript("OnShow", function(self) addon.LayoutTools.functions.applyFrameSettings(self) end)

		-- Wheel-based scaling with modifier on frame and all descendants
		handleWheel = function(targetFrame, delta)
			if not db["uiScalerGlobalScaleEnabled"] or not isActive() then return end
			local mod = db["uiScalerWheelModifier"] or "SHIFT"
			local pressed = (mod == "SHIFT" and IsShiftKeyDown()) or (mod == "CTRL" and IsControlKeyDown()) or (mod == "ALT" and IsAltKeyDown())
			if not pressed then return end
			local cur = db[keys.scale] or 1
			local step = 0.05
			local minV, maxV = 0.3, 1.0
			local newV = cur + (delta > 0 and step or -step)
			if newV < minV then newV = minV end
			if newV > maxV then newV = maxV end
			db[keys.scale] = newV
			local tgt = frame -- always scale the root frame
			if InCombatLockdown() and tgt:IsProtected() then
				addon.LayoutTools.functions.deferApply(tgt)
			else
				tgt:SetScale(newV)
			end
		end

		local function hookWheelRecursive(parent)
			if not parent or parent._eqolWheelHook then return end
			if parent.EnableMouseWheel then parent:EnableMouseWheel(true) end
			parent:HookScript("OnMouseWheel", function(_, delta) handleWheel(parent, delta) end)
			parent._eqolWheelHook = true
			-- Traverse children safely
			local num = parent.GetChildren and select("#", parent:GetChildren()) or 0
			if num and num > 0 then
				for i = 1, num do
					local child = select(i, parent:GetChildren())
					if child and not (child.IsForbidden and child:IsForbidden()) then hookWheelRecursive(child) end
				end
			end
		end

		-- initial hook for frame + children (wheel only)
		hookWheelRecursive(frame)
		-- root-level right-click reset with modifier (do not hook on children to avoid stealing mouse)
		frame:HookScript("OnMouseUp", function(_, button)
			if button ~= "RightButton" then return end
			if not db["uiScalerGlobalScaleEnabled"] or not isActive() then return end
			local mod = db["uiScalerWheelModifier"] or "SHIFT"
			local pressed = (mod == "SHIFT" and IsShiftKeyDown()) or (mod == "CTRL" and IsControlKeyDown()) or (mod == "ALT" and IsAltKeyDown())
			if not pressed then return end
			db[keys.scale] = 1
			local tgt = frame
			if InCombatLockdown() and tgt:IsProtected() then
				addon.LayoutTools.functions.deferApply(tgt)
			else
				tgt:SetScale(1)
			end
		end)
		-- re-hook possibly new children when frame shows
		frame:HookScript("OnShow", function(self) hookWheelRecursive(self) end)

		frame._eqolLayoutHooks = true
		addon.LayoutTools.variables.combatQueue[frame] = nil
	end
end

-- Prepare list of supported frames (can be extended later)
-- Use names; actual frames may load later and will be hooked on demand
local function isSupported(data) return true end

local function collectHandlesRecursive(name, data, set)
	if not name then return end
	if data and not isSupported(data) then return end
	local skip = data and (data.NonDraggable or data.IgnoreMouse)
	if not skip or not data then set[name] = true end
	if data and data.SubFrames then
		for subName, subData in pairs(data.SubFrames) do
			collectHandlesRecursive(subName, subData, set)
		end
	end
end

local function buildKnownFrames()
	local frames = addon.LayoutTools.variables.frameDefinitions or {}
	local addonFrames = addon.LayoutTools.variables.addonFrameDefinitions or {}
	local known = {}
	local seen = {}

	local function addEntry(addOnName, frameName, frameData)
		if frameData and (frameData.NonDraggable or not isSupported(frameData)) then return end
		local id = addOnName and (addOnName .. "::" .. frameName) or frameName
		if seen[id] then return end
		seen[id] = true

		local handlesSet = {}
		collectHandlesRecursive(frameName, frameData, handlesSet)
		local handles = {}
		for name in pairs(handlesSet) do
			table.insert(handles, name)
		end
		table.sort(handles)

		local entry = {
			id = id,
			label = frameName,
			names = { frameName },
			handles = handles,
			addon = addOnName,
		}
		table.insert(known, entry)
	end

	for frameName, frameData in pairs(frames) do
		addEntry(nil, frameName, frameData)
	end
	for addOn, frameTable in pairs(addonFrames) do
		for frameName, frameData in pairs(frameTable) do
			addEntry(addOn, frameName, frameData)
		end
	end

	table.sort(known, function(a, b) return a.label < b.label end)
	if #known == 0 then
		addon.LayoutTools.variables.knownFrames = {
			{ id = "CharacterFrame", label = CHARACTER_BUTTON, names = { "CharacterFrame" }, handles = { "CharacterFrame", "CharacterFrame.TitleContainer" } },
			{
				id = "Blizzard_PlayerSpells::PlayerSpellsFrame",
				label = PLAYERSPELLS_BUTTON or "PlayerSpellsFrame",
				names = { "PlayerSpellsFrame" },
				handles = { "PlayerSpellsFrame" },
				addon = "Blizzard_PlayerSpells",
			},
		}
	else
		addon.LayoutTools.variables.knownFrames = known
	end
	addon.LayoutTools.variables.knownFramesCount = #addon.LayoutTools.variables.knownFrames
end

buildKnownFrames()

-- Wheel capture overlay (inspired by BlizzMove)
local captureFrame
local function modifierPressed()
	local mod = db["uiScalerWheelModifier"] or "SHIFT"
	return (mod == "SHIFT" and IsShiftKeyDown()) or (mod == "CTRL" and IsControlKeyDown()) or (mod == "ALT" and IsAltKeyDown())
end

local function getMouseFoci()
	if GetMouseFoci then return GetMouseFoci() end
	return { GetMouseFocus() }
end

local function isManagedOrAncestor(f)
	while f do
		if addon.LayoutTools.variables.managedFrames[f] then return true end
		f = f.GetParent and f:GetParent() or nil
	end
	return false
end

local function ensureCapture()
	if captureFrame then return end
	captureFrame = CreateFrame("Frame")
	captureFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	captureFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
	captureFrame:SetFrameStrata("TOOLTIP")
	captureFrame:SetFrameLevel(9999)
	captureFrame:EnableMouseWheel(false)
	captureFrame:Show()
	captureFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
	captureFrame:SetScript("OnEvent", function() captureFrame:EnableMouseWheel(false) end)
	captureFrame:SetScript("OnUpdate", function()
		if not db["uiScalerGlobalScaleEnabled"] or not modifierPressed() then
			captureFrame:EnableMouseWheel(false)
			return
		end
		local anyManagedUnderMouse = false
		for _, f in ipairs(getMouseFoci() or {}) do
			if isManagedOrAncestor(f) then
				anyManagedUnderMouse = true
				break
			end
			if f and (f:IsForbidden() or (f:IsMouseWheelEnabled() or f:IsMouseClickEnabled())) and not isManagedOrAncestor(f) then
				captureFrame:EnableMouseWheel(false)
				return
			end
		end
		captureFrame:EnableMouseWheel(anyManagedUnderMouse)
	end)
	captureFrame:SetScript("OnMouseWheel", function(_, delta)
		for _, f in ipairs(getMouseFoci() or {}) do
			if isManagedOrAncestor(f) then
				-- find managed ancestor/root
				local anc = f
				while anc and not addon.LayoutTools.variables.managedFrames[anc] do
					anc = anc:GetParent()
				end
				local root = anc or f
				local fname = root:GetName() or ""
				local id = getIdForFrameName(fname)
				local keys = getKeys(id)
				local framesActive = db["uiScalerFramesActive"] or {}
				local active = framesActive[id]
				if active == nil then active = true end
				if not active then return end
				local cur = db[keys.scale] or 1
				local step = 0.05
				local minV, maxV = 0.3, 1.0
				local newV = cur + (delta > 0 and step or -step)
				if newV < minV then newV = minV end
				if newV > maxV then newV = maxV end
				db[keys.scale] = newV
				if InCombatLockdown() and root:IsProtected() then
					addon.LayoutTools.functions.deferApply(root)
				else
					root:SetScale(newV)
				end
				return
			end
		end
	end)
end

function addon.LayoutTools.functions.ensureWheelCaptureOverlay() ensureCapture() end
