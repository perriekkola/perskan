-- Loot roll placement and size, set in Edit Mode.
--
-- The need/greed/pass frames (GroupLootFrame1-4) stack inside GroupLootContainer, which
-- is a bottom-managed frame: BottomManagedFrameContainer lays it out above the action
-- bars with everything else in that stack, and re-anchors it (ClearAllPoints + SetPoint)
-- every time a roll opens or closes. The container is hidden while no roll is up, so
-- there is nothing to drag. Retail and WoW Forever share this code
-- (Blizzard_UIPanels_Game/Mainline/GroupLootFrame.*), so one implementation covers both.
--
-- So we own a stand-in: an invisible frame the size of one roll, shown with Edit Mode's
-- own selection art while Edit Mode is open and dragged there like any other system.
-- When the option is on, the container is pointed at the stand-in each time Blizzard
-- anchors it. Rolls stack upwards from its bottom edge, as they do by default, and the
-- alerts AlertFrame keeps above the rolls follow them.
--
-- Clicking the stand-in opens a settings panel of our own, laid out like Edit Mode's
-- system dialog (same border, slider and close button templates): a size slider, a
-- button that shows four sample rolls stacked exactly as real ones would be, and a
-- reset. The samples are our own frames drawn with the roll frame's own art; the real
-- GroupLootFrames can't be shown without a live roll ID behind them.
--
-- Size is SetScale on the roll frames themselves (they are children of UIParent, only
-- anchored to the container) and on the container, so the stack's spacing and the
-- container's height scale with them.
--
-- Taint: no field is written onto GroupLootContainer. ignoreFramePositionManager or
-- ignoreInLayout would take it out of the managed stack cleanly, but both are read
-- inside Blizzard's layout execution, which would then run tainted (the objective
-- tracker rule in CLAUDE.md). The cost of keeping out is that the stack still reserves
-- the container's height at its old spot while a roll is open - as it always has.
-- Edit Mode is followed with hooksecurefunc rather than an EventRegistry callback,
-- because a callback runs as part of Blizzard's EnterEditMode and leaves it tainted.
-- Nothing is hooked until the option is first switched on.
--
-- The position lives in the profile, not in an Edit Mode layout: Edit Mode's layouts
-- only hold Blizzard's own systems.

local ROLL_WIDTH = 277   -- GroupLootFrameTemplate's width
local ROLL_HEIGHT = 67   -- and height
local ROLL_SLOT = 100    -- GroupLootContainer.reservedSize: the stack's step per roll
local NUM_ROLLS = 4      -- NUM_GROUP_LOOT_FRAMES
local TITLE = "Loot Rolls"

local function profile() return Perskan.db.profile end

local mover
local dialog
local samples = {}
local samplesShown = false
local anchoring = false
local containerHooked = false
local editModeHooked = false
local editing = false
-- The last anchor Blizzard gave the container, so switching off can hand it straight
-- back instead of leaving the rolls where we put them until the next one opens.
local blizzardPoint

local function Enabled()
    return profile().moveLootRolls and true or false
end

local function Scale()
    local scale = tonumber(profile().lootRollScale) or 1
    if scale < 0.5 then scale = 0.5 elseif scale > 2 then scale = 2 end
    return scale
end

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- An atlas this client lacks raises, so ask first and fall back to a file texture.
local function SetAtlasOr(texture, atlas, fallbackFile)
    if HasAtlas(atlas) then
        texture:SetAtlas(atlas)
    elseif fallbackFile then
        texture:SetTexture(fallbackFile)
    end
end

--------------------------------------------------------------------------------
-- The stand-in
--------------------------------------------------------------------------------

-- Edit Mode's selection border, the same nine-slice its own systems draw. The layout is
-- local to Blizzard_EditMode, so it is repeated here. Not EditModeSystemSelectionTemplate
-- itself: its click and drag scripts hand our frame to EditModeManagerFrame:SelectSystem,
-- which would run Blizzard's selection code with our taint on a frame it doesn't know.
local SELECTION_LAYOUT = {
    TopRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
    TopLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
    BottomLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
    BottomRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
    TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
    BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
    LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
    RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
    Center = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}

local HIGHLIGHT_KIT = "editmode-actionbar-highlight"
local SELECTED_KIT = "editmode-actionbar-selected"

-- Paint a frame with one of the selection kits, falling back to a plain tint where the
-- client lacks the atlases.
local function ApplySelectionArt(frame, kit)
    if NineSliceUtil and NineSliceUtil.ApplyLayout and HasAtlas(kit .. "-NineSlice-Corner") then
        if pcall(NineSliceUtil.ApplyLayout, frame, SELECTION_LAYOUT, kit) then
            return
        end
    end
    if not frame._perskanFallback then
        local tex = frame:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        frame._perskanFallback = tex
    end
    if kit == SELECTED_KIT then
        frame._perskanFallback:SetColorTexture(1, 0.82, 0, 0.35)
    else
        frame._perskanFallback:SetColorTexture(0.25, 0.55, 1, 0.35)
    end
end

local function SavePosition()
    local point, _, relativePoint, x, y = mover:GetPoint(1)
    if not point then return end
    local db = profile()
    db.lootRollPoint = point
    db.lootRollRelativePoint = relativePoint
    db.lootRollX = math.floor(x + 0.5)
    db.lootRollY = math.floor(y + 0.5)
end

local function PlaceMover()
    local db = profile()
    local scale = Scale()
    -- One roll's footprint at the current size; rolls sit centred in it.
    mover:SetSize(ROLL_WIDTH * scale, ROLL_SLOT * scale)
    mover:ClearAllPoints()
    mover:SetPoint(db.lootRollPoint or "BOTTOM", UIParent, db.lootRollRelativePoint or "BOTTOM",
        db.lootRollX or 0, db.lootRollY or 0)
end

local OpenDialog, CloseDialog

local function SetSelected(selected)
    mover.selected = selected
    ApplySelectionArt(mover.Selection, selected and SELECTED_KIT or HIGHLIGHT_KIT)
    mover.Selection.Label:SetShown(not selected)
end

local function EnsureMover()
    if mover then return mover end

    mover = CreateFrame("Frame", "PerskanLootRollMover", UIParent)
    mover:SetFrameStrata("MEDIUM")
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:SetDontSavePosition(true)
    PlaceMover()

    -- What Edit Mode shows: the selection box and its name, the way Blizzard's own
    -- systems look. Hidden outside Edit Mode, and the anchor itself stays put so the
    -- rolls have somewhere to go.
    local selection = CreateFrame("Frame", nil, mover, "NineSliceCodeTemplate")
    selection:SetAllPoints()
    selection:SetFrameLevel(1000)
    selection:EnableMouse(true)
    selection:RegisterForDrag("LeftButton")
    selection:Hide()
    mover.Selection = selection

    local hover = CreateFrame("Frame", nil, selection, "NineSliceCodeTemplate")
    hover:SetAllPoints()
    hover:SetAlpha(0.4)
    hover:Hide()
    ApplySelectionArt(hover, HIGHLIGHT_KIT)
    for _, region in ipairs({ hover:GetRegions() }) do
        if region.SetBlendMode then region:SetBlendMode("ADD") end
    end
    selection.Hover = hover

    local label = selection:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("CENTER")
    label:SetText(TITLE)
    selection.Label = label

    SetSelected(false)

    selection:SetScript("OnEnter", function(self)
        self.Hover:Show()
        if not mover.selected then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(TITLE)
            GameTooltip:AddLine("Click for settings, drag to move.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    selection:SetScript("OnLeave", function(self)
        self.Hover:Hide()
        GameTooltip:Hide()
    end)
    selection:SetScript("OnMouseDown", function()
        GameTooltip:Hide()
        OpenDialog()
    end)
    selection:SetScript("OnDragStart", function()
        mover:StartMoving()
    end)
    selection:SetScript("OnDragStop", function()
        mover:StopMovingOrSizing()
        SavePosition()
        PlaceMover()
        Perskan:ApplyLootRollPosition()
    end)

    return mover
end

--------------------------------------------------------------------------------
-- Sample rolls
--------------------------------------------------------------------------------

-- A handful of items to show, by icon, quality and name. Nothing is looked up: these
-- only have to look like rolls.
local SAMPLE_ITEMS = {
    { icon = 135349, quality = 4, name = "Gleaming Ceremonial Blade" },
    { icon = 133129, quality = 3, name = "Crown of the Silver Wake" },
    { icon = 132661, quality = 2, name = "Weathered Iron Gauntlets" },
    { icon = 134937, quality = 4, name = "Sealed Treasure Map" },
}

local function QualityColor(quality)
    if C_Item and C_Item.GetItemQualityColor then
        local ok, r, g, b = pcall(C_Item.GetItemQualityColor, quality)
        if ok and r then return r, g, b end
    end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function RollButtonTexture(parent, atlas)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(32, 32)
    SetAtlasOr(tex, atlas)
    return tex
end

-- The art of GroupLootFrameTemplate (Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml),
-- rebuilt from the same textures and atlases at the same sizes.
local function CreateSample(index)
    local item = SAMPLE_ITEMS[index]
    local frame = CreateFrame("Frame", nil, mover)
    frame:SetSize(ROLL_WIDTH, ROLL_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\LootFrame\\LootToast")
    bg:SetTexCoord(0.28222656, 0.55273438, 0.30859375, 0.57031250)

    local border = frame:CreateTexture(nil, "BORDER")
    border:SetSize(286, 76)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\LootFrame\\LootToast")
    border:SetTexCoord(0.00097656, 0.28027344, 0.43750000, 0.73437500)

    local r, g, b = QualityColor(item.quality)
    border:SetVertexColor(r, g, b)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("TOPLEFT", bg, "TOPLEFT", 10, -13)
    icon:SetTexture(item.icon)

    local iconBorder = frame:CreateTexture(nil, "OVERLAY")
    iconBorder:SetSize(42, 42)
    iconBorder:SetPoint("CENTER", icon, "CENTER")
    SetAtlasOr(iconBorder, "loottoast-itemborder-green")
    iconBorder:SetVertexColor(r, g, b)

    local name = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetSize(125, 30)
    name:SetJustifyH("LEFT")
    name:SetJustifyV("MIDDLE")
    name:SetPoint("TOPLEFT", bg, "TOPLEFT", 60, -15)
    name:SetText(item.name)
    name:SetTextColor(r, g, b)

    local need = RollButtonTexture(frame, "lootroll-toast-icon-need-up")
    need:SetPoint("TOPRIGHT", -44, -6)
    local pass = RollButtonTexture(frame, "lootroll-toast-icon-pass-up")
    pass:SetPoint("LEFT", need, "RIGHT", 6, 2)
    local greed = RollButtonTexture(frame, "lootroll-toast-icon-greed-up")
    greed:SetPoint("TOP", need, "BOTTOM", 0, 5)

    local timer = CreateFrame("StatusBar", nil, frame)
    timer:SetSize(190, 8)
    timer:SetPoint("BOTTOMLEFT", 3, 2)
    timer:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    timer:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    timer:SetStatusBarColor(1, 1, 0)
    timer:SetMinMaxValues(0, 60)
    local timerBg = timer:CreateTexture(nil, "BACKGROUND")
    timerBg:SetAllPoints()
    timerBg:SetColorTexture(0, 0, 0)
    frame.Timer = timer

    -- Run the timer down and round again, staggered so the stack doesn't tick in step.
    frame.elapsed = (index - 1) * 12
    frame:SetScript("OnUpdate", function(self, delta)
        self.elapsed = (self.elapsed + delta) % 60
        self.Timer:SetValue(60 - self.elapsed)
    end)

    return frame
end

-- Placed the way GroupLootContainer_Update places the real ones: centred on the
-- container's bottom edge, one reserved slot up per roll, in the roll's own scale.
local function LayoutSamples()
    if not mover then return end
    local scale = Scale()
    for i = 1, NUM_ROLLS do
        local frame = samples[i]
        if frame then
            frame:SetScale(scale)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", mover, "BOTTOM", 0, ROLL_SLOT * (i - 0.5))
        end
    end
end

local function SetSamplesShown(shown)
    samplesShown = shown and true or false
    if samplesShown then
        EnsureMover()
        for i = 1, NUM_ROLLS do
            samples[i] = samples[i] or CreateSample(i)
        end
        LayoutSamples()
    end
    for i = 1, NUM_ROLLS do
        if samples[i] then samples[i]:SetShown(samplesShown) end
    end
    if dialog then
        dialog.TestButton:SetText(samplesShown and "Hide Test Rolls" or "Show Test Rolls")
    end
end

--------------------------------------------------------------------------------
-- Settings panel
--------------------------------------------------------------------------------

local DIALOG_WIDTH = 360

local function PositionDialog()
    dialog:ClearAllPoints()
    -- Beside the box, on whichever side has the room, as Edit Mode does.
    local centre = mover:GetCenter()
    if centre and centre > UIParent:GetWidth() / 2 then
        dialog:SetPoint("TOPRIGHT", mover, "TOPLEFT", -20, 0)
    else
        dialog:SetPoint("TOPLEFT", mover, "TOPRIGHT", 20, 0)
    end
end

local function BuildSlider(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(DIALOG_WIDTH - 40, 32)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetSize(100, 32)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT")
    label:SetText("Frame Size")

    local ok, slider = pcall(CreateFrame, "Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    if not ok or not slider or not slider.Init then
        return row
    end
    slider:SetSize(200, 32)
    slider:SetPoint("LEFT", label, "RIGHT", 5, 0)

    local formatters = {}
    if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
        and CreateMinimalSliderFormatter then
        local right = MinimalSliderWithSteppersMixin.Label.Right
        formatters[right] = CreateMinimalSliderFormatter(right, function(value)
            return ("%d%%"):format(math.floor(value * 100 + 0.5))
        end)
    end
    -- 50% to 200% in 5% steps.
    slider:Init(Scale(), 0.5, 2, 30, formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        value = math.floor(value * 20 + 0.5) / 20
        if value == Scale() then return end
        profile().lootRollScale = value
        Perskan:ApplyLootRollPosition()
        if Perskan.RefreshConfig then Perskan:RefreshConfig() end
    end, row)

    row.Slider = slider
    return row
end

local function BuildDialog()
    if dialog then return dialog end

    dialog = CreateFrame("Frame", "PerskanLootRollDialog", UIParent)
    dialog:SetSize(DIALOG_WIDTH, 210)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    dialog:SetClampedToScreen(true)
    dialog:SetMovable(true)
    dialog:SetDontSavePosition(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:Hide()

    -- Edit Mode's system dialog border, with the plain dialog border as a fallback.
    local ok, border = pcall(CreateFrame, "Frame", nil, dialog, "DialogBorderTranslucentTemplate")
    if not ok or not border then
        pcall(CreateFrame, "Frame", nil, dialog, "DialogBorderTemplate")
    end

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT")
    close:SetScript("OnClick", function() CloseDialog() end)

    local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText(TITLE)

    local slider = BuildSlider(dialog)
    slider:SetPoint("TOPLEFT", 20, -50)
    dialog.SizeRow = slider

    local test = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    test:SetSize(DIALOG_WIDTH - 40, 28)
    test:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -16)
    test:SetScript("OnClick", function() SetSamplesShown(not samplesShown) end)
    dialog.TestButton = test

    local divider = dialog:CreateTexture(nil, "ARTWORK")
    divider:SetSize(DIALOG_WIDTH - 60, 16)
    divider:SetPoint("TOP", test, "BOTTOM", 0, -6)
    SetAtlasOr(divider, "editmode-divider", "Interface\\Common\\UI-TooltipDivider-Transparent")

    local reset = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    reset:SetSize(DIALOG_WIDTH - 40, 28)
    reset:SetPoint("TOPLEFT", test, "BOTTOMLEFT", 0, -28)
    reset:SetText("Reset To Default Position")
    reset:SetScript("OnClick", function() Perskan:ResetLootRollPosition() end)

    SetSamplesShown(samplesShown)
    return dialog
end

function OpenDialog()
    if not mover then return end
    BuildDialog()
    SetSelected(true)
    local row = dialog.SizeRow
    if row.Slider then row.Slider:SetValue(Scale()) end
    PositionDialog()
    dialog:Show()
end

function CloseDialog()
    if dialog then dialog:Hide() end
    if mover then SetSelected(false) end
end

--------------------------------------------------------------------------------
-- Pointing the roll frames at it
--------------------------------------------------------------------------------

-- The frames that take a slot in the container: the four rolls, and the bonus-roll
-- results Blizzard swaps into a slot in their place.
local function RollFrames()
    local frames = {}
    for i = 1, NUM_ROLLS do
        frames[#frames + 1] = _G["GroupLootFrame" .. i]
    end
    frames[#frames + 1] = _G.BonusRollLootWonFrame
    frames[#frames + 1] = _G.BonusRollMoneyWonFrame
    return frames
end

local function ApplyScale(scale)
    local container = _G.GroupLootContainer
    if container then container:SetScale(scale) end
    for _, frame in ipairs(RollFrames()) do
        frame:SetScale(scale)
    end
end

local function AnchorContainer()
    local container = _G.GroupLootContainer
    if not container or not mover then return end
    anchoring = true
    container:ClearAllPoints()
    container:SetPoint("BOTTOM", mover, "BOTTOM", 0, 0)
    anchoring = false
end

local function HookContainer()
    if containerHooked then return end
    local container = _G.GroupLootContainer
    if not container then return end
    containerHooked = true

    -- The managed stack's layout clears the container's points and sets fresh ones on
    -- every roll; take them back straight after. Our own SetPoint comes through here
    -- too, which is what `anchoring` is for.
    hooksecurefunc(container, "SetPoint", function(self, ...)
        if anchoring then return end
        blizzardPoint = { ... }
        if Enabled() then
            AnchorContainer()
        end
    end)
end

-- Hand the container back to the anchor Blizzard last gave it, at Blizzard's size. The
-- stack lays it out again on the next roll either way.
local function ReleaseContainer()
    ApplyScale(1)
    local container = _G.GroupLootContainer
    if not container or not blizzardPoint then return end
    anchoring = true
    container:ClearAllPoints()
    pcall(container.SetPoint, container, unpack(blizzardPoint))
    anchoring = false
end

--------------------------------------------------------------------------------
-- Edit Mode
--------------------------------------------------------------------------------

local function ShowInEditMode()
    if not mover then return end
    local show = editing and Enabled()
    if not show then
        CloseDialog()
        SetSamplesShown(false)
    end
    mover.Selection:SetShown(show)
end

local function HookEditMode()
    if editModeHooked then return end
    local manager = _G.EditModeManagerFrame
    if not (manager and manager.EnterEditMode and manager.ExitEditMode) then return end
    editModeHooked = true

    hooksecurefunc(manager, "EnterEditMode", function()
        editing = true
        ShowInEditMode()
    end)
    hooksecurefunc(manager, "ExitEditMode", function()
        editing = false
        ShowInEditMode()
    end)
    -- Picking one of Blizzard's systems puts its own panel up; take ours down, as
    -- selecting another system does with Blizzard's.
    if manager.SelectSystem then
        hooksecurefunc(manager, "SelectSystem", function()
            if Enabled() then CloseDialog() end
        end)
    end

    if manager.IsEditModeActive then
        local ok, active = pcall(manager.IsEditModeActive, manager)
        editing = ok and active and true or false
    end
end

--------------------------------------------------------------------------------
-- Live apply
--------------------------------------------------------------------------------

function Perskan:ApplyLootRollPosition()
    if not Enabled() then
        -- Never switched on this session: nothing was hooked, moved or scaled.
        if mover then
            ShowInEditMode()
            ReleaseContainer()
        end
        return
    end

    EnsureMover()
    PlaceMover()
    HookContainer()
    HookEditMode()
    ShowInEditMode()
    ApplyScale(Scale())
    LayoutSamples()

    local container = _G.GroupLootContainer
    if container and container:IsShown() then
        AnchorContainer()
    end
end

-- Position and size back to their defaults.
function Perskan:ResetLootRollPosition()
    local db = profile()
    db.lootRollPoint = nil
    db.lootRollRelativePoint = nil
    db.lootRollX = nil
    db.lootRollY = nil
    db.lootRollScale = nil
    if dialog and dialog.SizeRow.Slider then
        dialog.SizeRow.Slider:SetValue(Scale())
    end
    if mover then
        self:ApplyLootRollPosition()
        if dialog and dialog:IsShown() then PositionDialog() end
    end
    if self.RefreshConfig then self:RefreshConfig() end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

Perskan:RegisterModule("LootRolls", function(self)
    self:ApplyLootRollPosition()

    -- Picks up Edit Mode or the loot frames if either wasn't there yet at login. A
    -- no-op while the option is off.
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function()
        if Enabled() then Perskan:ApplyLootRollPosition() end
    end)
end)
