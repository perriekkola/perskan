-- A bigger merchant window: more items per page, in a grid you choose.
--
-- The grid works the way Blizzard's own does - MERCHANT_ITEMS_PER_PAGE drives both the
-- layout and every index calculation in MerchantFrame_UpdateMerchantInfo, so raising it
-- and adding matching MerchantItem frames keeps buying, tooltips and paging consistent
-- with the stock UI. Nothing here remaps a merchant index, and Blizzard's own search box
-- and specialization filter are left alone.
--
-- Deliberately minimal beyond that: the merchant frame's own pieces (item inset, money
-- frame, buyback slot, repair buttons, page buttons) are all anchored to the frame's
-- edges already, so they follow it when it grows. Re-anchoring them by hand only added
-- insets that didn't belong.

local DEFAULT_COLUMNS, DEFAULT_ROWS = 2, 5
local BUYBACK_COLUMNS, BUYBACK_ROWS = 2, 6

-- Where MerchantItem1 sits inside the frame, and the gaps between slots, taken from the
-- stock layout so a default-sized grid lands where Blizzard puts it.
local FIRST_X, FIRST_Y = 11, -69
local GAP_X, GAP_Y = 12, 8
local BUYBACK_GAP_Y = 15

local originalWidth, originalHeight
local itemWidth, itemHeight
local slots = {}
local layoutHooked = false

local function GridSize()
    -- The module only runs when the feature is on (it's registered against that profile
    -- key), so there's no "off" grid to fall back to: switching it off reloads into a
    -- stock merchant frame rather than unpicking the layout at runtime.
    local profile = Perskan.db.profile
    return profile.vendorColumns or DEFAULT_COLUMNS, profile.vendorRows or DEFAULT_ROWS
end

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

-- Every slot the page size implies has to exist *before* MERCHANT_ITEMS_PER_PAGE claims
-- it: Blizzard's update walks 1..MERCHANT_ITEMS_PER_PAGE and indexes each slot's named
-- children, so raising the count first means it reaches a MerchantItem that isn't there
-- yet and errors out mid-update.
local function EnsureSlots(count)
    for i = 1, count do
        GetSlot(i)
    end
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

local function ApplyMerchantLayout()
    if not MerchantFrame or not itemWidth then return end

    -- Buyback is always Blizzard's 2x6 at the stock size; only the merchant tab is ours.
    local buyback = MerchantFrame.selectedTab == 2
    local columns, rows = GridSize()
    if buyback then
        columns, rows = BUYBACK_COLUMNS, BUYBACK_ROWS
    end

    EnsureSlots(columns * rows)

    MerchantFrame:SetSize(
        originalWidth + (columns - DEFAULT_COLUMNS) * (GAP_X + itemWidth),
        originalHeight + (rows - DEFAULT_ROWS) * (GAP_Y + itemHeight))

    LayoutGrid(columns, rows, buyback and BUYBACK_GAP_Y or GAP_Y)
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
    EnsureSlots(columns * rows)
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

    if not layoutHooked then
        layoutHooked = true
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", ApplyMerchantLayout)
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", ApplyMerchantLayout)
    end

    self:ApplyVendorLayout()
end, "extendedVendor")
