-- Two fixes to the vendored BindPad's window, both of which have to happen at runtime.
-- The window's art is not one of them - the buttons, checkboxes and slot frames were
-- moved onto Blizzard's current templates and atlases in BindPad.xml itself, where the
-- widgets are declared, each change marked [Perskan] there.
--
-- What is left here is the parts XML can't reach:
--
--   * The scroll frame is a UIPanelScrollFrameTemplate, whose slider is the old
--     arrows-and-thumb bar, and the panel draws its own character-sheet scrollbar art on
--     top of it. Both go, replaced by Blizzard's current MinimalScrollBar.
--   * The window was a managed UI panel, so it got shoved aside to make room for other
--     windows and hidden when enough were open. It floats and drags instead.
--
-- Every lookup is guarded: these are another addon's frame names, and a rename should
-- cost a tweak, never an error inside BindPad.

local function Hide(region)
    if region and region.Hide then region:Hide() end
end

--------------------------------------------------------------------------------
-- Scrollbar
--------------------------------------------------------------------------------

local function ModernizeScrollBar()
    -- BindPad's own scrollbar art, drawn on top of the template's.
    Hide(_G["BindPadScrollFrameTop"])
    Hide(_G["BindPadScrollFrameMiddle"])
    Hide(_G["BindPadScrollFrameBottom"])

    local scrollFrame = BindPadScrollFrame
    if not scrollFrame or scrollFrame._perskanScrollDone then return end
    if not (ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar) then return end
    scrollFrame._perskanScrollDone = true

    -- Reparenting rather than hiding in place: the scroll template re-shows and re-alphas
    -- its bar as the range changes, and nothing under a hidden frame is ever drawn.
    local holder = CreateFrame("Frame", nil, BindPadFrame)
    holder:Hide()

    local function Park(bar)
        if bar then
            bar:SetParent(holder)
            bar:Hide()
        end
    end
    Park(_G["BindPadScrollFrameScrollBar"])
    Park(scrollFrame.ScrollBar)
    Park(scrollFrame.scrollBar)
    -- Swept rather than named: the template's bar isn't under the same key on every
    -- client, and a missed one just ends up drawn beside the replacement.
    for _, child in ipairs({ scrollFrame:GetChildren() }) do
        local childName = child.GetName and child:GetName()
        local isSlider = child.GetObjectType and child:GetObjectType() == "Slider"
        if isSlider or (childName and childName:match("ScrollBar")) then
            Park(child)
        end
    end

    local ok, scrollBar = pcall(CreateFrame, "EventFrame", nil, BindPadFrame, "MinimalScrollBar")
    if not ok or not scrollBar then return end

    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 8, 0)
    -- ScrollUtil takes the wheel over as well, so the parked bar isn't needed for anything.
    pcall(ScrollUtil.InitScrollFrameWithScrollBar, scrollFrame, scrollBar)
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

Perskan:RegisterModule("BindPadTweaks", function(self)
    if not BindPadFrame then return end

    -- Out of the UIPanel system at login, before anything can show it: registering late
    -- (on first show) is already too late for that first show. BindPadFrame_Toggle calls
    -- Show/Hide directly - see the [Perskan] note in BindPad.lua - and HIGH strata puts
    -- it over the panels it used to make room for.
    if UIPanelWindows then
        UIPanelWindows["BindPadFrame"] = nil
        UIPanelWindows["BindPadMacroFrame"] = nil
    end
    BindPadFrame:SetFrameStrata("HIGH")
    BindPadFrame:SetToplevel(true)
    BindPadFrame:SetMovable(true)
    BindPadFrame:SetClampedToScreen(true)
    BindPadFrame:RegisterForDrag("LeftButton")
    BindPadFrame:HookScript("OnDragStart", function(frame) frame:StartMoving() end)
    BindPadFrame:HookScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)

    BindPadFrame:HookScript("OnShow", ModernizeScrollBar)
end, "bindPadEnabled")
