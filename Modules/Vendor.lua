-- A bigger merchant window: more items per page, in a grid you choose.
--
-- The grid works the way Blizzard's own does - MERCHANT_ITEMS_PER_PAGE drives both the
-- layout and every index calculation in MerchantFrame_UpdateMerchantInfo, so changing it
-- and adding matching MerchantItem frames keeps buying, tooltips and paging consistent
-- with the stock UI. Nothing here remaps a merchant index, and Blizzard's own search box
-- and specialization filter are left exactly where they are.
--
-- Growing the frame is the easy half; the bottom of the merchant window is a fixed band
-- of insets that has to be rebuilt around the taller item area, and the arrangement here
-- follows the one Krowi's Extended Vendor UI arrived at (money strip across the bottom,
-- repair buttons and buyback slot in their own insets above it, the item inset ending
-- above those).

local DEFAULT_COLUMNS, DEFAULT_ROWS = 2, 5
local BUYBACK_COLUMNS, BUYBACK_ROWS = 2, 6

-- Where MerchantItem1 sits inside the frame, and the gaps between slots, taken from the
-- stock layout so a default-sized grid lands where Blizzard puts it.
local FIRST_X, FIRST_Y = 11, -69
local GAP_X, GAP_Y = 12, 8
local BUYBACK_GAP_Y = 15

local MONEY_INSET_HEIGHT = 22
local BUTTON_INSET_WIDTH, BUTTON_INSET_HEIGHT = 185, 52
local BUYBACK_INSET_WIDTH = 149

local originalWidth, originalHeight
local itemWidth, itemHeight
local slots = {}
local insets = {}
local layoutHooked = false
local bottomBuilt = false

local function Profile()
    return Perskan.db.profile
end

-- The module only runs when the feature is on (it's registered with that profile key), so
-- there's no "off" grid to fall back to here - switching it off reloads into a stock
-- merchant frame instead of trying to unpick the layout at runtime.
local function GridSize()
    local profile = Profile()
    return profile.vendorColumns or DEFAULT_COLUMNS, profile.vendorRows or DEFAULT_ROWS
end

--------------------------------------------------------------------------------
-- Item slots
--------------------------------------------------------------------------------

-- Blizzard creates MerchantItem1..12 in XML; anything past that is ours, built from the
-- same template so it behaves identically.
local function GetSlot(index)
    if slots[index] then
        return slots[index]
    end

    local slot = _G["MerchantItem" .. index]
    if not slot then
        slot = CreateFrame("Frame", "MerchantItem" .. index, MerchantFrame, "MerchantItemTemplate")
    end

    slots[index] = slot
    return slot
end

-- Column-major, matching the stock frame: 1-5 down the left, 6-10 down the right.
local function LayoutGrid(columns, rows, gapY)
    local index = 0
    for column = 1, columns do
        for row = 1, rows do
            index = index + 1
            local slot = GetSlot(index)
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT",
                FIRST_X + (column - 1) * (GAP_X + itemWidth),
                FIRST_Y - (row - 1) * (gapY + itemHeight))
            slot:Show()
        end
    end

    for i = index + 1, #slots do
        slots[i]:Hide()
    end
end

--------------------------------------------------------------------------------
-- Bottom band
--------------------------------------------------------------------------------

-- Money strip along the bottom, with the repair buttons and the buyback slot in insets
-- above it. Built once; the item inset is what moves when the grid changes size.
local function BuildBottomBand()
    if bottomBuilt or not MerchantMoneyInset then return end
    bottomBuilt = true

    MerchantMoneyInset:ClearAllPoints()
    MerchantMoneyInset:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -6, 8)
    MerchantMoneyInset:SetPoint("LEFT", MerchantFrame, "LEFT", 4, 0)
    MerchantMoneyInset:SetHeight(MONEY_INSET_HEIGHT)

    insets.buttons = CreateFrame("Frame", "PerskanMerchantButtonsInset", MerchantFrame, "InsetFrameTemplate")
    insets.buttons:SetPoint("BOTTOMLEFT", MerchantMoneyInset, "TOPLEFT", 0, 4)
    insets.buttons:SetSize(BUTTON_INSET_WIDTH, BUTTON_INSET_HEIGHT)

    insets.buyback = CreateFrame("Frame", "PerskanMerchantBuybackInset", MerchantFrame, "InsetFrameTemplate")
    insets.buyback:SetPoint("TOPLEFT", insets.buttons, "TOPRIGHT", 4, 0)
    insets.buyback:SetPoint("BOTTOMLEFT", insets.buttons, "BOTTOMRIGHT", 4, 0)
    insets.buyback:SetWidth(BUYBACK_INSET_WIDTH)

    -- Fills whatever width the wider grid leaves over, so the band reads as one row.
    insets.filler = CreateFrame("Frame", "PerskanMerchantFillerInset", MerchantFrame, "InsetFrameTemplate")
    insets.filler:SetPoint("TOPLEFT", insets.buyback, "TOPRIGHT", 4, 0)
    insets.filler:SetPoint("BOTTOMLEFT", insets.buyback, "BOTTOMRIGHT", 4, 0)
    insets.filler:SetPoint("RIGHT", MerchantMoneyInset, "RIGHT", 0, 0)

    -- Repair and junk buttons live in the left inset. Re-asserted through Blizzard's own
    -- update, which re-anchors them.
    local function PlaceRepairButtons()
        if not MerchantRepairAllButton then return end
        MerchantRepairAllButton:ClearAllPoints()
        MerchantRepairAllButton:SetPoint("LEFT", insets.buttons, "LEFT", 52, -1)
        if MerchantRepairItemButton then
            MerchantRepairItemButton:ClearAllPoints()
            MerchantRepairItemButton:SetPoint("RIGHT", MerchantRepairAllButton, "LEFT", -8, 0)
        end
        if MerchantGuildBankRepairButton then
            MerchantGuildBankRepairButton:ClearAllPoints()
            MerchantGuildBankRepairButton:SetPoint("LEFT", MerchantRepairAllButton, "RIGHT", 8, 0)
        end
        if MerchantSellAllJunkButton then
            MerchantSellAllJunkButton:ClearAllPoints()
            MerchantSellAllJunkButton:SetPoint("LEFT", MerchantGuildBankRepairButton or MerchantRepairAllButton,
                "RIGHT", 8, 0)
        end
    end
    PlaceRepairButtons()
    if type(MerchantFrame_UpdateRepairButtons) == "function" then
        hooksecurefunc("MerchantFrame_UpdateRepairButtons", PlaceRepairButtons)
    end
end

--------------------------------------------------------------------------------
-- Layout driver
--------------------------------------------------------------------------------

local function ApplyMerchantLayout()
    if not MerchantFrame or not itemWidth then return end

    local buyback = MerchantFrame.selectedTab == 2
    local columns, rows = GridSize()
    if buyback then
        columns, rows = BUYBACK_COLUMNS, BUYBACK_ROWS
    end

    for i = 1, columns * rows do
        GetSlot(i)
    end

    -- Height has to cover the taller grid plus the band that now sits below the item
    -- inset; without the money strip's share the last row lands on top of it.
    local extraColumns = columns - DEFAULT_COLUMNS
    local extraRows = rows - DEFAULT_ROWS
    local width = originalWidth + extraColumns * (GAP_X + itemWidth)
    local height = originalHeight + extraRows * (GAP_Y + itemHeight)
    if not buyback then
        height = height + MONEY_INSET_HEIGHT + BUTTON_INSET_HEIGHT - 23
        if MerchantPageText and not MerchantPageText:IsShown() then
            height = height - 36
        end
    end
    MerchantFrame:SetSize(width, height)

    LayoutGrid(columns, rows, buyback and BUYBACK_GAP_Y or GAP_Y)

    if MerchantFrameInset then
        MerchantFrameInset:ClearAllPoints()
        MerchantFrameInset:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 4, -60)
        MerchantFrameInset:SetPoint("RIGHT", MerchantFrame, "RIGHT", -6, 0)
        if buyback then
            MerchantFrameInset:SetPoint("BOTTOM", MerchantMoneyInset, "TOP", 0, 3)
        else
            MerchantFrameInset:SetPoint("BOTTOM", insets.buttons, "TOP", 0, 4)
        end
    end

    for _, inset in pairs(insets) do
        inset:SetShown(not buyback)
    end

    if MerchantBuyBackItem and insets.buyback then
        MerchantBuyBackItem:ClearAllPoints()
        if buyback then
            MerchantBuyBackItem:Hide()
        else
            MerchantBuyBackItem:SetPoint("LEFT", insets.buyback, "LEFT", 7, 0)
            MerchantBuyBackItem:Show()
        end
    end

    -- Paging controls hang off the item inset, which just moved.
    if MerchantPrevPageButton and MerchantFrameInset then
        MerchantPrevPageButton:ClearAllPoints()
        MerchantPrevPageButton:SetPoint("BOTTOMLEFT", MerchantFrameInset, "BOTTOMLEFT", 5, 2)
        MerchantNextPageButton:ClearAllPoints()
        MerchantNextPageButton:SetPoint("BOTTOMRIGHT", MerchantFrameInset, "BOTTOMRIGHT", -5, 2)
        MerchantPageText:ClearAllPoints()
        MerchantPageText:SetPoint("BOTTOM", MerchantFrameInset, "BOTTOM", 0, 6)
    end
end

function Perskan:ApplyVendorLayout()
    -- Defined at file scope, so it exists even when the module never ran; a profile
    -- switch must not start rebuilding a merchant frame the player switched off.
    if not MerchantFrame or not self.db.profile.extendedVendor then return end

    if not originalWidth then
        originalWidth, originalHeight = MerchantFrame:GetSize()
        itemWidth, itemHeight = MerchantItem1:GetSize()
    end

    local columns, rows = GridSize()
    MERCHANT_ITEMS_PER_PAGE = columns * rows
    -- A page count that just changed under the frame leaves MerchantFrame.page pointing
    -- past the end, which breaks the next/prev buttons until the window is reopened.
    MerchantFrame.page = 1

    if MerchantFrame:IsShown() and type(MerchantFrame_Update) == "function" then
        -- Re-run Blizzard's own update so the new page size is filled in properly.
        MerchantFrame_Update()
    else
        ApplyMerchantLayout()
    end
end

Perskan:RegisterModule("Vendor", function(self)
    if not MerchantFrame then return end

    originalWidth, originalHeight = MerchantFrame:GetSize()
    itemWidth, itemHeight = MerchantItem1:GetSize()

    for i = 1, 12 do
        local slot = _G["MerchantItem" .. i]
        if slot then slots[i] = slot end
    end

    BuildBottomBand()

    if not layoutHooked then
        layoutHooked = true
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", ApplyMerchantLayout)
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", ApplyMerchantLayout)
    end

    self:ApplyVendorLayout()
end, "extendedVendor")
