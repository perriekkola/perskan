local addonName, addon = ...
local mini = addon.Framework

-- Layout metrics for the auto-stacking renderer.
local SPACING = 14
local SLIDER_ABOVE = 40 -- room above a slider for its value box + label
local SLIDER_BELOW = 16 -- room below for the min/max labels
local SLIDER_H = 20
local TOGGLE_H = 26
local DIVIDER_H = 26
local SELECT_LABEL_H = 16
local SELECT_GAP = 4
local SELECT_DD_H = 24

--------------------------------------------------------------------------------
-- Reload banner
--------------------------------------------------------------------------------

-- Non-blocking replacement for the old "reload now?" popup that fired on nearly every
-- toggle. Reload-dependent settings call Perskan:RequestReload(); a quiet bar slides
-- up at the bottom of the window offering a reload when the player is ready.
local function BuildReloadBanner(window)
    local accent = mini.GUI.Accent

    local banner = CreateFrame("Frame", nil, window, mini.GUI.BackdropTemplate)
    banner:SetHeight(30)
    banner:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 2, 2)
    banner:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -2, 2)
    banner:SetFrameStrata("HIGH")
    banner:SetFrameLevel(window:GetFrameLevel() + 20)
    -- Solid dark bar with an accent border, so the text stays legible over whatever
    -- content sits behind the window's bottom edge.
    mini.GUI.ApplyBackdrop(banner, {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    }, 0.12, 0.10, 0.10, 0.97, accent.r, accent.g, accent.b, 0.7)

    local stripe = banner:CreateTexture(nil, "OVERLAY")
    stripe:SetWidth(3)
    stripe:SetPoint("TOPLEFT", banner, "TOPLEFT", 1, -1)
    stripe:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 1, 1)
    stripe:SetColorTexture(accent.r, accent.g, accent.b, 0.9)

    local text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", banner, "LEFT", 14, 0)
    text:SetText("Some changes need a UI reload to take effect.")
    text:SetTextColor(0.95, 0.9, 0.85, 1)

    local reloadBtn = mini:Button({
        Parent = banner,
        Text = "Reload Now",
        Width = 110,
        Height = 22,
        OnClick = function() C_UI.Reload() end,
    })
    reloadBtn:SetPoint("RIGHT", banner, "RIGHT", -10, 0)

    local dismiss = CreateFrame("Button", nil, banner)
    dismiss:SetSize(22, 22)
    dismiss:SetPoint("RIGHT", reloadBtn, "LEFT", -6, 0)
    local dismissLabel = dismiss:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dismissLabel:SetAllPoints(dismiss)
    dismissLabel:SetText("×")
    dismissLabel:SetTextColor(0.7, 0.66, 0.62, 1)
    dismiss:SetScript("OnEnter", function() dismissLabel:SetTextColor(1, 0.5, 0.5, 1) end)
    dismiss:SetScript("OnLeave", function() dismissLabel:SetTextColor(0.7, 0.66, 0.62, 1) end)
    dismiss:SetScript("OnClick", function() banner:Hide() end)

    banner:Hide()
    return banner
end

--------------------------------------------------------------------------------
-- Get/set wiring from a schema control to the AceDB profile
--------------------------------------------------------------------------------

-- Reflow disabled/hidden states in place after a change (no value re-sync, so a
-- toggle's slide animation isn't cut short).
local function Relayout()
    if Perskan._relayoutActive then Perskan._relayoutActive() end
end

-- CVar toggles need the 1/0 form regardless of how the profile stores them.
local function ApplyCVarToggle(control, value)
    if control.cvar then
        Perskan:SetCVarValue(control.cvar, value and 1 or 0)
    end
end

local function MakeGet(control)
    if control.get then return control.get end
    local key = control.key
    if control.type == "toggle" then
        if control.store == "int01" then
            return function() return Perskan.db.profile[key] == 1 end
        end
        return function() return Perskan.db.profile[key] and true or false end
    end
    return function() return Perskan.db.profile[key] end
end

local function MakeSet(control)
    local key = control.key

    if control.set then
        -- Explicit setters (damage-meter per-window heights) do their own apply.
        return function(value)
            control.set(value)
            if control.reload then Perskan:RequestReload() end
            if control.type ~= "range" then Relayout() end
        end
    end

    if control.type == "toggle" then
        return function(value)
            if control.store == "int01" then
                Perskan.db.profile[key] = value and 1 or 0
            else
                Perskan.db.profile[key] = value and true or false
            end
            ApplyCVarToggle(control, value)
            if control.apply then control.apply() end
            if control.reload then Perskan:RequestReload() end
            Relayout()
        end
    end

    -- range / select
    return function(value)
        Perskan.db.profile[key] = value
        if control.cvar then
            Perskan:SetCVarValue(control.cvar, value)
        end
        if control.apply then control.apply() end
        if control.reload then Perskan:RequestReload() end
        -- Ranges (sliders) don't gate other controls; skip the per-tick reflow.
        if control.type ~= "range" then Relayout() end
    end
end

--------------------------------------------------------------------------------
-- Control builders -> layout entries
--------------------------------------------------------------------------------

local function BuildControlEntry(panel, control, sliderWidth)
    local get, set = MakeGet(control), MakeSet(control)

    if control.type == "divider" then
        local divider = mini:Divider({ Parent = panel, Text = control.name })
        divider:SetWidth(mini.ContentWidth)
        return { control = control, primary = divider, frames = { divider },
                 above = 4, body = DIVIDER_H, below = 6 }
    end

    if control.type == "toggle" then
        local toggle = mini:Checkbox({
            Parent = panel,
            LabelText = control.name,
            Tooltip = control.desc,
            GetValue = get,
            SetValue = set,
        })
        return { control = control, primary = toggle, frames = { toggle },
                 above = 0, body = TOGGLE_H, below = 0,
                 setDisabled = function(disabled)
                     if disabled then toggle:Disable() else toggle:Enable() end
                 end }
    end

    if control.type == "range" then
        local slider = mini:Slider({
            Parent = panel,
            LabelText = control.name,
            Min = control.min,
            Max = control.max,
            Step = control.step,
            Width = sliderWidth,
            GetValue = get,
            SetValue = set,
        })
        return { control = control, primary = slider.Slider, frames = { slider.Slider },
                 above = SLIDER_ABOVE, body = SLIDER_H, below = SLIDER_BELOW,
                 setDisabled = function(disabled)
                     if disabled then slider.Slider:Disable() else slider.Slider:Enable() end
                 end }
    end

    if control.type == "select" then
        local items, textOf = {}, {}
        for _, entry in ipairs(control.values) do
            items[#items + 1] = entry.value
            textOf[entry.value] = entry.text
        end

        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetText(control.name)

        local dd = mini:Dropdown({
            Parent = panel,
            Items = items,
            Width = 220,
            GetValue = get,
            SetValue = set,
            GetText = function(value) return textOf[value] or tostring(value) end,
        })
        dd:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -SELECT_GAP)

        return { control = control, primary = label, frames = { label, dd },
                 above = 0, body = SELECT_LABEL_H + SELECT_GAP + SELECT_DD_H, below = 0 }
    end
end

-- Builds one category page and returns a refresh closure.
local function BuildCategoryPanel(panel, category)
    local sliderWidth = math.min(340, (mini.ContentWidth or 400) - 20)
    local entries = {}
    for _, control in ipairs(category.controls) do
        entries[#entries + 1] = BuildControlEntry(panel, control, sliderWidth)
    end

    local function RelayoutPanel()
        local cursor = 0
        for _, e in ipairs(entries) do
            local hidden = e.control.hidden and e.control.hidden()
            e.primary:ClearAllPoints()
            if hidden then
                -- Leave hidden controls unanchored so they don't count toward the
                -- scroll height; they get repositioned if they become visible.
                for _, f in ipairs(e.frames) do f:Hide() end
            else
                for _, f in ipairs(e.frames) do f:Show() end
                cursor = cursor - e.above
                e.primary:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, cursor)
                cursor = cursor - e.body - e.below - SPACING
                if e.setDisabled then
                    e.setDisabled(e.control.disabled and e.control.disabled())
                end
            end
        end
        -- Drives the framework's scroll range (fires OnScrollRangeChanged).
        panel:SetHeight(math.max(1, -cursor + 10))
    end

    RelayoutPanel()
    -- Recompute when the tab is first shown: frame heights are only valid on screen,
    -- so this is what makes the scrollbar appear for tall pages.
    panel:HookScript("OnShow", RelayoutPanel)

    return {
        relayout = RelayoutPanel,
        refresh = function()
            if panel.MiniRefresh then panel:MiniRefresh() end
            RelayoutPanel()
        end,
    }
end

--------------------------------------------------------------------------------
-- Profiles panel (AceDB, rendered with MiniFramework widgets)
--------------------------------------------------------------------------------

local function BuildProfilesPanel(panel)
    local db = Perskan.db
    local y = 0
    local function place(frame, dy)
        frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
        y = y - dy
    end

    local currentList, copyList, deleteList = {}, {}, {}
    local function refillLists()
        wipe(currentList); wipe(copyList); wipe(deleteList)
        local current = db:GetCurrentProfile()
        for _, name in ipairs(db:GetProfiles()) do
            currentList[#currentList + 1] = name
            if name ~= current then
                copyList[#copyList + 1] = name
                deleteList[#deleteList + 1] = name
            end
        end
    end
    refillLists()

    -- Active profile
    local activeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    activeLabel:SetText("Active Profile")
    place(activeLabel, SELECT_LABEL_H + SELECT_GAP)

    local activeDD = mini:Dropdown({
        Parent = panel,
        Items = currentList,
        Width = 240,
        GetValue = function() return db:GetCurrentProfile() end,
        SetValue = function(value) db:SetProfile(value) end,
    })
    place(activeDD, SELECT_DD_H + SPACING * 2)

    -- New profile. GetValue mirrors the box's own text so the commit-on-focus-loss
    -- (fired when the Create button steals focus) keeps what the user typed.
    local newBox
    newBox = mini:EditBox({
        Parent = panel,
        LabelText = "New Profile",
        Width = 240,
        GetValue = function() return newBox and newBox.EditBox:GetText() or "" end,
        SetValue = function() end,
    })
    newBox.Label:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    newBox.EditBox:SetPoint("TOPLEFT", newBox.Label, "BOTTOMLEFT", 0, -SELECT_GAP)
    y = y - (SELECT_LABEL_H + SELECT_GAP + SELECT_DD_H)

    local createBtn = mini:Button({
        Parent = panel,
        Text = "Create",
        Width = 100,
        OnClick = function()
            local name = newBox.EditBox:GetText()
            if name and name:match("%S") then
                db:SetProfile(name)
                newBox.EditBox:SetText("")
                newBox.EditBox:ClearFocus()
            end
        end,
    })
    createBtn:SetPoint("TOPLEFT", newBox.EditBox, "BOTTOMLEFT", 0, -8)
    y = y - (22 + SPACING * 2)

    local divider = mini:Divider({ Parent = panel, Text = "Manage" })
    divider:SetWidth(mini.ContentWidth)
    place(divider, DIVIDER_H + SPACING)

    -- Copy from
    local copyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    copyLabel:SetText("Copy Settings From")
    place(copyLabel, SELECT_LABEL_H + SELECT_GAP)
    local copyDD
    copyDD = mini:Dropdown({
        Parent = panel,
        Items = copyList,
        Width = 240,
        GetValue = function() return copyDD._value end,
        SetValue = function(value) copyDD._value = value end,
        GetText = function(value) return value or "Select a profile" end,
    })
    local copyBtn = mini:Button({
        Parent = panel,
        Text = "Copy",
        Width = 100,
        OnClick = function()
            if copyDD._value then db:CopyProfile(copyDD._value) end
        end,
    })
    copyBtn:SetPoint("LEFT", copyDD, "RIGHT", mini.HorizontalSpacing, 0)
    place(copyDD, SELECT_DD_H + SPACING * 2)

    -- Delete
    local deleteLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    deleteLabel:SetText("Delete Profile")
    place(deleteLabel, SELECT_LABEL_H + SELECT_GAP)
    local deleteDD
    deleteDD = mini:Dropdown({
        Parent = panel,
        Items = deleteList,
        Width = 240,
        GetValue = function() return deleteDD._value end,
        SetValue = function(value) deleteDD._value = value end,
        GetText = function(value) return value or "Select a profile" end,
    })
    local deleteBtn = mini:Button({
        Parent = panel,
        Text = "Delete",
        Width = 100,
        Danger = true,
        OnClick = function()
            if deleteDD._value then
                db:DeleteProfile(deleteDD._value)
                deleteDD._value = nil
            end
        end,
    })
    deleteBtn:SetPoint("LEFT", deleteDD, "RIGHT", mini.HorizontalSpacing, 0)
    place(deleteDD, SELECT_DD_H + SPACING * 2)

    -- Reset
    local resetBtn = mini:Button({
        Parent = panel,
        Text = "Reset Current Profile",
        Width = 200,
        Danger = true,
        OnClick = function() db:ResetProfile() end,
    })
    resetBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - (22 + SPACING)

    local panelHeight = math.max(1, -y + 10)
    panel:SetHeight(panelHeight)
    -- Re-assert on show so the scroll range settles once frames are on screen.
    panel:HookScript("OnShow", function() panel:SetHeight(panelHeight) end)

    local function refresh()
        refillLists()
        if panel.MiniRefresh then panel:MiniRefresh() end
    end

    return { relayout = function() end, refresh = refresh }
end

--------------------------------------------------------------------------------
-- Window assembly
--------------------------------------------------------------------------------

function Perskan:RequestReload()
    self._reloadPending = true
    if self._reloadBanner then self._reloadBanner:Show() end
end

function Perskan:BuildConfig()
    if self._configBuilt then return end
    self._configBuilt = true

    -- Rebrand the framework: a cooler blue accent, distinct from MiniAuras's crimson.
    mini:SetCustomStyling(true)
    mini:SetPalette({
        Accent = { r = 0.16, g = 0.52, b = 0.82 },
        AccentHi = { r = 0.30, g = 0.64, b = 0.94 },
        TitleText = { r = 0.45, g = 0.72, b = 1.0 },
    })

    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or ""

    local windowWidth, windowHeight = 720, 600
    local contentPadding = 12
    local tabStripWidth = 150
    local tabHorizontalPadding = 12
    local windowInset = 2 + contentPadding * 2 + 14
    local contentWidth = windowWidth - windowInset - tabStripWidth - tabHorizontalPadding
    mini.ContentWidth = contentWidth
    mini.TextMaxWidth = contentWidth - windowInset

    local window = mini:CreateStandaloneWindow({
        Name = addonName .. "ConfigFrame",
        Title = "Perskan's Pack",
        Subtitle = version,
        Width = windowWidth,
        Height = windowHeight,
    })
    self._configWindow = window

    -- Recentre when re-opened from hidden.
    local previouslyHidden = true
    window:HookScript("OnHide", function() previouslyHidden = true end)
    window:HookScript("OnShow", function(w)
        if previouslyHidden then
            previouslyHidden = false
            w:ClearAllPoints()
            w:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        if self.RefreshConfig then self:RefreshConfig() end
        if self._reloadPending and self._reloadBanner then self._reloadBanner:Show() end
    end)

    self._reloadBanner = BuildReloadBanner(window)

    -- Nav strip flush with the title bar's accent line and the window's left edge.
    local tabsPanel = CreateFrame("Frame", nil, window)
    tabsPanel:SetPoint("TOPLEFT", window.TitleBar, "BOTTOMLEFT", 0, -1)
    tabsPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -13, 1)

    local refreshers = {}

    local tabs = {
        { Heading = "Settings" },
    }
    for _, category in ipairs(addon.configSchema) do
        tabs[#tabs + 1] = {
            Key = category.key,
            Title = category.title,
            Icon = category.icon,
            Build = function(content)
                refreshers[#refreshers + 1] = BuildCategoryPanel(content, category)
            end,
        }
    end
    tabs[#tabs + 1] = { Heading = "Profile" }
    tabs[#tabs + 1] = {
        Key = "profiles",
        Title = "Profiles",
        Icon = "Interface\\Icons\\INV_Misc_Book_11",
        Build = function(content)
            refreshers[#refreshers + 1] = BuildProfilesPanel(content)
        end,
    }

    mini:CreateTabs({
        Parent = tabsPanel,
        InitialKey = addon.configSchema[1] and addon.configSchema[1].key,
        Vertical = true,
        ScrollBody = true,
        ScrollContentWidth = contentWidth,
        ScrollContentHeight = 10, -- disable the auto-scan; panels set their own height
        ContentInsets = { Top = 4 + contentPadding + 1, Bottom = 40 },
        FooterReserve = 40,
        TabFitToParent = true,
        StripWidth = tabStripWidth + contentPadding,
        HorizontalPadding = tabHorizontalPadding,
        TabIconSize = 22,
        PageHeader = true,
        Tabs = tabs,
    })

    -- Full refresh (values + disabled/hidden reflow) after profile swaps, window show.
    function self:RefreshConfig()
        for _, entry in ipairs(refreshers) do
            pcall(entry.refresh)
        end
    end
    -- Lightweight reflow the live setters call so disabled/hidden states update in
    -- place without re-syncing values (which would interrupt a toggle's animation).
    self._relayoutActive = function()
        for _, entry in ipairs(refreshers) do
            pcall(entry.relayout)
        end
    end

    -- Blizzard AddOns redirect panel for discoverability.
    local redirect = CreateFrame("Frame")
    redirect.name = "Perskan's Pack"
    local category = mini:AddCategory(redirect)
    if category then
        local title = redirect:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
        title:SetPoint("TOP", redirect, "TOP", 0, -60)
        title:SetText("Perskan's Pack")
        local msg = redirect:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        msg:SetPoint("TOP", title, "BOTTOM", 0, -12)
        msg:SetText("Type /perskan (or /pp) to open the settings window.")
        local open = mini:Button({
            Parent = redirect, Text = "Open Settings", Width = 200, Height = 30,
            OnClick = function() Perskan:OpenConfig() end,
        })
        open:SetPoint("TOP", msg, "BOTTOM", 0, -20)
    end
end

function Perskan:OpenConfig()
    if not self._configWindow then
        self:BuildConfig()
    end
    if self._configWindow then
        self._configWindow:Show()
    end
end
