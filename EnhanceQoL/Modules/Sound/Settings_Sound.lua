local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

if not addon.Sounds or not addon.Sounds.soundFiles then return end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Sound")
local LSM = LibStub("LibSharedMedia-3.0", true)

local function GetLabel(key) return L[key] or key end

local function IsPureNumbersTable(tbl)
	local hasEntries
	for _, v in pairs(tbl) do
		hasEntries = true
		if type(v) ~= "number" then return false end
	end
	return hasEntries and true or false
end

local function AllChildrenArePureNumbers(tbl)
	local hasEntries
	for _, child in pairs(tbl) do
		hasEntries = true
		if type(child) ~= "table" or not IsPureNumbersTable(child) then return false end
	end
	return hasEntries and true or false
end

local cSound = addon.SettingsLayout.rootSOUND
addon.SettingsLayout.soundCategory = cSound

local audioDeviceExpandable = addon.functions.SettingsCreateExpandableSection(cSound, {
	name = L["audioDeviceSection"] or "Audio device",
	expanded = false,
	colorizeTitle = false,
})

local function CreateAudioCheckbox(data)
	data.parentSection = audioDeviceExpandable
	return addon.functions.SettingsCreateCheckbox(cSound, data)
end

CreateAudioCheckbox({
	var = "keepAudioSynced",
	text = L["keepAudioSynced"] or "Keep audio synced",
	desc = L["keepAudioSyncedDesc"],
	func = function(value)
		addon.db.keepAudioSynced = value and true or false
		if addon.Sounds and addon.Sounds.functions and addon.Sounds.functions.UpdateAudioSync then addon.Sounds.functions.UpdateAudioSync() end
	end,
	default = false,
})

local soundExpandable = addon.functions.SettingsCreateExpandableSection(cSound, {
	name = L["soundMuteSection"] or "Sounds to mute",
	expanded = false,
	colorizeTitle = false,
})

local function CreateHeadline(text) addon.functions.SettingsCreateHeadline(cSound, text, { parentSection = soundExpandable }) end

local function CreateCheckbox(data)
	data.parentSection = soundExpandable
	return addon.functions.SettingsCreateCheckbox(cSound, data)
end

CreateHeadline(L["soundMuteExplained"])

local headlineCache = {}
local function EnsureHeadlineForPath(path)
	local key = table.concat(path, "/")
	if headlineCache[key] then return end
	headlineCache[key] = true
	local label = GetLabel(path[#path])
	CreateHeadline(label)
end

local function SortKeys(keys)
	table.sort(keys, function(a, b)
		local la, lb = GetLabel(a), GetLabel(b)
		if la == lb then return tostring(a) < tostring(b) end
		return la < lb
	end)
end

local function AddSoundOptions(path, data)
	if type(data) ~= "table" then return false end

	if IsPureNumbersTable(data) then
		local varName = "sounds_" .. table.concat(path, "_")
		local label = GetLabel(path[#path])
		local soundList = data
		CreateCheckbox({
			var = varName,
			text = label,
			func = function(value)
				addon.db[varName] = value and true or false
				for _, soundID in ipairs(soundList) do
					if value then
						MuteSoundFile(soundID)
					else
						UnmuteSoundFile(soundID)
					end
				end
			end,
			default = false,
		})
		return true
	end

	if AllChildrenArePureNumbers(data) then
		local keys = {}
		for key in pairs(data) do
			table.insert(keys, key)
		end
		SortKeys(keys)

		if #path == 1 then
			local needHeadline
			for _, key in ipairs(keys) do
				local child = data[key]
				if type(child) == "table" and IsPureNumbersTable(child) then
					needHeadline = true
					break
				end
			end
			if needHeadline then EnsureHeadlineForPath(path) end

			local created = false
			for _, key in ipairs(keys) do
				table.insert(path, key)
				if AddSoundOptions(path, data[key]) then created = true end
				table.remove(path)
			end
			return created
		end

		local created = false
		local groupKey = table.concat(path, "_")
		if #keys > 0 then EnsureHeadlineForPath(path) end
		for _, key in ipairs(keys) do
			local varName = "sounds_" .. groupKey .. "_" .. key
			local label = GetLabel(key)
			local soundList = data[key]

			CreateCheckbox({
				var = varName,
				text = label,
				func = function(value)
					addon.db[varName] = value and true or false
					if type(soundList) == "table" then
						for _, soundID in ipairs(soundList) do
							if value then
								MuteSoundFile(soundID)
							else
								UnmuteSoundFile(soundID)
							end
						end
					end
				end,
				default = false,
			})
			created = true
		end
		return created
	end

	local created = false
	local children = {}
	for key, value in pairs(data) do
		if type(value) == "table" then table.insert(children, key) end
	end
	SortKeys(children)

	for _, key in ipairs(children) do
		table.insert(path, key)
		if AddSoundOptions(path, data[key]) then created = true end
		table.remove(path)
	end
	return created
end

local topKeys = {}
for key in pairs(addon.Sounds.soundFiles) do
	table.insert(topKeys, key)
end
SortKeys(topKeys)

for _, treeKey in ipairs(topKeys) do
	AddSoundOptions({ treeKey }, addon.Sounds.soundFiles[treeKey])
end

local extraSoundExpandable = addon.functions.SettingsCreateExpandableSection(cSound, {
	name = L["soundExtraSection"] or "Additional sounds",
	expanded = false,
	colorizeTitle = false,
})

local function buildExtraSoundOptions()
	local entries = {
		{ value = "", label = L["soundExtraNone"] or NONE },
	}
	local sounds = (LSM and LSM:List("sound")) or {}
	table.sort(sounds, function(a, b) return tostring(a) < tostring(b) end)
	for _, name in ipairs(sounds) do
		if name ~= "" and name ~= "None" and name ~= NONE and name ~= (L["soundExtraNone"] or NONE) then entries[#entries + 1] = { value = name, label = name } end
	end
	return entries
end

local function getExtraSound(eventName)
	local mapping = addon.db and addon.db.soundExtraEvents
	return (mapping and mapping[eventName]) or ""
end

local function setExtraSound(eventName, value)
	addon.db.soundExtraEvents = addon.db.soundExtraEvents or {}
	if not value or value == "" then
		addon.db.soundExtraEvents[eventName] = nil
	else
		addon.db.soundExtraEvents[eventName] = value
	end
	if addon.Sounds and addon.Sounds.functions and addon.Sounds.functions.UpdateExtraSounds then addon.Sounds.functions.UpdateExtraSounds() end
end

local extraEnable = addon.functions.SettingsCreateCheckbox(cSound, {
	var = "soundExtraEnabled",
	text = L["soundExtraEnable"] or "Enable extra sounds",
	desc = L["soundExtraEnableDesc"],
	func = function(value)
		addon.db.soundExtraEnabled = value and true or false
		if addon.Sounds and addon.Sounds.functions and addon.Sounds.functions.UpdateExtraSounds then addon.Sounds.functions.UpdateExtraSounds() end
	end,
	default = false,
	parentSection = extraSoundExpandable,
})

local function isExtraEnabled() return addon.db and addon.db.soundExtraEnabled == true end

local extraEvents = addon.Sounds and addon.Sounds.extraSoundEvents
if type(extraEvents) == "table" then
	local ordered = {}
	for _, entry in ipairs(extraEvents) do
		local eventName = entry and entry.event
		if type(eventName) == "string" and eventName ~= "" then
			local label = (entry.label and L[entry.label]) or entry.label or eventName
			ordered[#ordered + 1] = {
				event = eventName,
				label = label,
				sortKey = string.lower(tostring(label or "")),
			}
		end
	end
	table.sort(ordered, function(a, b)
		if a.sortKey == b.sortKey then return tostring(a.event or "") < tostring(b.event or "") end
		return a.sortKey < b.sortKey
	end)
	for _, entry in ipairs(ordered) do
		local eventName = entry.event
		local label = entry.label or eventName
		local varName = "soundExtraEvent_" .. eventName
		addon.functions.SettingsCreateSoundDropdown(cSound, {
			var = varName,
			text = label,
			listFunc = buildExtraSoundOptions,
			default = "",
			get = function() return getExtraSound(eventName) end,
			set = function(value) setExtraSound(eventName, value) end,
			parent = true,
			element = extraEnable.element,
			parentCheck = isExtraEnabled,
			parentSection = extraSoundExpandable,
			placeholderText = L["soundExtraNone"] or NONE,
			playbackChannel = "Master",
		})
		addon.functions.SettingsAttachNotify(extraEnable.setting, varName)
	end
end
