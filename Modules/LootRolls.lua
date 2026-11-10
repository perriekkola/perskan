-- Loot roll placement, moved in Edit Mode.
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

local ROLL_WIDTH = 256   -- GroupLootContainer's width
local ROLL_HEIGHT = 100  -- its reservedSize: one roll's slot

local function profile() return Perskan.db.profile end

local mover
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

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- Paint a frame with one of the selection kits, falling back to a plain tint where the
-- client lacks the atlases (an atlas this client doesn't have raises, so ask first).
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
    mover:ClearAllPoints()
    mover:SetPoint(db.lootRollPoint or "BOTTOM", UIParent, db.lootRollRelativePoint or "BOTTOM",
        db.lootRollX or 0, db.lootRollY or 0)
end

local function SetSelected(selected)
    mover.selected = selected
    ApplySelectionArt(mover.Selection, selected and SELECTED_KIT or HIGHLIGHT_KIT)
end

local function EnsureMover()
    if mover then return mover end

    mover = CreateFrame("Frame", "PerskanLootRollMover", UIParent)
    mover:SetSize(ROLL_WIDTH, ROLL_HEIGHT)
    mover:SetFrameStrata("MEDIUM")
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:SetDontSavePosition(true)
    PlaceMover()

    -- What Edit Mode shows: the selection box and its name, the way Blizzard's own
    -- systems look before one is picked. Hidden outside Edit Mode, and the anchor
    -- itself stays put so the rolls have somewhere to go.
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
    label:SetText(LOOT_ROLLS or "Loot Rolls")
    selection.Label = label

    SetSelected(false)

    selection:SetScript("OnEnter", function(self)
        self.Hover:Show()
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(LOOT_ROLLS or "Loot Rolls")
        GameTooltip:AddLine("Drag to move. Right-click to put it back.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    selection:SetScript("OnLeave", function(self)
        self.Hover:Hide()
        GameTooltip:Hide()
    end)
    selection:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            Perskan:ResetLootRollPosition()
        else
            SetSelected(true)
        end
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
-- Pointing the container at it
--------------------------------------------------------------------------------

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

-- Hand the container back to the anchor Blizzard last gave it. The stack lays it out
-- again on the next roll either way.
local function ReleaseContainer()
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
    if not show then SetSelected(false) end
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
        -- Never switched on this session: nothing was hooked or moved.
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

    local container = _G.GroupLootContainer
    if container and container:IsShown() then
        AnchorContainer()
    end
end

function Perskan:ResetLootRollPosition()
    local db = profile()
    db.lootRollPoint = nil
    db.lootRollRelativePoint = nil
    db.lootRollX = nil
    db.lootRollY = nil
    if mover then
        PlaceMover()
        self:ApplyLootRollPosition()
    end
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
