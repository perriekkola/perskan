-- BuffBarCooldownViewer positioning + ExtraQuestButton anchoring.
--
-- Settings that live here:
--   * anchorBuffBarsToWidgetFrame - park the viewer above the cast bar
--   * anchorExtraQuestButton      - park ExtraQuestButton above the cast bar
--   * collapseTrackedBarGaps      - close the holes inactive bars leave behind
--   * trackedBarSortMode          - order the visible bars by time remaining
--
-- The first two share the cast-bar anchor; the last two share the viewer's layout pass
-- (see the "Tracked bar stacking" section below).
--
-- The old code installed the cast-bar SetPoint hook and the login init twice (once
-- per anchor feature); this consolidates them into a single event frame and a single
-- hook. Repositioning is protected, so every path is guarded by InCombatLockdown and
-- reasserted on PLAYER_REGEN_ENABLED. These settings can't cleanly revert an
-- Edit-Mode-owned frame at runtime, so the settings window asks for a reload on change.

-- 12.1 removed UIParentBottomManagedFrameContainer; anchor to the player cast bar
-- (the frame this option is named for), falling back to UIParent.
local function GetBottomAnchorFrame()
    return PlayerCastingBarFrame or UIParent
end

local function RepositionBuffBarsAboveWidget()
    if not Perskan.db.profile.anchorBuffBarsToWidgetFrame then return end
    if not BuffBarCooldownViewer then return end
    if InCombatLockdown() then return end

    local anchor, yOffset
    if Perskan.db.profile.anchorExtraQuestButton and ExtraQuestButton and ExtraQuestButton:IsShown() then
        anchor, yOffset = ExtraQuestButton, 15
    else
        anchor, yOffset = GetBottomAnchorFrame(), 20
    end
    if not anchor then return end

    -- The cooldown viewer is an aura-driven Edit Mode system; SetPoint can raise a
    -- forbidden-aspect error under the 12.1 security model, so guard it.
    pcall(function()
        BuffBarCooldownViewer:ClearAllPoints()
        BuffBarCooldownViewer:SetPoint("BOTTOM", anchor, "TOP", 0, yOffset)
    end)

end

local function RepositionExtraQuestButton()
    if not Perskan.db.profile.anchorExtraQuestButton then return end
    if not ExtraQuestButton then return end
    if InCombatLockdown() then return end

    local anchor = GetBottomAnchorFrame()
    if not anchor then return end

    ExtraQuestButton:ClearAllPoints()
    ExtraQuestButton:SetPoint("BOTTOM", anchor, "TOP", 0, 20)

    RepositionBuffBarsAboveWidget()
end

-- Reassert every managed position.
local function RepositionAll()
    RepositionExtraQuestButton()
    RepositionBuffBarsAboveWidget()
end

--------------------------------------------------------------------------------
-- Tracked bar stacking: gap removal + duration sorting
--------------------------------------------------------------------------------
-- Blizzard hides a bar as soon as its aura drops (CooldownViewerItemMixin:UpdateShownState)
-- but only re-runs the viewer's grid layout when the *number* of configured bars changes
-- (CooldownViewerMixin:RefreshLayout). Every bar still on screen therefore keeps the anchor
-- it was given by the last layout pass, which is why an inactive bar leaves a hole and each
-- bar keeps a fixed slot in the list.
--
-- The layout engine already skips hidden children (BaseLayoutMixin:AddLayoutChildren only
-- collects shown regions), so closing the gaps is nothing more than asking the viewer to lay
-- itself out again whenever a bar shows or hides. No bar is anchored by hand, which is what
-- makes this survive Blizzard's own refreshes - the addon's earlier attempt at this anchored
-- the bars itself and lost that race on every relayout.
--
-- Sorting rides on the same pass. Right after a layout the visible bars occupy the slots the
-- grid produced, so ordering them by time remaining is a permutation of those slot offsets.
-- layoutIndex is deliberately left alone: RefreshData maps cooldownIDs by it, so renumbering
-- it would shuffle which aura each bar displays.
--
-- Only unprotected frames are touched (the item frames come from the viewer's frame pool),
-- so unlike the anchoring above this needs no combat guard - which matters, because bars come
-- and go mostly in combat.

local SORT_INTERVAL = 0.2

local stack = {
    hooked = false,
    relayoutPending = false,
    appliedOrder = nil,
    -- Aura timers can be unreadable from addon code; one failure disables sorting for the
    -- session instead of throwing on every tick.
    sortUnavailable = false,
    ticker = nil,
}

local function GapsCollapsed()
    return Perskan.db.profile.collapseTrackedBarGaps
end

local function SortMode()
    return Perskan.db.profile.trackedBarSortMode or "default"
end

local function SortingOn()
    return GapsCollapsed() and SortMode() ~= "default" and not stack.sortUnavailable
end

local function StackingOn()
    return GapsCollapsed()
end

-- Seconds left on a bar. Auras with no timer (expirationTime 0) and anything already
-- expired sort to the end of the list.
local function TimeRemaining(itemFrame)
    if type(itemFrame.GetCooldownValues) ~= "function" then return math.huge end

    local expirationTime = itemFrame:GetCooldownValues()
    if type(expirationTime) ~= "number" or expirationTime == 0 then return math.huge end

    local remaining = expirationTime - GetTime()
    return remaining > 0 and remaining or math.huge
end

-- The order the visible bars should appear in, or nil to leave Blizzard's order alone.
local function ComputeOrder(frames)
    if not SortingOn() then return nil end

    local shortestFirst = SortMode() ~= "longest"
    local remaining, order = {}, {}
    for i, itemFrame in ipairs(frames) do
        order[i] = itemFrame
        remaining[itemFrame] = TimeRemaining(itemFrame)
    end

    table.sort(order, function(a, b)
        local left, right = remaining[a], remaining[b]
        if left == right then
            -- Ties keep the Cooldown Manager's order so equal timers don't swap places.
            return (a.layoutIndex or 0) < (b.layoutIndex or 0)
        end
        if shortestFirst then return left < right end
        return left > right
    end)

    return order
end

local function SameOrder(a, b)
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- Runs straight after the viewer's grid layout, while the visible bars still sit in the
-- slots the grid just handed out.
local function ApplyBarOrder()
    local viewer = BuffBarCooldownViewer
    if not viewer or type(viewer.GetItemFrames) ~= "function" then return end

    local frames = viewer:GetItemFrames()
    if not frames or #frames == 0 then
        stack.appliedOrder = nil
        return
    end

    local ok, order = pcall(ComputeOrder, frames)
    if not ok then
        stack.sortUnavailable = true
        stack.appliedOrder = frames
        return
    end

    stack.appliedOrder = order or frames
    if not order or #order < 2 then return end

    -- Reuse the grid's own offsets rather than recomputing bar heights and padding.
    local slots = {}
    for i, itemFrame in ipairs(frames) do
        local point, relativeTo, relativePoint, x, y = itemFrame:GetPoint(1)
        if not point then return end
        slots[i] = { point, relativeTo, relativePoint, x, y }
    end

    for i, itemFrame in ipairs(order) do
        local slot = slots[i]
        itemFrame:ClearAllPoints()
        itemFrame:SetPoint(slot[1], slot[2], slot[3], slot[4], slot[5])
    end
end

local function RelayoutBars()
    local viewer = BuffBarCooldownViewer
    if not viewer or type(viewer.Layout) ~= "function" or not viewer:IsShown() then return end

    -- Blizzard's Layout compacts the visible bars; the hook below then reorders them.
    pcall(viewer.Layout, viewer)
end

-- Several bars can change visibility in the same aura update, so coalesce into one pass.
local function ScheduleRelayout()
    if not StackingOn() or stack.relayoutPending then return end

    stack.relayoutPending = true
    C_Timer.After(0, function()
        stack.relayoutPending = false
        RelayoutBars()
    end)
end

local function HookItemFrames()
    local viewer = BuffBarCooldownViewer
    local pool = viewer and viewer.itemFramePool
    if not pool or type(pool.EnumerateActive) ~= "function" then return end

    -- Frames are pooled and reused, so each one only ever needs hooking once.
    for itemFrame in pool:EnumerateActive() do
        if not itemFrame.perskanStackHooked then
            itemFrame.perskanStackHooked = true
            itemFrame:HookScript("OnShow", ScheduleRelayout)
            itemFrame:HookScript("OnHide", ScheduleRelayout)
        end
    end
end

local function SortTick(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < SORT_INTERVAL then return end
    self.elapsed = 0

    local viewer = BuffBarCooldownViewer
    if not viewer or type(viewer.GetItemFrames) ~= "function" or not viewer:IsShown() then return end

    local frames = viewer:GetItemFrames()
    if not frames or #frames < 2 then return end

    local ok, order = pcall(ComputeOrder, frames)
    if not ok then
        stack.sortUnavailable = true
        self:SetScript("OnUpdate", nil)
        return
    end

    -- Only relayout when the timers have actually crossed over.
    if order and not SameOrder(order, stack.appliedOrder) then
        RelayoutBars()
    end
end

local function UpdateSortTicker()
    if not stack.ticker then return end

    if SortingOn() then
        stack.ticker.elapsed = 0
        stack.ticker:SetScript("OnUpdate", SortTick)
    else
        stack.ticker:SetScript("OnUpdate", nil)
    end
end

local function EnsureStackingHooks()
    local viewer = BuffBarCooldownViewer
    if stack.hooked or not viewer or type(viewer.Layout) ~= "function" then return end
    stack.hooked = true

    hooksecurefunc(viewer, "Layout", function()
        if StackingOn() then pcall(ApplyBarOrder) end
    end)

    -- A relayout releases and re-acquires the item frames; pick up any new ones.
    if type(viewer.RefreshLayout) == "function" then
        hooksecurefunc(viewer, "RefreshLayout", HookItemFrames)
    end

    HookItemFrames()
end

-- Live apply. Turning the options off just stops the extra layout passes: Blizzard's own
-- fixed slots come back as soon as bars change again.
function Perskan:ApplyTrackedBarLayout()
    EnsureStackingHooks()
    UpdateSortTicker()
    RelayoutBars()
end

Perskan:RegisterModule("BuffBars", function(self)
    stack.ticker = CreateFrame("Frame")

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

    local initialized = false
    eventFrame:SetScript("OnEvent", function(_, event)
        if not (BuffBarCooldownViewer or ExtraQuestButton) then return end

        if not initialized then
            initialized = true

            -- Single cast-bar hook re-anchors everything when the bar re-lays-out
            -- (e.g. Edit Mode changes), replacing the two overlapping hooks the old
            -- code installed.
            local castBar = GetBottomAnchorFrame()
            if castBar and castBar ~= UIParent then
                hooksecurefunc(castBar, "SetPoint", function()
                    if not InCombatLockdown() then
                        RepositionAll()
                    end
                end)
            end

            -- ExtraQuestButton visibility affects the buff-bar anchor.
            if ExtraQuestButton then
                ExtraQuestButton:HookScript("OnShow", function()
                    if not InCombatLockdown() then RepositionBuffBarsAboveWidget() end
                end)
                ExtraQuestButton:HookScript("OnHide", function()
                    if not InCombatLockdown() then RepositionBuffBarsAboveWidget() end
                end)
            end

            RepositionAll()
        end

        -- The cooldown viewer can come up after the first event fires, and its item frames
        -- are pooled, so both are (re)checked on every event rather than once at login.
        if BuffBarCooldownViewer then
            EnsureStackingHooks()
            UpdateSortTicker()
            HookItemFrames()
        end

        if event == "PLAYER_REGEN_ENABLED" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
            RepositionAll()
        end

        if event == "PLAYER_ENTERING_WORLD" then
            ScheduleRelayout()
        end
    end)
end)
