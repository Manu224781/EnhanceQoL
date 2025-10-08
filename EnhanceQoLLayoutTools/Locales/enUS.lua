local L = LibStub("AceLocale-3.0"):NewLocale("EnhanceQoL_LayoutTools", "enUS", true)

-- Tree entry
L["Move"] = "Layout Tools"

-- Global section
L["Global Settings"] = "Global Settings"
L["Global Move Enabled"] = "Enable Moving (all)"
L["Global Scale Enabled"] = "Enable Scaling (all)"
L["Require Modifier For Move"] = "Require modifier to move"

-- Wheel scaling
L["Wheel Scaling"] = "Wheel Scaling"
L["Scale Modifier"] = "Scale Modifier"
L["ScaleInstructions"] = "Use %s + Mouse Wheel to scale. Use %s + Right-Click to reset."

-- Frames list
L["Frames"] = "Frames"

-- Optional legacy keys (if old pages are ever used)
L["uiScalerPlayerSpellsFrameMove"] = "Enable to move " .. (PLAYERSPELLS_BUTTON or "Talents & Spells")
L["uiScalerPlayerSpellsFrameEnabled"] = "Enable to Scale the " .. (PLAYERSPELLS_BUTTON or "Talents & Spells")
L["talentFrameUIScale"] = "Talent/Spells frame scale"
L["uiScalerCharacterFrameEnabled"] = "Enable to Scale the " .. (CHARACTER_BUTTON or "Character")
L["uiScalerCharacterFrameMove"] = "Enable to move " .. (CHARACTER_BUTTON or "Character")
