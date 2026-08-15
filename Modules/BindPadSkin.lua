-- Repaints BindPad's window in the settings window's styling.
--
-- Purely cosmetic, and deliberately a skin rather than a rebuild: BindPad's slots are
-- secure action buttons carrying drag-and-drop and key capture, so re-creating its panel
-- on MiniFramework widgets would put working behaviour at risk for a paint job. Instead
-- the stock ButtonFrameTemplate art (gold NineSlice, portrait, parchment insets) is
-- hidden and a flat dark panel with our accent is drawn behind it.
--
-- Every lookup is guarded: these are Blizzard template internals, and a renamed region
-- should cost some styling, never an error inside BindPad.

local addonName, addon = ...
local mini = addon.Framework

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
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

-- Flat dark field with a one-pixel border, matching the settings window's chrome.
local function PaintPanel(frame, r, g, b, a)
    local backdropFrame = CreateFrame("Frame", nil, frame, mini.GUI.BackdropTemplate)
    backdropFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    backdropFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    backdropFrame:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))

    local accent = mini.GUI.Accent
    mini.GUI.ApplyBackdrop(backdropFrame, BACKDROP,
        r or 0.09, g or 0.08, b or 0.08, a or 0.96,
        accent.r, accent.g, accent.b, 0.55)

    return backdropFrame
end

-- Blizzard's button art swapped for the same flat field the framework's buttons use.
local function SkinButton(button)
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
        highlight:SetColorTexture(mini.GUI.AccentHi.r, mini.GUI.AccentHi.g, mini.GUI.AccentHi.b, 0.18)
    end

    local label = button.Text or (button.GetFontString and button:GetFontString())
    if label then
        label:SetTextColor(mini.GUI.TabTextHover.r, mini.GUI.TabTextHover.g, mini.GUI.TabTextHover.b, 1)
    end
end

-- Top tabs lose their parchment and read like the settings sidebar: dim when idle, gold
-- when selected.
local function SkinTabs()
    for i = 1, 4 do
        local tab = _G["BindPadFrameTab" .. i]
        if tab then
            if not tab._perskanSkinned then
                tab._perskanSkinned = true
                HideAll(_G[tab:GetName() .. "Left"], _G[tab:GetName() .. "Middle"],
                    _G[tab:GetName() .. "Right"], _G[tab:GetName() .. "LeftDisabled"],
                    _G[tab:GetName() .. "MiddleDisabled"], _G[tab:GetName() .. "RightDisabled"])
                if tab.Left then HideAll(tab.Left, tab.Middle, tab.Right) end
                if tab.LeftActive then HideAll(tab.LeftActive, tab.MiddleActive, tab.RightActive) end
                if tab.LeftHighlight then HideAll(tab.LeftHighlight, tab.MiddleHighlight, tab.RightHighlight) end

                -- Accent bar under the selected tab, in place of the raised art.
                local marker = tab:CreateTexture(nil, "OVERLAY")
                marker:SetHeight(2)
                marker:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 6, 2)
                marker:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 2)
                marker:SetColorTexture(mini.GUI.Accent.r, mini.GUI.Accent.g, mini.GUI.Accent.b, 1)
                tab._perskanMarker = marker
            end

            local selected = BindPadFrame and BindPadFrame.selectedTab == i
            local color = selected and mini.GUI.TabTextSelected or mini.GUI.TabTextIdle
            local label = tab.Text or (tab.GetFontString and tab:GetFontString())
            if label then
                label:SetTextColor(color.r, color.g, color.b, 1)
            end
            if tab._perskanMarker then
                tab._perskanMarker:SetShown(selected and true or false)
            end
        end
    end
end

local function SkinBindPad()
    if skinned or not BindPadFrame then return end
    skinned = true

    -- Panel chrome.
    HideAll(BindPadFrame.NineSlice, BindPadFrame.Bg, BindPadFrame.TopTileStreaks,
        _G["MacroFramePortrait"])
    if BindPadFrame.PortraitContainer then Hide(BindPadFrame.PortraitContainer) end
    if BindPadFrame.portrait then Hide(BindPadFrame.portrait) end
    if BindPadFrame.Inset then
        HideAll(BindPadFrame.Inset.NineSlice, BindPadFrame.Inset.Bg)
    end

    PaintPanel(BindPadFrame)

    -- Title: same colour and accent rule as the settings window's title bar.
    local title = BindPadFrame.TitleContainer and BindPadFrame.TitleContainer.TitleText
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

    -- The scroll frame's old character-sheet scrollbar art.
    HideAll(_G["BindPadScrollFrameTop"], _G["BindPadScrollFrameMiddle"], _G["BindPadScrollFrameBottom"])

    for _, name in ipairs({
        "BindPadFrameExitButton",
        "BindPadFrameOpenSpellBookButton",
        "BindPadFrameOpenMacroButton",
        "BindPadFrameOpenBagButton",
    }) do
        SkinButton(_G[name])
    end

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
    end

    SkinTabs()
end

Perskan:RegisterModule("BindPadSkin", function(self)
    if not BindPadFrame then return end

    -- Skinned on first show: BindPad's own OnShow lays the panel out, and a frame that
    -- never opens costs nothing.
    BindPadFrame:HookScript("OnShow", function()
        SkinBindPad()
        SkinTabs()
    end)

    -- Selection colour has to follow the tab clicks.
    if type(BindPadFrameTab_OnClick) == "function" then
        hooksecurefunc("BindPadFrameTab_OnClick", SkinTabs)
    end
end, "bindPadEnabled")
