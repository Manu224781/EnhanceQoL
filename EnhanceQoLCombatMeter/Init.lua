local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
-- luacheck: globals GENERAL SlashCmdList INTERRUPTS UIParent
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

if addon.variables.isMidnight then return end

addon.CombatMeter = {}
addon.CombatMeter.functions = {}

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_CombatMeter")
local TEXTURE_PATH = "Interface\\AddOns\\EnhanceQoLCombatMeter\\Texture\\"
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

addon.functions.InitDBValue("combatMeterEnabled", false)
addon.functions.InitDBValue("combatMeterHistory", {})
addon.functions.InitDBValue("combatMeterAlwaysShow", false)
addon.functions.InitDBValue("combatMeterUpdateRate", 0.2)
addon.functions.InitDBValue("combatMeterFontSize", 12)
addon.functions.InitDBValue("combatMeterNameLength", 12)
addon.functions.InitDBValue("combatMeterPrePullCapture", true)
addon.functions.InitDBValue("combatMeterPrePullWindow", 4)
addon.functions.InitDBValue("combatMeterBarTexture", TEXTURE_PATH .. "eqol_base_flat_8x8.tga")
addon.functions.InitDBValue("combatMeterUseOverlay", false)
addon.functions.InitDBValue("combatMeterOverlayTexture", TEXTURE_PATH .. "eqol_overlay_gradient_512x64.tga")
addon.functions.InitDBValue("combatMeterOverlayBlend", "ADD")
addon.functions.InitDBValue("combatMeterOverlayAlpha", 0.28)
addon.functions.InitDBValue("combatMeterRoundedCorners", false)
addon.functions.InitDBValue("combatMeterResetOnChallengeStart", true)
addon.functions.InitDBValue("combatMeterGroups", {
	{
		type = "dps",
		point = "CENTER",
		x = 0,
		y = 0,
		barWidth = 210,
		barHeight = 25,
		maxBars = 5,
		alwaysShowSelf = true,
	},
})
