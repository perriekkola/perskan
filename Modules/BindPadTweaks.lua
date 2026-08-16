-- Two fixes to the vendored BindPad's window, both of which have to happen at runtime.
-- The window's art is not one of them - the buttons, checkboxes and slot frames were
-- moved onto Blizzard's current templates and atlases in BindPad.xml itself, where the
-- widgets are declared, each change marked [Perskan] there.
--
-- What is left here is the parts XML can't reach:
--
--   * Both scroll frames - the pad and the icon picker - are UIPanelScrollFrameTemplates,
--     whose slider is the old arrows-and-thumb bar, and the pad draws its own
--     character-sheet scrollbar art on top of that. All of it goes, replaced by
--     Blizzard's current MinimalScrollBar.
--   * The window was a managed UI panel, so it got shoved aside to make room for other
--     windows and hidden when enough were open. It floats and drags instead.
--
-- Every lookup is guarded: these are another addon's frame names, and a rename should
-- cost a tweak, never an error inside BindPad.

local function Hide(region)
    if region and region.Hide then region:Hide() end
end

--------------------------------------------------------------------------------
-- Scrollbars
--------------------------------------------------------------------------------

-- Swaps a UIPanelScrollFrameTemplate's arrows-and-thumb slider for Blizzard's current
-- MinimalScrollBar.
--
-- Both of BindPad's scroll frames read their position from the scroll frame's own
-- vertical scroll rather than from the slider - even the icon picker, whose faux paging
-- derives its row offset inside OnVerticalScroll - so ScrollUtil can drive them with the
-- old slider out of the picture.
local function ReplaceScrollBar(scrollFrame, barParent, barBottom, onVerticalScroll)
    if not scrollFrame or scrollFrame._perskanScrollDone then return end
    if not (ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar) then return end
    scrollFrame._perskanScrollDone = true

    -- Reparenting rather than hiding in place: the scroll template re-shows and re-alphas
    -- its bar as the range changes, and nothing under a hidden frame is ever drawn.
    local holder = CreateFrame("Frame", nil, barParent)
    holder:Hide()

    local function Park(bar)
        if bar then
            -- Cleared before the reparent, and load bearing on the icon picker: the
            -- slider's own handler scrolls self:GetParent(), which is about to stop
            -- being the scroll frame, and FauxScrollFrame_* still calls SetValue on it.
            -- Left alone it would either error against the holder or fight ScrollUtil
            -- over the scroll position.
            --
            -- Asked rather than assumed, because the two frames genuinely differ. The
            -- pad calls ScrollFrame_OnLoad, which reassigns .ScrollBar to an EventFrame
            -- MinimalScrollBar of Blizzard's own; the picker does not, so its .ScrollBar
            -- is still the template's Slider. An EventFrame has no OnValueChanged, and
            -- SetScript rejects the name outright even when the handler is nil.
            if bar.HasScript and bar:HasScript("OnValueChanged") then
                bar:SetScript("OnValueChanged", nil)
            end
            bar:SetParent(holder)
            bar:Hide()
        end
    end

    local name = scrollFrame.GetName and scrollFrame:GetName()
    if name then Park(_G[name .. "ScrollBar"]) end
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

    local ok, scrollBar = pcall(CreateFrame, "EventFrame", nil, barParent, "MinimalScrollBar")
    if not ok or not scrollBar then return end

    -- barBottom lets the bar run the full height of what is on screen where that is
    -- taller than the scroll frame: the icon picker's frame is sized to the scroll range
    -- its faux paging expects, which is a row short of the grid it sits over.
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", barBottom or scrollFrame, "BOTTOMRIGHT", 8, 0)

    -- ScrollUtil takes the wheel over as well, so the parked bar isn't needed for
    -- anything. It SetScripts OnVerticalScroll rather than hooking it, though, so any
    -- caller that needs a handler of its own has to hand it over to be put back - see
    -- the picker, where that handler is the entire mechanism by which the grid repaints.
    pcall(ScrollUtil.InitScrollFrameWithScrollBar, scrollFrame, scrollBar)
    if onVerticalScroll then
        scrollFrame:HookScript("OnVerticalScroll", onVerticalScroll)
    end
end

local function ModernizeScrollBar()
    -- BindPad's own scrollbar art, drawn on top of the template's.
    Hide(_G["BindPadScrollFrameTop"])
    Hide(_G["BindPadScrollFrameMiddle"])
    Hide(_G["BindPadScrollFrameBottom"])

    ReplaceScrollBar(BindPadScrollFrame, BindPadFrame)
end

local function ModernizeMacroPopupScrollBar()
    -- Named rather than read back off the frame: the handler is BindPad's, declared in
    -- the picker's XML, and naming it keeps this independent of whatever happens to be
    -- attached by the time the popup first opens.
    ReplaceScrollBar(BindPadMacroPopupScrollFrame, BindPadMacroPopupFrame,
        BindPadMacroPopupButton20, BindPadMacroPopupFrame_OnScroll)
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
    if BindPadMacroPopupFrame then
        BindPadMacroPopupFrame:HookScript("OnShow", ModernizeMacroPopupScrollBar)
    end
end, "bindPadEnabled")
