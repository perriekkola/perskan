-- BuffBarCooldownViewer positioning + ExtraQuestButton anchoring.
--
-- Three related settings live here because they share the cast-bar anchor and the
-- bar-sorting state:
--   * anchorBuffBarsToWidgetFrame - park the viewer above the cast bar
--   * anchorExtraQuestButton       - park ExtraQuestButton above the cast bar
--   * sortBuffBarsUpward           - stack active bars upward without gaps
--
-- The old code installed the cast-bar SetPoint hook and the login init twice (once
-- per anchor feature); this consolidates them into a single event frame and a single
-- hook. Repositioning is protected, so every path is guarded by InCombatLockdown and
-- reasserted on PLAYER_REGEN_ENABLED. These settings can't cleanly revert an
-- Edit-Mode-owned frame at runtime, so the settings window asks for a reload on change.

local sortState = {
    containers = {},
    containerHeight = nil,
    containerSpacing = 2,
    parentFrame = nil,
    layoutHooked = false,
    repositioning = false,
    blocked = false,
}

-- 12.1 removed UIParentBottomManagedFrameContainer; anchor to the player cast bar
-- (the frame this option is named for), falling back to UIParent.
local function GetBottomAnchorFrame()
    return PlayerCastingBarFrame or UIParent
end

local RepositionBuffBarContainers

-- The viewer's bars come from a frame pool that is released and re-acquired on every
-- RefreshLayout, so the set is re-read on each pass instead of cached once at login
-- (which is why the old collect-once version stopped finding any bars at all).
local function CollectBuffBarContainers()
    wipe(sortState.containers)

    sortState.parentFrame = BuffBarCooldownViewer
    if not sortState.parentFrame then return end

    for _, child in ipairs({ sortState.parentFrame:GetChildren() }) do
        if child.Icon and child.Bar then
            sortState.containers[#sortState.containers + 1] = child
            if not sortState.containerHeight then
                sortState.containerHeight = child:GetHeight()
            end

            if not child._perskanHooked then
                child._perskanHooked = true
                child:HookScript("OnShow", function() RepositionBuffBarContainers() end)
                child:HookScript("OnHide", function() RepositionBuffBarContainers() end)
            end
        end
    end

    -- GetChildren order follows pool creation, not display order; layoutIndex is what
    -- the viewer actually sorts by.
    table.sort(sortState.containers, function(a, b)
        return (a.layoutIndex or math.huge) < (b.layoutIndex or math.huge)
    end)
end

RepositionBuffBarContainers = function()
    if not Perskan.db.profile.sortBuffBarsUpward then return end
    -- Our own SetPoint calls run inside a Layout post-hook; don't re-enter.
    if sortState.repositioning or sortState.blocked then return end
    -- Child OnShow/OnHide fire during combat as cooldowns come and go; SetPoint is
    -- protected, so never reposition in a lockdown.
    if InCombatLockdown() then return end

    CollectBuffBarContainers()
    if not sortState.parentFrame or #sortState.containers == 0 then return end

    -- Re-read rather than trusting the login-time value: bar height follows the
    -- viewer's icon scale, which the player can change in Edit Mode.
    local height = sortState.containers[1]:GetHeight()
    if height and height > 0 then
        sortState.containerHeight = height
    end

    sortState.repositioning = true

    -- The viewer is an Edit Mode system frame; if its security model rejects our
    -- anchoring, say so once instead of erroring on every layout pass.
    local ok, err = pcall(function()
        local visibleIndex = 0
        for _, container in ipairs(sortState.containers) do
            if container:IsShown() then
                container:ClearAllPoints()
                container:SetPoint("BOTTOMLEFT", sortState.parentFrame, "BOTTOMLEFT", 0,
                    visibleIndex * ((sortState.containerHeight or 0) + sortState.containerSpacing))
                visibleIndex = visibleIndex + 1
            end
        end
    end)

    sortState.repositioning = false

    if not ok then
        sortState.blocked = true
        Perskan:Print("Sort Bars Upward is unavailable on this client: " .. tostring(err))
    end
end

-- The viewer is a GridLayoutFrame: every Layout() pass re-anchors its children and
-- would undo our stacking, so re-assert right after it runs.
local function HookBuffBarLayout()
    if sortState.layoutHooked then return end
    local viewer = BuffBarCooldownViewer
    if not viewer or type(viewer.Layout) ~= "function" then return end

    sortState.layoutHooked = true
    hooksecurefunc(viewer, "Layout", function()
        RepositionBuffBarContainers()
    end)
end

-- Live toggle: turning the option off hands the bars back to Blizzard's layout.
function Perskan:ApplySortBuffBars()
    if not BuffBarCooldownViewer then return end

    if self.db.profile.sortBuffBarsUpward then
        HookBuffBarLayout()
        RepositionBuffBarContainers()
    elseif not InCombatLockdown() and type(BuffBarCooldownViewer.Layout) == "function" then
        BuffBarCooldownViewer:Layout()
    end
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

    RepositionBuffBarContainers()
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
    RepositionBuffBarContainers()
end

Perskan:RegisterModule("BuffBars", function(self)
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

            HookBuffBarLayout()
            RepositionAll()
        end

        if event == "PLAYER_REGEN_ENABLED" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
            RepositionAll()
        end
    end)
end)
