local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Sound")
local LSM = LibStub("LibSharedMedia-3.0", true)

local function toggleSounds(sounds, state)
	if type(sounds) == "table" then
		for _, v in pairs(sounds) do
			if state then
				MuteSoundFile(v)
			else
				UnmuteSoundFile(v)
			end
		end
	end
end

-- hooksecurefunc("PlaySound", function(soundID, channel, forceNoDuplicates)
-- 	if addon.db["sounds_DebugEnabled"] then print("Sound played:", soundID, "on channel:", channel) end
-- end)

-- -- Hook für PlaySoundFile
-- hooksecurefunc("PlaySoundFile", function(soundFile, channel)
-- 	if addon.db["sounds_DebugEnabled"] then print("Sound file played:", soundFile, "on channel:", channel) end
-- end)

local function applyMutedSounds()
	if not addon.db or not addon.Sounds or not addon.Sounds.soundFiles then return end
	for topic in pairs(addon.Sounds.soundFiles) do
		if topic == "emotes" then
		elseif topic == "spells" then
			for spell in pairs(addon.Sounds.soundFiles[topic]) do
				if addon.db["sounds_mounts_" .. spell] then toggleSounds(addon.Sounds.soundFiles[topic][spell], true) end
			end
		elseif topic == "mounts" then
			for mount in pairs(addon.Sounds.soundFiles[topic]) do
				if addon.db["sounds_mounts_" .. mount] then toggleSounds(addon.Sounds.soundFiles[topic][mount], true) end
			end
		else
			for class in pairs(addon.Sounds.soundFiles[topic]) do
				for key in pairs(addon.Sounds.soundFiles[topic][class]) do
					if addon.db["sounds_" .. topic .. "_" .. class .. "_" .. key] then toggleSounds(addon.Sounds.soundFiles[topic][class][key], true) end
				end
			end
		end
	end
end

local function isFrameShown(frame) return frame and frame.IsShown and frame:IsShown() end

local function isCinematicPlaying() return isFrameShown(CinematicFrame) or isFrameShown(MovieFrame) end

local function applyAudioSync()
	if not SetCVar then return end
	SetCVar("Sound_OutputDriverIndex", "0")
	if Sound_GameSystem_RestartSoundSystem and not isCinematicPlaying() then Sound_GameSystem_RestartSoundSystem() end
end

local function resolveExtraSound(soundName)
	if not soundName or soundName == "" or not LSM then return end
	return LSM:Fetch("sound", soundName, true)
end

local function getExtraEventEntry(eventName)
	local events = addon.Sounds and addon.Sounds.extraSoundEvents
	if type(events) ~= "table" then return end
	for _, entry in ipairs(events) do
		if entry and entry.event == eventName then return entry end
	end
end

local extraSoundFrame
local function playExtraSound(event, ...)
	if not addon.db or addon.db.soundExtraEnabled ~= true then return end
	local entry = getExtraEventEntry(event)
	if entry and type(entry.condition) == "function" then
		if not entry.condition(event, ...) then return end
	end
	local mapping = addon.db.soundExtraEvents
	local soundName = mapping and mapping[event]
	if not soundName or soundName == "" then return end
	local file = resolveExtraSound(soundName)
	if file then PlaySoundFile(file, "Master") end
end

local audioSyncFrame

function addon.Sounds.functions.UpdateAudioSync()
	if not audioSyncFrame then
		audioSyncFrame = CreateFrame("Frame")
		audioSyncFrame:SetScript("OnEvent", function()
			if not addon.db or not addon.db.keepAudioSynced then return end
			applyAudioSync()
		end)
	end

	audioSyncFrame:UnregisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")

	if addon.db and addon.db.keepAudioSynced then
		audioSyncFrame:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")
		applyAudioSync()
	end
end

function addon.Sounds.functions.UpdateExtraSounds()
	if not addon.db or addon.db.soundExtraEnabled ~= true then
		if extraSoundFrame then extraSoundFrame:UnregisterAllEvents() end
		return
	end

	if not extraSoundFrame then
		extraSoundFrame = CreateFrame("Frame")
		extraSoundFrame:SetScript("OnEvent", function(_, event, ...) playExtraSound(event, ...) end)
	end

	extraSoundFrame:UnregisterAllEvents()

	local events = addon.Sounds and addon.Sounds.extraSoundEvents
	if type(events) ~= "table" then return end
	local mapping = addon.db.soundExtraEvents
	for _, entry in ipairs(events) do
		local eventName = entry and entry.event
		if type(eventName) == "string" and eventName ~= "" then
			local soundName = mapping and mapping[eventName]
			if soundName and soundName ~= "" then extraSoundFrame:RegisterEvent(eventName) end
		end
	end
end

function addon.Sounds.functions.InitState()
	applyMutedSounds()
	addon.Sounds.functions.UpdateAudioSync()
	if addon.Sounds.functions.UpdateExtraSounds then addon.Sounds.functions.UpdateExtraSounds() end
end
