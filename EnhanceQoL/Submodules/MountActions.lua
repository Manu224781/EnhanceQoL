local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale(parentAddonName)

local MountActions = addon.MountActions or {}
addon.MountActions = MountActions

local RANDOM_FAVORITE_SPELL_ID = 150544
local REPAIR_MOUNT_SPELLS = { 457485, 122708, 61425, 61447 }
local AH_MOUNT_SPELLS = { 264058, 465235 }

_G["BINDING_NAME_CLICK EQOLRandomMountButton:LeftButton"] = L["Random Mount"] or "Random Mount"
_G["BINDING_NAME_CLICK EQOLRepairMountButton:LeftButton"] = L["Repair Mount"] or "Repair Mount"
_G["BINDING_NAME_CLICK EQOLAuctionMountButton:LeftButton"] = L["Auction House Mount"] or "Auction House Mount"

local function getMountIdFromSource(sourceID)
	if not sourceID then return nil, nil end
	if C_MountJournal then
		if C_MountJournal.GetMountFromSpell then
			local mountID = C_MountJournal.GetMountFromSpell(sourceID)
			if mountID then return mountID, "spell" end
		end
		if C_MountJournal.GetMountFromItem then
			local mountID = C_MountJournal.GetMountFromItem(sourceID)
			if mountID then return mountID, "item" end
		end
	end
	return nil, nil
end

local function isMountSpellUsable(spellID)
	if not spellID then return false end
	local mountID = getMountIdFromSource(spellID)
	if not mountID then return false end
	local _, _, _, _, isUsable, _, _, _, _, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
	if not isCollected or shouldHideOnChar then return false end
	if C_MountJournal.GetMountUsabilityByID then
		local usable = C_MountJournal.GetMountUsabilityByID(mountID, true)
		if usable ~= nil then isUsable = usable end
	end
	return isUsable == true
end

local function pickFirstUsable(spellList)
	for _, spellID in ipairs(spellList) do
		if isMountSpellUsable(spellID) then return spellID end
	end
	return nil
end

local function getSourceName(sourceID)
	local name
	if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(sourceID) end
	if not name and GetSpellInfo then name = GetSpellInfo(sourceID) end
	if not name and C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(sourceID) end
	if not name and GetItemInfo then name = GetItemInfo(sourceID) end
	return name
end

local function getMountDebugInfo(spellID)
	local sourceName = getSourceName(spellID)
	local mountID, sourceType = getMountIdFromSource(spellID)
	local mountName, isCollected, isUsable, isHidden
	if mountID and C_MountJournal and C_MountJournal.GetMountInfoByID then
		local name, _, _, _, usable, _, _, _, _, shouldHideOnChar, collected = C_MountJournal.GetMountInfoByID(mountID)
		mountName = name
		isCollected = collected
		isHidden = shouldHideOnChar
		isUsable = usable
		if C_MountJournal.GetMountUsabilityByID then
			local usableByID = C_MountJournal.GetMountUsabilityByID(mountID, true)
			if usableByID ~= nil then isUsable = usableByID end
		end
	end
	return sourceName, mountID, mountName, isCollected, isUsable, isHidden, sourceType
end

local function debugRepairMountSelection(selectedSpellID)
	local parts = {}
	for _, spellID in ipairs(REPAIR_MOUNT_SPELLS) do
		local sourceName, mountID, mountName, collected, usable, hidden, sourceType = getMountDebugInfo(spellID)
		parts[#parts + 1] = string.format(
			"%s (%s) source=%s mountID=%s mount=%s collected=%s usable=%s hidden=%s",
			tostring(spellID),
			sourceName or "?",
			sourceType or "?",
			mountID and tostring(mountID) or "?",
			mountName or "?",
			tostring(collected),
			tostring(usable),
			tostring(hidden)
		)
	end
	local message = "Repair Mount candidates: " .. table.concat(parts, " | ")
	if selectedSpellID then message = message .. " | selected=" .. tostring(selectedSpellID) end
	print("|cff00ff98Enhance QoL|r: " .. message)
end

local function summonMountBySource(sourceID)
	if not sourceID then return false end
	if C_MountJournal and C_MountJournal.SummonByID then
		local mountID = getMountIdFromSource(sourceID)
		if mountID then
			C_MountJournal.SummonByID(mountID)
			return true
		end
	end
	if CastSpellByID then
		CastSpellByID(sourceID)
		return true
	end
	return false
end

function MountActions:IsRandomAllEnabled()
	return addon.db and addon.db.randomMountUseAll == true
end

function MountActions:MarkRandomCacheDirty()
	self.randomAllDirty = true
end

function MountActions:BuildRandomAllCache()
	local list = {}
	if not C_MountJournal or not C_MountJournal.GetMountIDs then return list end
	local mountIDs = C_MountJournal.GetMountIDs()
	if type(mountIDs) ~= "table" then return list end
	for _, mountID in ipairs(mountIDs) do
		local _, spellID, _, _, isUsable, _, _, _, _, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
		if isCollected and not shouldHideOnChar and spellID then
			if C_MountJournal.GetMountUsabilityByID then
				local usable = C_MountJournal.GetMountUsabilityByID(mountID, true)
				if usable ~= nil then isUsable = usable end
			end
			if isUsable then list[#list + 1] = spellID end
		end
	end
	return list
end

function MountActions:GetRandomAllSpell()
	if self.randomAllDirty or not self.randomAllCache then
		self.randomAllCache = self:BuildRandomAllCache()
		self.randomAllDirty = false
	end
	local list = self.randomAllCache
	if not list or #list == 0 then return nil end
	local idx = math.random(#list)
	return list[idx]
end

function MountActions:PrepareActionButton(btn)
	if InCombatLockdown and InCombatLockdown() then return end
	if not btn or not btn._eqolAction then return end
	if btn._eqolAction == "random" then
		if self:IsRandomAllEnabled() then
			local spellID = self:GetRandomAllSpell()
			if spellID then
				btn:SetAttribute("spell1", spellID)
				btn:SetAttribute("spell", spellID)
			else
				btn:SetAttribute("spell1", RANDOM_FAVORITE_SPELL_ID)
				btn:SetAttribute("spell", RANDOM_FAVORITE_SPELL_ID)
			end
		else
			btn:SetAttribute("spell1", RANDOM_FAVORITE_SPELL_ID)
			btn:SetAttribute("spell", RANDOM_FAVORITE_SPELL_ID)
		end
	elseif btn._eqolAction == "repair" then
		local spellID = pickFirstUsable(REPAIR_MOUNT_SPELLS)
		btn:SetAttribute("spell1", spellID)
		btn:SetAttribute("spell", spellID)
	elseif btn._eqolAction == "ah" then
		local spellID = pickFirstUsable(AH_MOUNT_SPELLS)
		btn:SetAttribute("spell1", spellID)
		btn:SetAttribute("spell", spellID)
	end
end

function MountActions:HandleClick(btn, button, down)
	if button and button ~= "LeftButton" then return end
	if down == false then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if not btn or not btn._eqolAction then return end

	if btn._eqolAction == "random" then
		if self:IsRandomAllEnabled() then
			local spellID = self:GetRandomAllSpell()
			if spellID then summonMountBySource(spellID) end
		else
			summonMountBySource(RANDOM_FAVORITE_SPELL_ID)
		end
	elseif btn._eqolAction == "repair" then
		local spellID = pickFirstUsable(REPAIR_MOUNT_SPELLS)
		debugRepairMountSelection(spellID)
		if spellID then summonMountBySource(spellID) end
	elseif btn._eqolAction == "ah" then
		local spellID = pickFirstUsable(AH_MOUNT_SPELLS)
		if spellID then summonMountBySource(spellID) end
	end
end

function MountActions:EnsureButton(name, action)
	local btn = _G[name]
	if not btn then
		btn = CreateFrame("Button", name, UIParent, "InsecureActionButtonTemplate")
	end
	btn:RegisterForClicks("AnyDown")
	btn:SetAttribute("type1", "spell")
	btn:SetAttribute("type", "spell")
	-- Force the action to trigger on key down regardless of ActionButtonUseKeyDown.
	btn:SetAttribute("pressAndHoldAction", true)
	btn._eqolAction = action
	if action == "random" then
		btn:SetAttribute("spell1", RANDOM_FAVORITE_SPELL_ID)
		btn:SetAttribute("spell", RANDOM_FAVORITE_SPELL_ID)
	end
	btn:SetScript("PreClick", function(self) MountActions:PrepareActionButton(self) end)
	btn:SetScript("OnClick", function(self, button, down) MountActions:HandleClick(self, button, down) end)
	return btn
end

function MountActions:Init()
	if self.initialized then return end
	self.initialized = true
	self:MarkRandomCacheDirty()
	self:EnsureButton("EQOLRandomMountButton", "random")
	self:EnsureButton("EQOLRepairMountButton", "repair")
	self:EnsureButton("EQOLAuctionMountButton", "ah")
end

local function handleMountEvents()
	MountActions:MarkRandomCacheDirty()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
eventFrame:RegisterEvent("COMPANION_LEARNED")
eventFrame:RegisterEvent("COMPANION_UNLEARNED")
eventFrame:RegisterEvent("COMPANION_UPDATE")
eventFrame:SetScript("OnEvent", handleMountEvents)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function() MountActions:Init() end)
