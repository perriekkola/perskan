-- A bigger merchant window: more items per page, in a grid you choose, plus a search
-- box that highlights matches on the page.
--
-- Written against Blizzard's merchant frame rather than ported from an addon. The grid
-- works the way Blizzard's own does - MERCHANT_ITEMS_PER_PAGE drives both the layout and
-- every index calculation in MerchantFrame_UpdateMerchantInfo, so changing it and adding
-- matching MerchantItem frames keeps buying, tooltips and paging consistent with the
-- stock UI. Nothing here remaps a merchant index, which is what keeps the buy path
-- exactly as Blizzard wrote it.

local DEFAULT_COLUMNS, DEFAULT_ROWS = 2, 5
local BUYBACK_COLUMNS, BUYBACK_ROWS = 2, 6

-- Where MerchantItem1 sits inside the frame, and the gaps between slots. Taken from the
-- stock layout so a default-sized grid lands exactly where Blizzard puts it.
local FIRST_X, FIRST_Y = 11, -69
local GAP_X, GAP_Y = 12, 8

local originalWidth, originalHeight
local itemWidth, itemHeight
local slots = {}
local searchBox
local layoutHooked = false

local function Profile()
    return Perskan.db.profile
end

local function GridSize()
    local profile = Profile()
    if not profile.extendedVendor then
        return DEFAULT_COLUMNS, DEFAULT_ROWS
    end
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

local function EnsureSlots(count)
    for i = 1, count do
        GetSlot(i)
    end
end

-- Column-major, matching the stock frame: 1-5 down the left, 6-10 down the right.
local function LayoutGrid(columns, rows, offsetY)
    local index = 0
    for column = 1, columns do
        for row = 1, rows do
            index = index + 1
            local slot = GetSlot(index)
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT",
                FIRST_X + (column - 1) * (GAP_X + itemWidth),
                FIRST_Y - (row - 1) * ((offsetY or GAP_Y) + itemHeight))
            slot:Show()
        end
    end

    -- Anything left over from a larger grid or the buyback tab.
    for i = index + 1, #slots do
        slots[i]:Hide()
    end
end

local function ResizeMerchantFrame(columns, rows)
    MerchantFrame:SetSize(
        originalWidth + (columns - DEFAULT_COLUMNS) * (GAP_X + itemWidth),
        originalHeight + (rows - DEFAULT_ROWS) * (GAP_Y + itemHeight))
end

--------------------------------------------------------------------------------
-- Search
--------------------------------------------------------------------------------

-- Deliberately a highlight rather than a filter: hiding non-matches would mean handing
-- out our own item indices, and every buy, tooltip and drag path would then have to be
-- re-pointed at them. Dimming leaves Blizzard's indices - and its buy path - untouched.
local function ApplySearchHighlight()
    if MerchantFrame.selectedTab ~= 1 then return end

    local term = searchBox and searchBox:GetText() or ""
    term = term:lower():trim()

    local perPage = MERCHANT_ITEMS_PER_PAGE or (DEFAULT_COLUMNS * DEFAULT_ROWS)
    local page = MerchantFrame.page or 1

    for i = 1, perPage do
        local slot = slots[i] or _G["MerchantItem" .. i]
        if slot and slot:IsShown() then
            local matched = true
            if term ~= "" then
                local name = GetMerchantItemInfo((page - 1) * perPage + i)
                matched = name and name:lower():find(term, 1, true) and true or false
            end
            slot:SetAlpha(matched and 1 or 0.25)
        end
    end
end

local function BuildSearchBox()
    if searchBox then return searchBox end

    local box = CreateFrame("EditBox", nil, MerchantFrame, "InputBoxTemplate")
    box:SetSize(140, 20)
    -- In the gap between the frame's title and the first row of items, clear of the
    -- stock filter dropdown in the top right.
    box:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 18, -44)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")

    local label = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    label:SetPoint("LEFT", box, "LEFT", 4, 0)
    label:SetText("Search")

    box:SetScript("OnTextChanged", function(self)
        label:SetShown(self:GetText() == "")
        ApplySearchHighlight()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    searchBox = box
    return box
end

--------------------------------------------------------------------------------
-- Layout driver
--------------------------------------------------------------------------------

local function ApplyMerchantLayout()
    if not MerchantFrame or not itemWidth then return end

    if MerchantFrame.selectedTab == 2 then
        -- Buyback is always Blizzard's 2x6; only the merchant tab is ours.
        MerchantFrame:SetSize(originalWidth, originalHeight)
        LayoutGrid(BUYBACK_COLUMNS, BUYBACK_ROWS, 15)
        if searchBox then searchBox:Hide() end
        return
    end

    local columns, rows = GridSize()
    EnsureSlots(columns * rows)
    ResizeMerchantFrame(columns, rows)
    LayoutGrid(columns, rows, GAP_Y)

    -- Paging controls hang off the frame's bottom edge, which just moved.
    if MerchantPrevPageButton and MerchantFrameInset then
        MerchantPrevPageButton:ClearAllPoints()
        MerchantPrevPageButton:SetPoint("BOTTOMLEFT", MerchantFrameInset, "BOTTOMLEFT", 5, 2)
        MerchantNextPageButton:ClearAllPoints()
        MerchantNextPageButton:SetPoint("BOTTOMRIGHT", MerchantFrameInset, "BOTTOMRIGHT", -5, 2)
        MerchantPageText:ClearAllPoints()
        MerchantPageText:SetPoint("BOTTOM", MerchantFrameInset, "BOTTOM", 0, 6)
    end

    if Profile().vendorSearch then
        BuildSearchBox():Show()
        ApplySearchHighlight()
    elseif searchBox then
        searchBox:SetText("")
        searchBox:Hide()
    end
end

function Perskan:ApplyVendorLayout()
    if not MerchantFrame then return end

    -- Measured once, before anything is moved, so "restore Blizzard's size" stays honest
    -- across repeated toggling.
    if not originalWidth then
        originalWidth, originalHeight = MerchantFrame:GetSize()
        itemWidth, itemHeight = MerchantItem1:GetSize()
    end

    local columns, rows = GridSize()
    MERCHANT_ITEMS_PER_PAGE = columns * rows

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
end)
