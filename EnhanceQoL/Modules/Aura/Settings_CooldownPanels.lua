local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")

local cat = addon.SettingsLayout and addon.SettingsLayout.rootUI
if not (cat and addon.functions and addon.functions.SettingsCreateExpandableSection) then return end

local expandable = addon.functions.SettingsCreateExpandableSection(cat, {
	name = L["CooldownPanels"] or "Cooldown Panels",
	expanded = false,
	colorizeTitle = false,
})

addon.functions.SettingsCreateText(cat, "|cffffd700" .. (L["CooldownPanelEditModeHint"] or "Use Edit Mode to move and resize panels.") .. "|r", {
	parentSection = expandable,
})

local function withCooldownPanels(action)
	local panels = addon.Aura and addon.Aura.CooldownPanels
	if not panels then return end
	action(panels)
end

addon.functions.SettingsCreateButton(cat, {
	text = L["CooldownPanelOpenEditor"] or "Open Cooldown Panel Editor",
	func = function()
		withCooldownPanels(function(panels)
			if panels.OpenEditor then panels:OpenEditor() end
		end)
	end,
	parentSection = expandable,
})

addon.functions.SettingsCreateButton(cat, {
	text = L["CooldownPanelAddPanel"] or "Add Panel",
	func = function()
		withCooldownPanels(function(panels)
			local panelId = panels:CreatePanel(L["CooldownPanelNewPanel"] or "New Panel")
			if panelId then panels:SelectPanel(panelId) end
			if panels.OpenEditor then panels:OpenEditor() end
		end)
	end,
	parentSection = expandable,
})
