-- luacheck: globals EnhanceQoL MenuUtil MenuResponse C_AddOns UIParentLoadAddOn PlayerSpellsUtil C_Garrison C_Covenants Enum ShowGarrisonLandingPage HousingFramesUtil ToggleCharacter ToggleProfessionsBook ToggleAchievementFrame ToggleQuestLog ToggleCalendar ToggleTimeManager ToggleEncounterJournal ToggleGuildFrame PVEFrame_ToggleFrame ToggleCollectionsJournal ToggleGameMenu ToggleHelpFrame ToggleChannelFrame ToggleFriendsFrame UnitClass
local addonName, addon = ...
local L = addon.L

local format = string.format
local lower = string.lower
local G = _G

local ICON_SIZE = 14

local function atlasIcon(atlas)
	if not atlas then return "" end
	return format("|A:%s:%d:%d|a ", atlas, ICON_SIZE, ICON_SIZE)
end

local function textureIcon(texture)
	if not texture then return "" end
	return format("|T%s:%d:%d|t ", texture, ICON_SIZE, ICON_SIZE)
end

local function classIcon()
	local class = UnitClass and select(2, UnitClass("player"))
	if not class then return "" end
	return atlasIcon("classicon-" .. lower(class))
end

local function ensureAddOn(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn then
		if not C_AddOns.IsAddOnLoaded(name) then C_AddOns.LoadAddOn(name) end
	elseif UIParentLoadAddOn then
		UIParentLoadAddOn(name)
	end
end

local function openCharacter()
	if ToggleCharacter then ToggleCharacter("PaperDollFrame") end
end

local function openProfessions()
	if ToggleProfessionsBook then ToggleProfessionsBook() end
end

local function openTalents()
	ensureAddOn("Blizzard_PlayerSpells")
	if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentOrSpecFrame then
		PlayerSpellsUtil.ToggleClassTalentOrSpecFrame()
	end
end

local function openSpellbook()
	ensureAddOn("Blizzard_PlayerSpells")
	if PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
		PlayerSpellsUtil.ToggleSpellBookFrame()
	end
end

local function openAchievements()
	if ToggleAchievementFrame then ToggleAchievementFrame() end
end

local function openQuestLog()
	ensureAddOn("Blizzard_WorldMap")
	if ToggleQuestLog then ToggleQuestLog() end
end

local function openHousing()
	ensureAddOn("Blizzard_HousingEventHandler")
	if HousingFramesUtil and HousingFramesUtil.ToggleHousingDashboard then
		HousingFramesUtil.ToggleHousingDashboard()
	end
end

local function openGuild()
	ensureAddOn("Blizzard_Communities")
	if ToggleGuildFrame then ToggleGuildFrame() end
end

local function openLFG()
	ensureAddOn("Blizzard_GroupFinder")
	if PVEFrame_ToggleFrame then PVEFrame_ToggleFrame() end
end

local function openDungeonJournal()
	if ToggleEncounterJournal then ToggleEncounterJournal() end
end

local function openCollections()
	if ToggleCollectionsJournal then ToggleCollectionsJournal() end
end

local function openGameMenu()
	if ToggleGameMenu then ToggleGameMenu() end
end

local function openHelp()
	if ToggleHelpFrame then ToggleHelpFrame() end
end

local function openCalendar()
	if ToggleCalendar then ToggleCalendar() end
end

local function openClock()
	if ToggleTimeManager then ToggleTimeManager() end
end

local function openChatChannels()
	ensureAddOn("Blizzard_Channels")
	if ToggleChannelFrame then ToggleChannelFrame() end
end

local function openSocial()
	ensureAddOn("Blizzard_FriendsFrame")
	if ToggleFriendsFrame then ToggleFriendsFrame() end
end

local function getMissionsGarrisonType()
	if not C_Garrison or not C_Garrison.GetLandingPageGarrisonType then return nil end
	local garrTypeID = C_Garrison.GetLandingPageGarrisonType()
	if not garrTypeID or garrTypeID == 0 then return nil end
	if C_Garrison.IsLandingPageMinimapButtonVisible and not C_Garrison.IsLandingPageMinimapButtonVisible(garrTypeID) then
		return nil
	end
	if Enum and Enum.GarrisonType and Enum.GarrisonType.Type_9_0_Garrison and garrTypeID == Enum.GarrisonType.Type_9_0_Garrison then
		if not C_Covenants or not C_Covenants.GetActiveCovenantID then return nil end
		local covenantID = C_Covenants.GetActiveCovenantID()
		if not covenantID or covenantID == 0 then return nil end
		if C_Covenants.GetCovenantData and not C_Covenants.GetCovenantData(covenantID) then return nil end
	end
	return garrTypeID
end

local function missionsEnabled()
	return getMissionsGarrisonType() ~= nil
end

local function openMissions()
	local garrTypeID = getMissionsGarrisonType()
	if not garrTypeID then return end
	ensureAddOn("Blizzard_GarrisonBase")
	if ShowGarrisonLandingPage then ShowGarrisonLandingPage(garrTypeID) end
end

local menuEntries = {
	{
		label = G.ACHIEVEMENT_BUTTON or "Achievements",
		icon = atlasIcon("UI-HUD-MicroMenu-Achievements-Up"),
		action = openAchievements,
	},
	{
		label = G.CALENDAR or "Calendar",
		icon = textureIcon("Interface\\Calendar\\EventNotification"),
		action = openCalendar,
	},
	{
		label = G.CHARACTER_BUTTON or "Character",
		icon = classIcon,
		action = openCharacter,
	},
	{
		label = G.CHAT_CHANNELS or "Chat Channels",
		icon = textureIcon("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up"),
		action = openChatChannels,
	},
	{
		label = G.TIMEMANAGER_TITLE or "Clock",
		icon = textureIcon("Interface\\TimeManager\\GlobeIcon"),
		action = openClock,
	},
	{
		label = G.ENCOUNTER_JOURNAL or G.ADVENTURE_JOURNAL or "Dungeon Journal",
		icon = atlasIcon("UI-HUD-MicroMenu-AdventureGuide-Up"),
		action = openDungeonJournal,
	},
	{
		label = G.GUILD or "Guild",
		icon = atlasIcon("UI-HUD-MicroMenu-GuildCommunities-Up"),
		action = openGuild,
	},
	{
		label = G.HOUSING_DASHBOARD_HOUSEINFO_FRAMETITLE or G.HOUSING_MICRO_BUTTON or "Housing Dashboard",
		icon = atlasIcon("UI-HUD-MicroMenu-Housing-Up"),
		action = openHousing,
	},
	{
		label = G.DUNGEONS_BUTTON or "Looking For Group",
		icon = atlasIcon("UI-HUD-MicroMenu-Groupfinder-Up"),
		action = openLFG,
	},
	{
		label = G.GARRISON_MISSIONS or "Missions",
		icon = textureIcon("Interface\\Icons\\INV_Garrison_Mission"),
		action = openMissions,
		enabled = missionsEnabled,
	},
	{
		label = G.PROFESSIONS_BUTTON or "Professions",
		icon = atlasIcon("UI-HUD-MicroMenu-Professions-Up"),
		action = openProfessions,
	},
	{
		label = G.QUESTLOG_BUTTON or "Quest Log",
		icon = atlasIcon("UI-HUD-MicroMenu-Questlog-Up"),
		action = openQuestLog,
	},
	{
		label = L["Social"] or "Social",
		icon = textureIcon("Interface\\FriendsFrame\\PlusManz-PlusManz"),
		action = openSocial,
	},
	{
		label = L["Specialization & Talents"] or G.PLAYERSPELLS_BUTTON or "Specialization & Talents",
		icon = atlasIcon("UI-HUD-MicroMenu-SpecTalents-Up"),
		action = openTalents,
	},
	{
		label = G.SPELLBOOK_ABILITIES_BUTTON or "Spellbook",
		icon = textureIcon("Interface\\Icons\\INV_Misc_Book_09"),
		action = openSpellbook,
	},
	{
		label = L["Warband Collections"] or G.COLLECTIONS or "Collections",
		icon = atlasIcon("UI-HUD-MicroMenu-Collections-Up"),
		action = openCollections,
	},
	{
		label = G.MAINMENU_BUTTON or "Game Menu",
		icon = atlasIcon("UI-HUD-MicroMenu-GameMenu-Up"),
		action = openGameMenu,
	},
	{
		label = L["Customer Support"] or G.HELP_BUTTON or "Customer Support",
		icon = atlasIcon("UI-HUD-MicroMenu-Help-Up"),
		action = openHelp,
	},
}

local function getMenuLabel(entry)
	local label = entry.label
	if type(label) == "function" then label = label() end
	if not label then label = "" end
	local icon = entry.icon
	if type(icon) == "function" then icon = icon() end
	if not icon then icon = "" end
	return icon .. label
end

local function isEntryEnabled(entry)
	if entry.enabled == nil then return true end
	if type(entry.enabled) == "function" then return entry.enabled() end
	return entry.enabled and true or false
end

local function showMenu(owner)
	if not MenuUtil or not MenuUtil.CreateContextMenu then return end
	MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_MICROBAR")
		rootDescription:CreateTitle(L["Micro Bar"] or "Micro Bar")

		for _, entry in ipairs(menuEntries) do
			local label = getMenuLabel(entry)
			local enabled = isEntryEnabled(entry)
			local button = rootDescription:CreateButton(label, function()
				if enabled and entry.action then entry.action() end
				return MenuResponse and MenuResponse.Close
			end)
			if button and not enabled then button:SetEnabled(false) end
		end
	end)
end

local function updateMicroBar(stream)
	stream.snapshot.text = L["Micro Bar"] or "Micro Bar"
	stream.snapshot.fontSize = 14
end

local provider = {
	id = "microbar",
	version = 1,
	title = L["Micro Bar"] or "Micro Bar",
	update = updateMicroBar,
	events = {
		PLAYER_ENTERING_WORLD = function(s) addon.DataHub:RequestUpdate(s) end,
	},
	OnClick = function(button, btn)
		if btn == "LeftButton" then showMenu(button) end
	end,
}

EnhanceQoL.DataHub.RegisterStream(provider)

return provider
