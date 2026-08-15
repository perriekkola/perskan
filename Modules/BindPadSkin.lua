-- Repaints BindPad's window in the settings window's styling.
--
-- Purely cosmetic, and deliberately a skin rather than a rebuild: BindPad's slots are
-- secure action buttons carrying drag-and-drop and key capture, so re-creating its panel
-- on MiniFramework widgets would put working behaviour at risk for a paint job. The stock
-- ButtonFrameTemplate art is hidden, a flat dark panel drawn behind it, the top tabs
-- moved into a vertical strip down the left like the settings sidebar, and the stock
-- checkboxes swapped for the framework's toggles (the originals stay alive underneath,
-- since they own the logic - ours just click them).
--
-- Every lookup is guarded: these are Blizzard template internals and another addon's
-- frame names, and a rename should cost some styling, never an error inside BindPad.

local addonName, addon = ...
local mini = addon.Framework

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

-- Width of the tab strip the window grows by, and the geometry of one tab in it.
local SIDEBAR_WIDTH = 132
local TAB_WIDTH, TAB_HEIGHT, TAB_SPACING = 122, 26, 4
local TAB_TOP = -46

-- The slot grid starts below the old top-tab band; with the tabs on the left it can come
-- up by that much.
local GRID_LIFT = 32

-- Stock icons for the three shortcut buttons, whose micro-button art doesn't survive
-- being flattened.
local SHORTCUT_ICONS = {
    BindPadFrameOpenSpellBookButton = "Interface\\Icons\\INV_Misc_Book_09",
    BindPadFrameOpenMacroButton = "Interface\\Icons\\INV_Scroll_03",
    BindPadFrameOpenBagButton = "Interface\\Icons\\INV_Misc_Bag_08",
}

local skinned = false

local function Hide(region)
    if region and region.Hide then region:Hide() end
end

local function HideAll(...)
    for i = 1, select("#", ...) do
        Hide((select(i, ...)))
    end
end

local function Label(button)
    if not button then return nil end
    return button.Text or (button.GetFontString and button:GetFontString()) or _G[(button:GetName() or "") .. "Text"]
end

local function PaintPanel(frame, level)
    local backdropFrame = CreateFrame("Frame", nil, frame, mini.GUI.BackdropTemplate)
    backdropFrame:SetAllPoints(frame)
    backdropFrame:SetFrameLevel(math.max(0, frame:GetFrameLevel() - (level or 1)))

    local accent = mini.GUI.Accent
    mini.GUI.ApplyBackdrop(backdropFrame, BACKDROP,
        0.09, 0.08, 0.08, 0.96, accent.r, accent.g, accent.b, 0.55)

    return backdropFrame
end

--------------------------------------------------------------------------------
-- Buttons
--------------------------------------------------------------------------------

-- Flat dark field with an accent hover, for text buttons.
local function SkinTextButton(button)
    if not button or button._perskanSkinned then return end
    button._perskanSkinned = true

    HideAll(button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture())
    if button.Left then HideAll(button.Left, button.Middle, button.Right) end
    if button.LeftSeparator then HideAll(button.LeftSeparator, button.RightSeparator) end

    local field = CreateFrame("Frame", nil, button, mini.GUI.BackdropTemplate)
    field:SetAllPoints(button)
    field:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    mini.GUI.ApplyBackdrop(field, BACKDROP,
        mini.GUI.FieldIdle.r, mini.GUI.FieldIdle.g, mini.GUI.FieldIdle.b, 1,
        mini.GUI.LineIdle.r, mini.GUI.LineIdle.g, mini.GUI.LineIdle.b, 1)

    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetColorTexture(mini.GUI.AccentHi.r, mini.GUI.AccentHi.g, mini.GUI.AccentHi.b, 0.2)
    end

    local label = Label(button)
    if label then
        label:SetTextColor(mini.GUI.TabTextHover.r, mini.GUI.TabTextHover.g, mini.GUI.TabTextHover.b, 1)
    end
end

-- The three shortcuts were 29x58 micro buttons: too big, and left blank by flattening.
-- They become square icon buttons; their tooltips are BindPad's own and stay untouched.
local function SkinShortcutButton(name, icon)
    local button = _G[name]
    if not button or button._perskanSkinned then return end
    button._perskanSkinned = true

    button:SetSize(26, 26)
    button:SetHitRectInsets(0, 0, 0, 0)

    local normal = button:GetNormalTexture()
    if normal then
        normal:SetTexture(icon)
        normal:ClearAllPoints()
        normal:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        normal:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        normal:Show()
    end
    HideAll(button:GetPushedTexture(), button:GetDisabledTexture())

    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
        highlight:SetVertexColor(mini.GUI.AccentHi.r, mini.GUI.AccentHi.g, mini.GUI.AccentHi.b, 0.25)
        highlight:ClearAllPoints()
        highlight:SetAllPoints(button)
    end

    local field = CreateFrame("Frame", nil, button, mini.GUI.BackdropTemplate)
    field:SetAllPoints(button)
    field:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    mini.GUI.ApplyBackdrop(field, BACKDROP,
        mini.GUI.FieldIdle.r, mini.GUI.FieldIdle.g, mini.GUI.FieldIdle.b, 1,
        mini.GUI.LineIdle.r, mini.GUI.LineIdle.g, mini.GUI.LineIdle.b, 1)
end

-- Built to the same spec as the settings window's close button: 28px square, a faint
-- white hover wash over the whole hit area, and an × that reddens under the mouse.
local function SkinCloseButton(button, anchorTo)
    if not button or button._perskanSkinned then return end
    button._perskanSkinned = true

    -- Sweep the regions rather than naming the four texture slots: a close button's art
    -- can sit in extra pieces (borders, icons) that survive hiding just Normal/Pushed,
    -- which is what left a stock red X sitting on the panel.
    for _, region in ipairs({ button:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end
    HideAll(button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(),
        button:GetHighlightTexture())

    button:SetSize(28, 28)
    button:SetHitRectInsets(0, 0, 0, 0)
    if anchorTo then
        button:ClearAllPoints()
        button:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", -6, -6)
    end

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.07)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetAllPoints(button)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText("×")
    label:SetTextColor(0.5, 0.5, 0.5, 1)

    button:HookScript("OnEnter", function() label:SetTextColor(1, 0.3, 0.3, 1) end)
    button:HookScript("OnLeave", function() label:SetTextColor(0.5, 0.5, 0.5, 1) end)
end

--------------------------------------------------------------------------------
-- Toggles
--------------------------------------------------------------------------------

-- The stock check button keeps the logic and stays "shown" (a hidden button can't be
-- clicked programmatically); it's just made invisible and unclickable, with one of the
-- framework's toggles sitting in its place. Ours are laid out in their own column rather
-- than inheriting the originals' positions, which were spaced for 20px checkboxes and
-- left the taller toggles touching.
local function ReplaceCheckButton(name, labelText, tooltip, x, y)
    local original = _G[name]
    if not original or original._perskanReplaced then return end
    original._perskanReplaced = true

    local originalLabel = Label(original)
    if originalLabel then originalLabel:SetText("") end
    original:SetAlpha(0)
    original:EnableMouse(false)

    local toggle = mini:Checkbox({
        Parent = BindPadFrame,
        LabelText = labelText,
        Tooltip = tooltip,
        GetValue = function() return original:GetChecked() and true or false end,
        SetValue = function() original:Click() end,
    })
    toggle:ClearAllPoints()
    toggle:SetPoint("BOTTOMLEFT", BindPadFrame, "BOTTOMLEFT", x, y)

    return toggle
end

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

-- PanelTemplates re-shows a tab's stock art every time the selection changes, so this
-- runs on every styling pass rather than once. Sweeping the regions beats naming them:
-- the template's pieces have moved around between clients, and the tabs were still
-- drawing their boxes when only the known names were hidden.
local function StripTabArt(tab)
    for _, region in ipairs({ tab:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and not region._perskanOwned then
            region:Hide()
        end
    end
    if tab.NineSlice then Hide(tab.NineSlice) end
    HideAll(tab:GetHighlightTexture(), tab:GetDisabledTexture(), tab:GetNormalTexture())
end

local function StyleTabs()
    for i = 1, 4 do
        local tab = _G["BindPadFrameTab" .. i]
        if tab then
            StripTabArt(tab)

            if not tab._perskanSkinned then
                tab._perskanSkinned = true

                -- Selection wash and the accent bar down the left edge, as in the
                -- settings window's sidebar.
                local wash = tab:CreateTexture(nil, "BACKGROUND")
                wash:SetAllPoints(tab)
                wash:SetColorTexture(mini.GUI.Accent.r, mini.GUI.Accent.g, mini.GUI.Accent.b, 0.16)
                wash._perskanOwned = true
                tab._perskanWash = wash

                local bar = tab:CreateTexture(nil, "OVERLAY")
                bar:SetWidth(3)
                bar:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
                bar:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
                bar:SetColorTexture(mini.GUI.Accent.r, mini.GUI.Accent.g, mini.GUI.Accent.b, 1)
                bar._perskanOwned = true
                tab._perskanBar = bar

                tab:HookScript("OnEnter", function(self)
                    local label = Label(self)
                    if label and BindPadFrame.selectedTab ~= i then
                        label:SetTextColor(mini.GUI.TabTextBright.r, mini.GUI.TabTextBright.g,
                            mini.GUI.TabTextBright.b, 1)
                    end
                end)
                tab:HookScript("OnLeave", function() StyleTabs() end)
            end

            -- Re-asserted on every pass: PanelTemplates rewrites tab geometry when the
            -- selection changes.
            tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", BindPadFrame, "TOPLEFT", 8,
                TAB_TOP - (i - 1) * (TAB_HEIGHT + TAB_SPACING))

            local label = Label(tab)
            if label then
                label:ClearAllPoints()
                label:SetPoint("LEFT", tab, "LEFT", 12, 0)
                label:SetJustifyH("LEFT")
            end

            local selected = BindPadFrame and BindPadFrame.selectedTab == i
            local color = selected and mini.GUI.TabTextSelected or mini.GUI.TabTextHover
            if label then
                label:SetTextColor(color.r, color.g, color.b, 1)
            end
            if tab._perskanWash then tab._perskanWash:SetShown(selected and true or false) end
            if tab._perskanBar then tab._perskanBar:SetShown(selected and true or false) end
        end
    end
end

--------------------------------------------------------------------------------
-- Scroll bar
--------------------------------------------------------------------------------

-- The panel carried its own scrollbar art on top of the template's, so both were drawn.
-- What's left is rebuilt to the settings window's scrollbar: a 10px flat track with an
-- 8px grey thumb and no arrow buttons. The stock slider keeps doing the scrolling - only
-- its art is replaced - so the wheel, the drag and the range all behave as they did.
-- Two bars were showing: the panel draws its own art (old character-sheet scrollbar
-- pieces) on top of the template's, and the template's own bar is the dated
-- UIPanelScrollFrameTemplate slider. The decorative art is hidden, the legacy slider is
-- parked in a hidden holder - reparenting rather than alpha, since the scroll template
-- resets a scrollbar's alpha on range changes and mouse-over - and Blizzard's current
-- MinimalScrollBar takes over, wired up by ScrollUtil exactly as retail's own panels do.
local function SkinScrollBar()
    HideAll(_G["BindPadScrollFrameTop"], _G["BindPadScrollFrameMiddle"], _G["BindPadScrollFrameBottom"])

    local scrollFrame = BindPadScrollFrame
    if not scrollFrame or scrollFrame._perskanScrollSkinned then return end
    if not (ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar) then return end
    scrollFrame._perskanScrollSkinned = true

    local stockBar = _G["BindPadScrollFrameScrollBar"] or scrollFrame.ScrollBar or scrollFrame.scrollBar
    if stockBar then
        local holder = CreateFrame("Frame", nil, BindPadFrame)
        holder:Hide()
        stockBar:SetParent(holder)
    end

    local ok, scrollBar = pcall(CreateFrame, "EventFrame", nil, BindPadFrame, "MinimalScrollBar")
    if not ok or not scrollBar then return end

    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 8, 0)
    pcall(ScrollUtil.InitScrollFrameWithScrollBar, scrollFrame, scrollBar)
end

--------------------------------------------------------------------------------
-- Skin
--------------------------------------------------------------------------------

local function SkinBindPad()
    if skinned or not BindPadFrame then return end
    skinned = true

    -- Panel chrome.
    HideAll(BindPadFrame.NineSlice, BindPadFrame.Bg, BindPadFrame.TopTileStreaks, _G["MacroFramePortrait"])
    if BindPadFrame.PortraitContainer then Hide(BindPadFrame.PortraitContainer) end
    if BindPadFrame.portrait then Hide(BindPadFrame.portrait) end
    if BindPadFrame.Inset then
        HideAll(BindPadFrame.Inset.NineSlice, BindPadFrame.Inset.Bg)
    end

    -- Room for the tab strip down the left, and for a column of three toggles along the
    -- bottom (taller than the 20px checkboxes they replace).
    BindPadFrame:SetWidth(BindPadFrame:GetWidth() + SIDEBAR_WIDTH)
    BindPadFrame:SetHeight(BindPadFrame:GetHeight() + 26)
    if BindPadScrollFrame then
        -- The slot grid sat below where the top tabs used to be; with the tabs down the
        -- left that band is dead space, so the grid moves up into it and the viewport
        -- grows by the same amount.
        BindPadScrollFrame:ClearAllPoints()
        BindPadScrollFrame:SetPoint("TOPLEFT", BindPadFrame, "TOPLEFT", 13 + SIDEBAR_WIDTH, -68 + GRID_LIFT)
        BindPadScrollFrame:SetHeight(BindPadScrollFrame:GetHeight() + GRID_LIFT)
    end
    if BindPadFrameOpenSpellBookButton then
        BindPadFrameOpenSpellBookButton:ClearAllPoints()
        BindPadFrameOpenSpellBookButton:SetPoint("BOTTOMLEFT", BindPadFrame, "BOTTOMLEFT",
            16 + SIDEBAR_WIDTH, 16)
    end

    PaintPanel(BindPadFrame)

    local title = (BindPadFrame.TitleContainer and BindPadFrame.TitleContainer.TitleText)
        or _G["BindPadFrameTitleText"]
    if title then
        local titleColor = mini.GUI.TitleText
        title:SetTextColor(titleColor.r, titleColor.g, titleColor.b, 1)
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", BindPadFrame, "TOPLEFT", 14, -12)
    end

    local accent = mini.GUI.Accent
    local accentLine = BindPadFrame:CreateTexture(nil, "OVERLAY")
    accentLine:SetHeight(1)
    accentLine:SetPoint("TOPLEFT", BindPadFrame, "TOPLEFT", 1, -34)
    accentLine:SetPoint("TOPRIGHT", BindPadFrame, "TOPRIGHT", -1, -34)
    mini.GUI.SetGradientH(accentLine, accent.r, accent.g, accent.b, 0.9, accent.r, accent.g, accent.b, 0.04)

    SkinScrollBar()
    -- The panel's own close button, then any other close button anywhere beneath it -
    -- looking up a single one left a second, unskinned stock X sitting on the frame.
    -- Only the primary one is repositioned; the rest just lose their art.
    local primaryClose = BindPadFrame.CloseButton or _G["BindPadFrameCloseButton"]
    SkinCloseButton(primaryClose, BindPadFrame)

    local function SkinCloseButtonsIn(frame, depth)
        if depth > 4 then return end
        for _, child in ipairs({ frame:GetChildren() }) do
            local childName = child.GetName and child:GetName()
            if child ~= primaryClose and childName and childName:match("CloseButton$") then
                SkinCloseButton(child)
            end
            SkinCloseButtonsIn(child, depth + 1)
        end
    end
    SkinCloseButtonsIn(BindPadFrame, 1)

    SkinCloseButton(_G["BindPadBindFrameCloseButton"])
    SkinCloseButton(_G["BindPadMacroFrameCloseButton"])
    SkinTextButton(_G["BindPadFrameExitButton"])

    for name, icon in pairs(SHORTCUT_ICONS) do
        SkinShortcutButton(name, icon)
    end

    -- One column, clear of the icon buttons, 28px apart so the toggles aren't touching.
    local toggleX = SIDEBAR_WIDTH + 110
    ReplaceCheckButton("BindPadFrameCharacterButton",
        CHARACTER_SPECIFIC_KEYBINDINGS or "Character Specific",
        CHARACTER_SPECIFIC_KEYBINDING_TOOLTIP, toggleX, 68)
    ReplaceCheckButton("BindPadFrameSaveAllKeysButton",
        BINDPAD_TEXT_SAVE_ALL_KEYS or "Save All Keys",
        BINDPAD_TOOLTIP_SAVE_ALL_KEYS, toggleX, 40)
    ReplaceCheckButton("BindPadFrameShowHotkeyButton",
        BINDPAD_TEXT_SHOW_HOTKEY or "Show Hotkeys",
        BINDPAD_TOOLTIP_SHOW_HOTKEY, toggleX, 12)

    -- Free-floating and draggable, like the settings window.
    BindPadFrame:SetMovable(true)
    BindPadFrame:EnableMouse(true)
    BindPadFrame:SetClampedToScreen(true)
    BindPadFrame:RegisterForDrag("LeftButton")
    BindPadFrame:HookScript("OnDragStart", function(self) self:StartMoving() end)
    BindPadFrame:HookScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- The key-capture dialog and the macro popup are separate top-level frames.
    if BindPadBindFrame then
        HideAll(BindPadBindFrame.NineSlice, BindPadBindFrame.Bg)
        PaintPanel(BindPadBindFrame)
    end
    if BindPadMacroPopupFrame then
        HideAll(BindPadMacroPopupFrame.NineSlice, BindPadMacroPopupFrame.Bg)
        if BindPadMacroPopupFrame.Inset then
            HideAll(BindPadMacroPopupFrame.Inset.NineSlice, BindPadMacroPopupFrame.Inset.Bg)
        end
        PaintPanel(BindPadMacroPopupFrame)
        SkinCloseButton(BindPadMacroPopupFrame.CloseButton)
    end

    StyleTabs()
end

Perskan:RegisterModule("BindPadSkin", function(self)
    if not BindPadFrame then return end

    -- Out of the UIPanel system at login, before anything can show it: as a managed panel
    -- it was being repositioned to sit beside other windows, and hidden when enough of
    -- them were open. Registering it late (on first show) was already too late for that
    -- first show. HIGH strata puts it over the panels it used to make room for.
    if UIPanelWindows then
        UIPanelWindows["BindPadFrame"] = nil
        UIPanelWindows["BindPadMacroFrame"] = nil
    end
    BindPadFrame:SetFrameStrata("HIGH")
    BindPadFrame:SetToplevel(true)

    -- Skinned on first show: BindPad's own OnShow lays the panel out, and a frame that
    -- never opens costs nothing.
    BindPadFrame:HookScript("OnShow", function(frame)
        SkinBindPad()
        StyleTabs()
        -- Re-sync the toggles with whatever BindPad set the real checkboxes to.
        if frame.MiniRefresh then frame:MiniRefresh() end
    end)

    if type(BindPadFrameTab_OnClick) == "function" then
        hooksecurefunc("BindPadFrameTab_OnClick", StyleTabs)
    end
end, "bindPadEnabled")
