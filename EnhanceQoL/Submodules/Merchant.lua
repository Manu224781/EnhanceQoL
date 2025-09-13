local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local MerchantMod = addon.Merchant or {}
addon.Merchant = MerchantMod

MerchantMod.enabled = MerchantMod.enabled or false
MerchantMod.hooked = MerchantMod.hooked or false
MerchantMod.originalItemsPerPage = MerchantMod.originalItemsPerPage or _G.MERCHANT_ITEMS_PER_PAGE or 10

-- local helpers (gated by self.enabled inside each)
local function RebuildMerchantFrame()
	if not MerchantMod.enabled or not MerchantFrame then return end
	MerchantFrame:SetWidth(696)
	for i = 1, MERCHANT_ITEMS_PER_PAGE do
		if not _G["MerchantItem" .. i] then CreateFrame("Frame", "MerchantItem" .. i, MerchantFrame, "MerchantItemTemplate") end
	end
end

local function UpdateSlotPositions()
	if not MerchantMod.enabled or not MerchantFrame then return end
	local vertSpacing = -16
	local horizSpacing = 12
	local perSubpage = MerchantMod.originalItemsPerPage or 10

	for i = 1, MERCHANT_ITEMS_PER_PAGE do
		local buy_slot = _G["MerchantItem" .. i]
		if buy_slot then
			buy_slot:Show()
			if (i % perSubpage) == 1 then
				if i == 1 then
					buy_slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 24, -70)
				else
					buy_slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - (perSubpage - 1))], "TOPRIGHT", 12, 0)
				end
			else
				if (i % 2) == 1 then
					buy_slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 2)], "BOTTOMLEFT", 0, vertSpacing)
				else
					buy_slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 1)], "TOPRIGHT", horizSpacing, 0)
				end
			end
		end
	end

	local numMerchantItems = securecall("GetMerchantNumItems")
	if numMerchantItems <= MERCHANT_ITEMS_PER_PAGE then
		MerchantPageText:Show()
		MerchantPrevPageButton:Show()
		MerchantPrevPageButton:Disable()
		MerchantNextPageButton:Show()
		MerchantNextPageButton:Disable()
	end
end

local function UpdateBuyBackSlotPositions()
	if not MerchantMod.enabled or not MerchantFrame then return end
	local vertSpacing = -30
	local horizSpacing = 50

	for i = 1, MERCHANT_ITEMS_PER_PAGE do
		local buyback_slot = _G["MerchantItem" .. i]
		if buyback_slot then
			if i > BUYBACK_ITEMS_PER_PAGE then
				buyback_slot:Hide()
			else
				if i == 1 then
					buyback_slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 64, -105)
				else
					if (i % 3) == 1 then
						buyback_slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 3)], "BOTTOMLEFT", 0, vertSpacing)
					else
						buyback_slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 1)], "TOPRIGHT", horizSpacing, 0)
					end
				end
			end
		end
	end
end

local function RebuildTokenPositions()
	if not MerchantMod.enabled or not MerchantFrame then return end
	local MerchantMoneyBg = _G.MerchantMoneyBg
	local MerchantMoneyInset = _G.MerchantMoneyInset
	local MerchantExtraCurrencyInset = _G.MerchantExtraCurrencyInset
	local MerchantExtraCurrencyBg = _G.MerchantExtraCurrencyBg

	if MerchantMoneyBg then
		MerchantMoneyBg:SetPoint("TOPRIGHT", MerchantFrame, "BOTTOMRIGHT", -8, 25)
		MerchantMoneyBg:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMRIGHT", -169, 6)
	end

	if MerchantExtraCurrencyInset and MerchantMoneyInset then
		MerchantExtraCurrencyInset:ClearAllPoints()
		MerchantExtraCurrencyInset:SetPoint("TOPLEFT", MerchantMoneyInset, "TOPLEFT", -171, 0)
		MerchantExtraCurrencyInset:SetPoint("BOTTOMRIGHT", MerchantMoneyInset, "BOTTOMLEFT", 0, 0)
	end

	if MerchantExtraCurrencyBg and MerchantMoneyBg then
		MerchantExtraCurrencyBg:ClearAllPoints()
		MerchantExtraCurrencyBg:SetPoint("TOPLEFT", MerchantMoneyBg, "TOPLEFT", -171, 0)
		MerchantExtraCurrencyBg:SetPoint("BOTTOMRIGHT", MerchantMoneyBg, "BOTTOMLEFT", -3, 0)
	end

	local currencies = { GetMerchantCurrencies() }
	MerchantFrame.numCurrencies = #currencies
	for index = 1, MerchantFrame.numCurrencies do
		local tokenButton = _G["MerchantToken" .. index]
		if tokenButton then
			tokenButton:ClearAllPoints()
			if index == 1 then
				tokenButton:SetPoint("BOTTOMRIGHT", -16, 8)
			elseif index == 4 then
				tokenButton:SetPoint("RIGHT", _G["MerchantToken" .. index - 1], "LEFT", -15, 0)
			else
				tokenButton:SetPoint("RIGHT", _G["MerchantToken" .. index - 1], "LEFT", 0, 0)
			end
		end
	end
end

local function RebuildSellAllJunkButtonPositions()
	if not MerchantMod.enabled then return end
	if not securecall("CanMerchantRepair") then
		local MerchantSellAllJunkButton = _G.MerchantSellAllJunkButton
		local MerchantBuyBackItem = _G.MerchantBuyBackItem
		if MerchantSellAllJunkButton and MerchantBuyBackItem then MerchantSellAllJunkButton:SetPoint("RIGHT", MerchantBuyBackItem, "LEFT", -18, 0) end
	end
end

local function RebuildGuildBankRepairButtonPositions()
	if not MerchantMod.enabled then return end
	local MerchantGuildBankRepairButton = _G.MerchantGuildBankRepairButton
	local MerchantRepairAllButton = _G.MerchantRepairAllButton
	if MerchantGuildBankRepairButton and MerchantRepairAllButton then MerchantGuildBankRepairButton:SetPoint("LEFT", MerchantRepairAllButton, "RIGHT", 10, 0) end
end

local function RebuildBuyBackItemPositions()
	if not MerchantMod.enabled then return end
	local MerchantBuyBackItem = _G.MerchantBuyBackItem
	local MerchantItem10 = _G.MerchantItem10
	if MerchantBuyBackItem and MerchantItem10 then MerchantBuyBackItem:SetPoint("TOPLEFT", MerchantItem10, "BOTTOMLEFT", 17, -20) end
end

local function RebuildPageButtonPositions()
	if not MerchantMod.enabled then return end
	MerchantPrevPageButton:SetPoint("CENTER", MerchantFrame, "BOTTOM", 36, 55)
	MerchantPageText:SetPoint("BOTTOM", MerchantFrame, "BOTTOM", 166, 50)
	MerchantNextPageButton:SetPoint("CENTER", MerchantFrame, "BOTTOM", 296, 55)
end

function MerchantMod:Enable()
	if self.enabled then return end
	self.enabled = true

	-- Expand to 20 items per page (2x10 grid)
	_G.MERCHANT_ITEMS_PER_PAGE = 20

	RebuildMerchantFrame()
	RebuildPageButtonPositions()
	RebuildBuyBackItemPositions()
	RebuildTokenPositions()
	RebuildGuildBankRepairButtonPositions()

	if not self.hooked then
		hooksecurefunc("MerchantFrame_UpdateRepairButtons", RebuildSellAllJunkButtonPositions)
		hooksecurefunc("MerchantFrame_UpdateMerchantInfo", UpdateSlotPositions)
		hooksecurefunc("MerchantFrame_UpdateBuybackInfo", UpdateBuyBackSlotPositions)
		self.hooked = true
	end

	-- Apply once if the frame is around
	if MerchantFrame then
		UpdateSlotPositions()
		UpdateBuyBackSlotPositions()
	end
end

function MerchantMod:Disable()
	if not self.enabled then return end
	self.enabled = false
	-- We deliberately do not attempt to revert all anchors here. A reload is recommended.
end
