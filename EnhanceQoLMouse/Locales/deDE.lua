local L = LibStub("AceLocale-3.0"):NewLocale("EnhanceQoL_Mouse", "deDE")
if not L then return end

--@localization(locale="deDE", namespace="Mouse", format="lua_additive_table")@

-- Fallbacks für neue Strings (werden von Lokalisation überschrieben, wenn vorhanden)
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Mouse")
L["mouseRingOnlyInCombat"] = L["mouseRingOnlyInCombat"] or "Ring nur im Kampf anzeigen"
L["mouseTrailOnlyInCombat"] = L["mouseTrailOnlyInCombat"] or "Spur nur im Kampf anzeigen"
L["mouseRingUseClassColor"] = L["mouseRingUseClassColor"] or "Klassenfarbe für Ring verwenden"
L["mouseTrailUseClassColor"] = L["mouseTrailUseClassColor"] or "Klassenfarbe für Spur verwenden"
