local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.FriendsListDecor = addon.FriendsListDecor or {}
local FriendsListDecor = addon.FriendsListDecor

FriendsListDecor.enabled = FriendsListDecor.enabled or false

local function GetOption(key, fallback)
	if not addon or not addon.db then return fallback end
	local value = addon.db[key]
	if value == nil then return fallback end
	return value
end

local function IsLocationEnabled()
	return GetOption("friendsListDecorShowLocation", true) == true
end

local function ShouldHideOwnRealm()
	return GetOption("friendsListDecorHideOwnRealm", true) == true
end

local function IsFeatureConfiguredEnabled()
	return GetOption("friendsListDecorEnabled", false) == true
end

local tUnpack = unpack

local NAME_FONT_MIN = 8
local NAME_FONT_MAX = 24

local function GetNameFontSize()
	local value = tonumber(GetOption("friendsListDecorNameFontSize", 0))
	if not value or value <= 0 then return 0 end
	value = math.floor(value + 0.5)
	if value < NAME_FONT_MIN then value = NAME_FONT_MIN end
	if value > NAME_FONT_MAX then value = NAME_FONT_MAX end
	return value
end

local function EnsureOriginalNameFont(button)
	local fontString = button and button.name
	if not fontString then return nil end
	if not fontString._eqolOriginalFont then
		local font, size, flags = fontString:GetFont()
		fontString._eqolOriginalFont = { font, size, flags }
	end
	return fontString._eqolOriginalFont
end

local function RestoreNameFont(button)
	local fontString = button and button.name
	if not fontString or not fontString._eqolOriginalFont then return end
	local font, size, flags = tUnpack(fontString._eqolOriginalFont)
	if font then fontString:SetFont(font, size, flags) end
end

local function ApplyNameFontOverride(button)
	local fontString = button and button.name
	if not fontString then return end
	local original = EnsureOriginalNameFont(button)
	if not original then return end

	local desired = GetNameFontSize()
	local font, baselineSize, flags = tUnpack(original)

	if desired > 0 and font then
		fontString:SetFont(font, desired, flags)
	elseif font then
		fontString:SetFont(font, baselineSize, flags)
	end
end

local select = select
local strsplit = strsplit
local format = string.format
local ipairs = ipairs
local floor = math.floor
local max = math.max
local min = math.min
local UnitFullName = UnitFullName
local GetRealmName = GetRealmName
local GetQuestDifficultyColor = GetQuestDifficultyColor
local TimerunningUtil_AddSmallIcon = TimerunningUtil and TimerunningUtil.AddSmallIcon

local localizedClassMap = {}
if LOCALIZED_CLASS_NAMES_MALE then
	for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		if type(name) == "string" and name ~= "" then localizedClassMap[name] = token end
	end
end
if LOCALIZED_CLASS_NAMES_FEMALE then
	for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
		if type(name) == "string" and name ~= "" and not localizedClassMap[name] then localizedClassMap[name] = token end
	end
end

local factionLookup = {}
local function RegisterFactionKeys(faction, ...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" and value ~= "" then factionLookup[value:lower()] = faction end
	end
end
RegisterFactionKeys("Alliance", "Alliance", ALLIANCE, FACTION_ALLIANCE, PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[1])
RegisterFactionKeys("Horde", "Horde", HORDE, FACTION_HORDE, PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[0])

local function NormalizeFactionName(name)
	if type(name) ~= "string" then return nil end
	return factionLookup[name:lower()]
end

local function CleanRealmName(realm)
	if type(realm) ~= "string" then return nil end
	local cleaned = realm:gsub("%(%*%)", "")
	cleaned = cleaned:gsub("%*$", "")
	cleaned = cleaned:gsub("^%s+", "")
	cleaned = cleaned:gsub("%s+$", "")
	if cleaned == "" then return nil end
	return cleaned
end

local function NormalizeRealmWithoutSpecials(realm)
	if type(realm) ~= "string" then return nil end
	local normalized = realm:gsub("[%s%-']", ""):lower()
	if normalized == "" then return nil end
	return normalized
end

local playerRealmNormalized do
	local playerRealm = GetRealmName and GetRealmName()
	if (not playerRealm or playerRealm == "") and UnitFullName then
		playerRealm = select(2, UnitFullName("player"))
	end
	if playerRealm and playerRealm ~= "" then
		local cleaned = CleanRealmName(playerRealm)
		playerRealmNormalized = cleaned and NormalizeRealmWithoutSpecials(cleaned) or nil
	end
end

local function GetRealmDisplayText(realm)
	local cleaned = CleanRealmName(realm)
	if not cleaned then return nil end

	local normalized = NormalizeRealmWithoutSpecials(cleaned)
	if normalized and playerRealmNormalized and normalized == playerRealmNormalized and ShouldHideOwnRealm() then return nil end

	return cleaned
end

local function BuildLocationText(areaText, realmText)
	if not IsLocationEnabled() then return nil end
	local area = (type(areaText) == "string" and areaText ~= "") and areaText or nil
	local realm = GetRealmDisplayText(realmText)

	if area and realm then return ("%s - %s"):format(area, realm) end
	return area or realm or nil
end

local FACTION_ASSETS = {
	Alliance = {
		atlas = "FactionIcon-Alliance",
		textures = {
			"Interface\\FriendsFrame\\PlusManz-Alliance",
			"Interface\\PVPFrame\\PVP-Currency-Alliance",
			"Interface\\Icons\\Achievement_PVP_A_00",
		},
	},
	Horde = {
		atlas = "FactionIcon-Horde",
		textures = {
			"Interface\\FriendsFrame\\PlusManz-Horde",
			"Interface\\PVPFrame\\PVP-Currency-Horde",
			"Interface\\Icons\\Achievement_PVP_H_00",
		},
	},
}

local STATUS_TEXTURES = {
	Online = FRIENDS_TEXTURE_ONLINE,
	Offline = FRIENDS_TEXTURE_OFFLINE,
	AFK = FRIENDS_TEXTURE_AFK,
	DND = FRIENDS_TEXTURE_DND,
}

local CLIENT_COLORS = {
	[BNET_CLIENT_WOW] = { r = 0.866, g = 0.69, b = 0.18 },
	APP = { r = 0.509, g = 0.772, b = 1 },
	WTCG = { r = 1, g = 0.694, b = 0 },
	Hero = { r = 0, g = 0.8, b = 1 },
	D3 = { r = 0.768, g = 0.121, b = 0.231 },
}

local function SetStatusIcon(button, status)
	if not button or not button.status or not status then return end
	local texture = STATUS_TEXTURES[status]
	if texture then
		button.status:SetTexture(texture)
		button.status:Show()
	end
end

local function AreWoWFriendCountsReady()
	if not C_FriendList or not C_FriendList.GetNumFriends then return false end
	local ok, numFriends = pcall(C_FriendList.GetNumFriends)
	if not ok then return false end
	return type(numFriends) == "number"
end

local function ScheduleRefreshRetry()
	if not C_Timer or not C_Timer.After then return end
	if FriendsListDecor._pendingRefreshTimer then return end
	FriendsListDecor._pendingRefreshTimer = true
	C_Timer.After(0.1, function()
		FriendsListDecor._pendingRefreshTimer = nil
		FriendsListDecor:Refresh()
	end)
end

local function GetFavoriteIcon(button)
	if not button then return nil end
	return button.Favorite or button.favorite or nil
end

local function SetPointCompat(frame, ...)
	if not frame then return end
	if frame.Point then
		frame:Point(...)
	else
		frame:SetPoint(...)
	end
end

local function CacheFavoriteAnchor(favorite)
	if not favorite or favorite._eqolOriginalPoints or not favorite.GetNumPoints then return end
	local points = {}
	for i = 1, favorite:GetNumPoints() do
		local point, relTo, relPoint, x, y = favorite:GetPoint(i)
		points[#points + 1] = { point = point, relTo = relTo, relPoint = relPoint, x = x, y = y }
	end
	favorite._eqolOriginalPoints = points
end

local function RestoreFavoriteAnchor(button)
	local favorite = GetFavoriteIcon(button)
	if not favorite or not favorite._eqolOriginalPoints then return end
	favorite:ClearAllPoints()
	for _, data in ipairs(favorite._eqolOriginalPoints) do
		SetPointCompat(favorite, data.point, data.relTo, data.relPoint, data.x, data.y)
	end
end

local function AdjustFavoriteAnchorNow(button)
	local favorite = GetFavoriteIcon(button)
	if not favorite or not favorite.IsShown or not favorite:IsShown() then return end
	local nameFont = button and button.name
	if not nameFont or not nameFont.GetStringWidth then return end

	CacheFavoriteAnchor(favorite)

	local width = nameFont:GetStringWidth() or 0
	local offset = width + 6

	if button.gameIcon and button.gameIcon.GetLeft and nameFont.GetLeft then
		local iconLeft = button.gameIcon:GetLeft()
		local nameLeft = nameFont:GetLeft()
		local starWidth = (favorite.GetWidth and favorite:GetWidth()) or 0
		if iconLeft and nameLeft and starWidth then
			local maxOffset = (iconLeft - nameLeft) - starWidth - 4
			if maxOffset then
				offset = min(offset, max(0, maxOffset))
			end
		end
	end

	favorite:ClearAllPoints()
	SetPointCompat(favorite, "LEFT", nameFont, "LEFT", offset, 0)
end

local function AdjustFavoriteAnchor(button)
	if not button then return end
	if not C_Timer or not C_Timer.After then
		AdjustFavoriteAnchorNow(button)
		return
	end
	if button._eqolFavoriteAdjustPending then return end
	button._eqolFavoriteAdjustPending = true
	C_Timer.After(0, function()
		button._eqolFavoriteAdjustPending = nil
		AdjustFavoriteAnchorNow(button)
	end)
end

local function RGBToHex(r, g, b)
	if not r or not g or not b then return nil end
	return format("%02x%02x%02x", min(255, floor(r * 255 + 0.5)), min(255, floor(g * 255 + 0.5)), min(255, floor(b * 255 + 0.5)))
end

local function WrapColor(text, r, g, b)
	if not text or text == "" then return text end
	local hex = RGBToHex(r, g, b)
	if not hex then return text end
	return ("|cff%s%s|r"):format(hex, text)
end

local function ColorClientText(text, clientProgram)
	if not text or text == "" then return text end
	local color = CLIENT_COLORS[clientProgram] or CLIENT_COLORS[clientProgram and clientProgram:upper()]
	if color then return WrapColor(text, color.r, color.g, color.b) end
	return text
end

local function FormatLevel(level)
	if not level or level <= 0 then return nil end
	if not GetQuestDifficultyColor then return tostring(level) end
	local color = GetQuestDifficultyColor(level)
	if not color then return tostring(level) end
	return WrapColor(tostring(level), color.r, color.g, color.b)
end

local function GetClassColorFromToken(token)
	if not token or token == "" then return nil end
	local colorObj = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token)
	if colorObj and colorObj.r and colorObj.g and colorObj.b then return colorObj.r, colorObj.g, colorObj.b end
	if CUSTOM_CLASS_COLORS then
		local custom = CUSTOM_CLASS_COLORS[token]
		if custom and custom.r and custom.g and custom.b then return custom.r, custom.g, custom.b end
	end
	if RAID_CLASS_COLORS then
		local color = RAID_CLASS_COLORS[token]
		if color and color.r and color.g and color.b then return color.r, color.g, color.b end
	end
	return nil
end

local function ResolveClassToken(classToken, classID, localizedName)
	if type(classToken) == "string" and classToken ~= "" then
		local token = classToken
		if localizedClassMap[token] then token = localizedClassMap[token] end
		token = token:upper()
		local r = GetClassColorFromToken(token)
		if r then return token end
	end

	if classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
		local info = C_CreatureInfo.GetClassInfo(classID)
		if info and info.classFile and GetClassColorFromToken(info.classFile) then return info.classFile end
	end

	if type(localizedName) == "string" then
		local token = localizedClassMap[localizedName]
		if token and GetClassColorFromToken(token) then return token end
	end

	return nil
end

local function GetClassColor(classToken, classID, localizedName)
	local token = ResolveClassToken(classToken, classID, localizedName)
	if not token then return nil end
	return GetClassColorFromToken(token)
end

local function SetFactionIcon(button, factionName)
	if not button then return end
	local texture = button._eqolFactionIcon

	if factionName == nil then
		if texture then
			texture:SetTexture(nil)
			texture:Hide()
		end
		return
	end

	if not texture then
		texture = button:CreateTexture(nil, "OVERLAY", nil, 1)
		texture:SetSize(16, 16)
		if button.name and button.name.GetObjectType and button.name:GetObjectType() == "FontString" then
			texture:SetPoint("LEFT", button.name, "RIGHT", 4, 0)
		else
			texture:SetPoint("LEFT", button, "LEFT", 200, 0)
		end
		button._eqolFactionIcon = texture
	end

	local faction = NormalizeFactionName(factionName)
	local asset = faction and FACTION_ASSETS[faction] or nil

	if asset then
		local applied = false
		if asset.atlas and texture.SetAtlas then
			local ok = pcall(texture.SetAtlas, texture, asset.atlas)
			if ok then
				texture:SetTexCoord(0, 1, 0, 1)
				texture:Show()
				applied = true
			end
		end
		if not applied and asset.textures then
			for _, texturePath in ipairs(asset.textures) do
				if type(texturePath) == "string" and texturePath ~= "" then
					texture:SetTexCoord(0, 1, 0, 1)
					texture:SetTexture(texturePath)
					if texture:GetTexture() then
						texture:Show()
						applied = true
						break
					end
				end
			end
		end
		if not applied then
			texture:SetTexture(nil)
			texture:Hide()
		end
	else
		texture:SetTexture(nil)
		texture:Hide()
	end
end

local function ResetNameColor(button)
	if not button or not button.name then return end
	button.name._eqolNameColorR = nil
	button.name._eqolNameColorG = nil
	button.name._eqolNameColorB = nil
end

local function DecorateWoWFriend(button)
	if not FriendsListDecor.enabled then
		ResetNameColor(button)
		SetFactionIcon(button, nil)
		return
	end

	local nameFont = button and button.name
	local infoFont = button and button.info
	if not nameFont then return end
	if not C_FriendList or not C_FriendList.GetFriendInfoByIndex then return end

	local id = button.id
	if not id then
		nameFont:SetText("")
		if infoFont then infoFont:SetText("") end
		SetFactionIcon(button, nil)
		return
	end

	local info = C_FriendList.GetFriendInfoByIndex(id)
	if not info or not info.name then
		nameFont:SetText("")
		if infoFont then infoFont:SetText("") end
		SetFactionIcon(button, nil)
		return
	end

	local isConnected = info.connected == true
	local status
	if isConnected then
		if info.dnd then
			status = "DND"
		elseif info.afk then
			status = "AFK"
		else
			status = "Online"
		end
	else
		status = "Offline"
	end
	SetStatusIcon(button, status)

	local baseName, realm = strsplit("-", info.name, 2)
	baseName = baseName or info.name or ""
	local levelText = FormatLevel(info.level)

	local nameColored = baseName
	if isConnected then
		local localizedName = info.className or info.classLocalized or info.class
		local token = info.classTag or info.classFileName or info.classFile or info.classToken
		local r, g, b = GetClassColor(token, info.classID, localizedName)
		if not r and localizedName then
			r, g, b = GetClassColor(nil, info.classID, localizedName)
		end
		if r then nameColored = WrapColor(baseName, r, g, b) end
	else
		nameColored = WrapColor(baseName, 0.6, 0.6, 0.6)
	end

	local displayName = nameColored
	if levelText and levelText ~= "" then displayName = ("%s %s"):format(nameColored, levelText) end

	nameFont:SetText(displayName)
	ApplyNameFontOverride(button)
	if not isConnected then nameFont:SetTextColor(0.6, 0.6, 0.6) end

	if infoFont then
		local showLocation = IsLocationEnabled()
		local infoText
		if isConnected then
			if showLocation then infoText = BuildLocationText(info.area, realm) end
		else
			if info.notes and info.notes ~= "" then
				infoText = info.notes
			elseif showLocation then
				infoText = BuildLocationText(info.area, realm)
			end
		end
		infoFont:SetText(infoText or "")
	end

	SetFactionIcon(button, nil)

	if button.gameIcon then button.gameIcon:SetTexCoord(0, 1, 0, 1) end

	-- Favorite star spacing adjusted so text and icons stay readable
	AdjustFavoriteAnchor(button)
end

local function DecorateBNetFriend(button)
	if not C_BattleNet or not C_BattleNet.GetFriendAccountInfo then return end
	local nameFont = button and button.name
	local infoFont = button and button.info
	if not nameFont then return end

	local id = button.id
	if not id then
		nameFont:SetText("")
		if infoFont then infoFont:SetText("") end
		SetFactionIcon(button, nil)
		return
	end

	local accountInfo = C_BattleNet.GetFriendAccountInfo(id)
	if not accountInfo then
		nameFont:SetText("")
		if infoFont then infoFont:SetText("") end
		SetFactionIcon(button, nil)
		return
	end

	local gameInfo = accountInfo.gameAccountInfo
	local isOnline = gameInfo and gameInfo.isOnline == true
	local status
	if isOnline then
		if accountInfo.isDND or (gameInfo.isGameBusy == true) then
			status = "DND"
		elseif accountInfo.isAFK or (gameInfo.isGameAFK == true) then
			status = "AFK"
		else
			status = "Online"
		end
	else
		status = "Offline"
	end
	SetStatusIcon(button, status)

	local realID = accountInfo.accountName or (accountInfo.battleTag and accountInfo.battleTag:match("^[^#]+"))
	local displayName = realID or ""
	local infoText = ""
	local factionName = nil

	if gameInfo and gameInfo.clientProgram == BNET_CLIENT_WOW then
		local localizedName = gameInfo.className or gameInfo.classLocalized or gameInfo.class
		local token = gameInfo.classTag or gameInfo.classFile or gameInfo.classToken
		local charName = gameInfo.characterName or ""
		local levelText = FormatLevel(gameInfo.characterLevel)
		if levelText and levelText ~= "" then
			if charName ~= "" then
				charName = ("%s %s"):format(charName, levelText)
			else
				charName = levelText
			end
		end
		local r, g, b = GetClassColor(token, gameInfo.classID, localizedName)
		if r then charName = WrapColor(charName, r, g, b) end
		if TimerunningUtil_AddSmallIcon and gameInfo.timerunningSeasonID then charName = TimerunningUtil_AddSmallIcon(charName) or charName end

		local clientDisplay = ColorClientText(realID or "", gameInfo.clientProgram)
		if clientDisplay ~= "" and charName ~= "" then
			displayName = clientDisplay .. " || " .. charName
		elseif charName ~= "" then
			displayName = charName
		elseif clientDisplay ~= "" then
			displayName = clientDisplay
		end

		local showLocation = IsLocationEnabled()
		local location = showLocation and BuildLocationText(gameInfo.areaName, gameInfo.realmDisplayName) or nil
		if location and location ~= "" then
			infoText = location
		elseif showLocation then
			infoText = gameInfo.richPresence or ""
			if infoText == "" then infoText = accountInfo.note or "" end
		else
			infoText = accountInfo.note or ""
		end
		factionName = gameInfo.factionName
	else
		if gameInfo and gameInfo.clientProgram then
			displayName = ColorClientText(realID or "", gameInfo.clientProgram)
			if displayName == "" then displayName = realID or "" end
		end
		if displayName == "" then displayName = realID or "" end
		if gameInfo and gameInfo.richPresence then
			infoText = gameInfo.richPresence
		else
			infoText = accountInfo.note or ""
		end
	end

	nameFont:SetText(displayName)
	ApplyNameFontOverride(button)
	if not isOnline then nameFont:SetTextColor(0.6, 0.6, 0.6) end

	if infoFont then infoFont:SetText(infoText or "") end

	SetFactionIcon(button, factionName)

	if button.gameIcon then
		if gameInfo and gameInfo.clientTexture then
			button.gameIcon:SetTexture(gameInfo.clientTexture)
			button.gameIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		else
			button.gameIcon:SetTexCoord(0, 1, 0, 1)
		end
	end

	-- Favorite star spacing adjusted so text and icons stay readable
	AdjustFavoriteAnchor(button)
end

local function UpdateFriendButton(button)
	if not button or not button.buttonType then return end
	if not FriendsListDecor.enabled then
		local nameFont = button.name
		if nameFont and (nameFont._eqolNameColorR or nameFont._eqolNameColorG or nameFont._eqolNameColorB) then ResetNameColor(button) end
		if button._eqolFactionIcon then button._eqolFactionIcon:Hide() end
		RestoreNameFont(button)
		RestoreFavoriteAnchor(button)
		return
	end

	if button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
		DecorateWoWFriend(button)
	elseif button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
		DecorateBNetFriend(button)
	else
		if button._eqolFactionIcon then button._eqolFactionIcon:Hide() end
		if button.name and (button.name._eqolNameColorR or button.name._eqolNameColorG or button.name._eqolNameColorB) then ResetNameColor(button) end
		RestoreNameFont(button)
	end
end

local hookInstalled = false
local function EnsureHook()
	if hookInstalled then return true end
	if type(FriendsFrame_UpdateFriendButton) ~= "function" then return false end
	hooksecurefunc("FriendsFrame_UpdateFriendButton", UpdateFriendButton)
	hookInstalled = true
	return true
end

function FriendsListDecor:Refresh()
	if not hookInstalled then EnsureHook() end

	if not AreWoWFriendCountsReady() then
		ScheduleRefreshRetry()
		return
	end

	if FriendsList_UpdateFriends then
		FriendsList_UpdateFriends()
	elseif FriendsFrame_UpdateFriends then
		FriendsFrame_UpdateFriends()
	elseif FriendsList_Update then
		FriendsList_Update()
	elseif FriendsFrame and FriendsFrame.ScrollBox and FriendsFrame.ScrollBox.Update then
		FriendsFrame.ScrollBox:Update()
	end
end

function FriendsListDecor:SetEnabled(enabled)
	enabled = enabled and true or false
	if enabled == self.enabled then return end

	self.enabled = enabled
	EnsureHook()
	self:Refresh()
end

function FriendsListDecor:IsEnabled()
	return self.enabled == true
end

EnsureHook()
FriendsListDecor:SetEnabled(IsFeatureConfiguredEnabled())