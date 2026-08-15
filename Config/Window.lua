local addonName, addon = ...

-- The settings window, built from Blizzard's own templates: ButtonFrameTemplate for the
-- window, UICheckButtonTemplate / UISliderTemplateWithLabels / WowStyle1DropdownTemplate /
-- UIPanelButtonTemplate for the controls, and a MinimalScrollBar paired to the content
-- through ScrollUtil. No custom widget art anywhere - the game's UI is the design.
--
-- The renderer walks Config/Schema.lua and builds one entry per control, each of which
-- knows how to place itself, refresh its value, and grey itself out.

local SIDEBAR_WIDTH = 170
local PAD = 16
local TOP_PAD = 12
local SPACING = 10
local RIGHT_MARGIN = 26

-- Height of the strip below the insets, and where a 22px button sits in it.
local FOOTER_HEIGHT = 34
local FOOTER_BUTTON_Y = 5

-- Per-control vertical space. Sliders need room above for their value label and below for
-- the min/max labels the template anchors outside the bar.
local TOGGLE_H = 26
local SLIDER_ABOVE, SLIDER_H, SLIDER_BELOW = 22, 20, 14
local SELECT_LABEL_H, SELECT_GAP, SELECT_DD_H = 16, 4, 30
local DIVIDER_H = 24
local BUTTON_H = 26
local COLOR_H = 24

local window, contentChild

local function ContentWidth()
    return 760 - SIDEBAR_WIDTH - PAD * 2 - RIGHT_MARGIN
end

--------------------------------------------------------------------------------
-- Shared behaviour
--------------------------------------------------------------------------------

local function AddTooltip(frame, title, text)
    if not text and not title then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        if text then
            GameTooltip:AddLine(text, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Relayout()
    if Perskan._relayoutActive then Perskan._relayoutActive() end
end

local function ApplyCVarToggle(control, value)
    if control.cvar then
        Perskan:SetCVarValue(control.cvar, value and 1 or 0)
    end
end

local function MakeGet(control)
    if control.get then return control.get end
    local key = control.key

    if control.type == "color" then
        return function()
            local color = Perskan.db.profile[key] or {}
            return color.r or 1, color.g or 1, color.b or 1
        end
    end
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
        -- Explicit setters (Simple Item Level's own saved variables) do their own apply.
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

    if control.type == "color" then
        return function(r, g, b)
            local color = Perskan.db.profile[key]
            if type(color) ~= "table" then
                color = {}
                Perskan.db.profile[key] = color
            end
            color.r, color.g, color.b = r, g, b
            if control.apply then control.apply() end
            if control.reload then Perskan:RequestReload() end
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
        if control.type ~= "range" then Relayout() end
    end
end

--------------------------------------------------------------------------------
-- Controls
--------------------------------------------------------------------------------

local function BuildDivider(parent, control)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetText(control.name)
    header:SetTextColor(1, 0.82, 0)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", header, "RIGHT", 8, 0)
    line:SetColorTexture(0.4, 0.35, 0.28, 0.8)

    return {
        control = control,
        primary = header,
        frames = { header, line },
        above = 6, body = DIVIDER_H, below = 2,
        place = function()
            line:SetPoint("RIGHT", parent, "RIGHT", -RIGHT_MARGIN, 0)
        end,
    }
end

local function BuildToggle(parent, control, get, set)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)

    local label = check.Text or check.text
    if label then
        label:SetFontObject("GameFontHighlight")
        label:SetText(control.name)
        label:ClearAllPoints()
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    end

    check:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
    end)
    AddTooltip(check, control.name, control.desc)

    return {
        control = control,
        primary = check,
        frames = { check },
        above = 0, body = TOGGLE_H, below = 0,
        refresh = function() check:SetChecked(get() and true or false) end,
        setDisabled = function(disabled)
            check:SetEnabled(not disabled)
            if label then
                label:SetFontObject(disabled and "GameFontDisable" or "GameFontHighlight")
            end
        end,
    }
end

local function BuildRange(parent, control, get, set)
    local slider = CreateFrame("Slider", nil, parent, "UISliderTemplateWithLabels")
    slider:SetSize(ContentWidth() - 90, SLIDER_H)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(control.min, control.max)
    slider:SetValueStep(control.step)
    slider:SetObeyStepOnDrag(true)

    slider.Low:SetText(tostring(control.min))
    slider.High:SetText(tostring(control.max))

    -- Name on the line above the bar, as Blizzard's own sliders do.
    slider.Text:ClearAllPoints()
    slider.Text:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
    slider.Text:SetJustifyH("LEFT")

    -- Whole numbers read as integers; fractional steps keep two decimals.
    local function Format(number)
        if control.step and control.step < 1 then
            return string.format("%.2f", number)
        end
        return tostring(math.floor(number + 0.5))
    end

    -- An editable value rather than a label: dragging can't reliably hit an exact number,
    -- least of all on the wider ranges.
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(64, 20)
    box:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    box:SetMaxLetters(8)

    local syncing = false

    local function SyncBox(value)
        syncing = true
        box:SetText(Format(value))
        box:SetCursorPosition(0)
        syncing = false
    end

    -- Typed values are clamped to the range and snapped to the control's step, so the box
    -- can't put the slider somewhere it could never be dragged to.
    local function Commit()
        local typed = tonumber(box:GetText())
        if typed then
            typed = math.max(control.min, math.min(control.max, typed))
            if control.step and control.step > 0 then
                local steps = math.floor(((typed - control.min) / control.step) + 0.5)
                typed = control.min + steps * control.step
            end
            typed = tonumber(Format(typed)) or typed
            slider:SetValue(typed)
            set(typed)
        end
        SyncBox(slider:GetValue())
        box:ClearFocus()
    end

    box:SetScript("OnEnterPressed", Commit)
    box:SetScript("OnEditFocusLost", Commit)
    box:SetScript("OnEscapePressed", function()
        SyncBox(slider:GetValue())
        box:ClearFocus()
    end)

    slider:SetScript("OnValueChanged", function(_, newValue)
        if not box:HasFocus() then
            SyncBox(newValue)
        end
        if syncing then return end
        set(newValue)
    end)
    AddTooltip(slider, control.name, control.desc)

    return {
        control = control,
        primary = slider,
        frames = { slider, box },
        above = SLIDER_ABOVE, body = SLIDER_H, below = SLIDER_BELOW,
        refresh = function()
            syncing = true
            local current = get() or control.min
            slider:SetValue(current)
            SyncBox(current)
            syncing = false
        end,
        setDisabled = function(disabled)
            if disabled then slider:Disable() else slider:Enable() end
            slider.Text:SetFontObject(disabled and "GameFontDisable" or "GameFontHighlight")
            box:EnableMouse(not disabled)
            box:SetTextColor(disabled and 0.5 or 1, disabled and 0.5 or 1, disabled and 0.5 or 1)
        end,
    }
end

local function BuildSelect(parent, control, get, set)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetText(control.name)

    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(240, SELECT_DD_H)
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -SELECT_GAP)

    local function TextFor(value)
        for _, entry in ipairs(control.values) do
            if entry.value == value then return entry.text end
        end
        return tostring(value)
    end

    dropdown:SetupMenu(function(_, rootDescription)
        for _, entry in ipairs(control.values) do
            rootDescription:CreateRadio(entry.text,
                function() return get() == entry.value end,
                function() set(entry.value) end)
        end
    end)
    AddTooltip(dropdown, control.name, control.desc)

    return {
        control = control,
        primary = label,
        frames = { label, dropdown },
        above = 0, body = SELECT_LABEL_H + SELECT_GAP + SELECT_DD_H, below = 0,
        refresh = function()
            dropdown:SetDefaultText(TextFor(get()))
            if dropdown.GenerateMenu then dropdown:GenerateMenu() end
        end,
        setDisabled = function(disabled)
            dropdown:SetEnabled(not disabled)
            label:SetFontObject(disabled and "GameFontDisable" or "GameFontHighlight")
        end,
    }
end

local function BuildColor(parent, control, get, set)
    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetSize(20, 20)

    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(swatch)
    border:SetColorTexture(0, 0, 0, 1)

    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -1, 1)

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetText(control.name)
    label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)

    local function Refresh()
        local r, g, b = get()
        fill:SetColorTexture(r or 1, g or 1, b or 1, 1)
    end

    swatch:SetScript("OnClick", function()
        local r, g, b = get()
        local function OnColorChanged()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            set(newR, newG, newB)
            Refresh()
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = OnColorChanged,
            cancelFunc = function(previous)
                if previous then
                    set(previous.r, previous.g, previous.b)
                    Refresh()
                end
            end,
        })
    end)
    AddTooltip(swatch, control.name, control.desc)

    return {
        control = control,
        primary = swatch,
        frames = { swatch, label },
        above = 0, body = COLOR_H, below = 0,
        refresh = Refresh,
        setDisabled = function(disabled)
            swatch:SetEnabled(not disabled)
            label:SetFontObject(disabled and "GameFontDisable" or "GameFontHighlight")
        end,
    }
end

local function BuildButton(parent, control)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(control.width or 200, BUTTON_H)
    button:SetText(control.name)
    button:SetScript("OnClick", function() control.onClick() end)
    AddTooltip(button, control.name, control.desc)

    return {
        control = control,
        primary = button,
        frames = { button },
        above = 0, body = BUTTON_H, below = 0,
        setDisabled = function(disabled) button:SetEnabled(not disabled) end,
    }
end

local BUILDERS = {
    divider = function(parent, control) return BuildDivider(parent, control) end,
    toggle = BuildToggle,
    range = BuildRange,
    select = BuildSelect,
    color = BuildColor,
    button = function(parent, control) return BuildButton(parent, control) end,
}

--------------------------------------------------------------------------------
-- Category pages
--------------------------------------------------------------------------------

local function BuildCategoryPanel(panel, category)
    local entries = {}
    for _, control in ipairs(category.controls) do
        local builder = BUILDERS[control.type]
        if builder then
            local get, set = MakeGet(control), MakeSet(control)
            entries[#entries + 1] = builder(panel, control, get, set)
        end
    end

    local function RelayoutPanel()
        -- Start below the inset's top edge rather than flush against it.
        local cursor = -TOP_PAD
        for _, entry in ipairs(entries) do
            local hidden = entry.control.hidden and entry.control.hidden()
            entry.primary:ClearAllPoints()
            if hidden then
                for _, frame in ipairs(entry.frames) do frame:Hide() end
            else
                for _, frame in ipairs(entry.frames) do frame:Show() end
                cursor = cursor - entry.above
                entry.primary:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, cursor)
                if entry.place then entry.place() end
                cursor = cursor - entry.body - entry.below - SPACING
                if entry.setDisabled then
                    entry.setDisabled(entry.control.disabled and entry.control.disabled())
                end
            end
        end
        panel:SetHeight(math.max(1, -cursor + 10))
    end

    local function Refresh()
        for _, entry in ipairs(entries) do
            if entry.refresh then entry.refresh() end
        end
        RelayoutPanel()
    end

    Refresh()
    panel:HookScript("OnShow", Refresh)

    return { relayout = RelayoutPanel, refresh = Refresh }
end

--------------------------------------------------------------------------------
-- Profiles page
--------------------------------------------------------------------------------

local function BuildProfilesPanel(panel)
    local db = Perskan.db
    local y = 0
    local refreshers = {}

    local function Header(text, dy)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetText(text)
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
        y = y - (dy or (SELECT_LABEL_H + SELECT_GAP))
        return label
    end

    local function ProfileDropdown(getValue, setValue, includeCurrent, defaultText)
        local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
        dropdown:SetSize(240, SELECT_DD_H)
        dropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
        dropdown:SetupMenu(function(_, rootDescription)
            local current = db:GetCurrentProfile()
            for _, name in ipairs(db:GetProfiles()) do
                if includeCurrent or name ~= current then
                    rootDescription:CreateRadio(name,
                        function() return getValue() == name end,
                        function() setValue(name) end)
                end
            end
        end)
        refreshers[#refreshers + 1] = function()
            dropdown:SetDefaultText(getValue() or defaultText)
        end
        y = y - (SELECT_DD_H + SPACING * 2)
        return dropdown
    end

    Header("Active Profile")
    ProfileDropdown(function() return db:GetCurrentProfile() end,
        function(name) db:SetProfile(name) end, true)

    -- New profile
    local newLabel = Header("New Profile")
    local newBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    newBox:SetSize(240, 22)
    newBox:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 6, y)
    newBox:SetAutoFocus(false)
    y = y - (28 + SPACING)

    local createButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    createButton:SetSize(120, BUTTON_H)
    createButton:SetText("Create")
    createButton:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
    createButton:SetScript("OnClick", function()
        local name = newBox:GetText()
        if name and name:match("%S") then
            db:SetProfile(name)
            newBox:SetText("")
            newBox:ClearFocus()
        end
    end)
    y = y - (BUTTON_H + SPACING * 2)

    -- Copy / delete
    local copyTarget, deleteTarget
    Header("Copy Settings From")
    local copyDropdown = ProfileDropdown(function() return copyTarget end,
        function(name) copyTarget = name; Perskan:RefreshConfig() end, false, "Select a profile")
    local copyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copyButton:SetSize(120, BUTTON_H)
    copyButton:SetText("Copy")
    copyButton:SetPoint("LEFT", copyDropdown, "RIGHT", 8, 0)
    copyButton:SetScript("OnClick", function()
        if copyTarget then db:CopyProfile(copyTarget) end
    end)

    Header("Delete Profile")
    local deleteDropdown = ProfileDropdown(function() return deleteTarget end,
        function(name) deleteTarget = name; Perskan:RefreshConfig() end, false, "Select a profile")
    local deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    deleteButton:SetSize(120, BUTTON_H)
    deleteButton:SetText("Delete")
    deleteButton:SetPoint("LEFT", deleteDropdown, "RIGHT", 8, 0)
    deleteButton:SetScript("OnClick", function()
        if deleteTarget then
            db:DeleteProfile(deleteTarget)
            deleteTarget = nil
            Perskan:RefreshConfig()
        end
    end)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(200, BUTTON_H)
    resetButton:SetText("Reset Current Profile")
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
    resetButton:SetScript("OnClick", function() db:ResetProfile() end)
    y = y - (BUTTON_H + SPACING)

    panel:SetHeight(math.max(1, -y + 10))

    local function Refresh()
        for _, refresher in ipairs(refreshers) do refresher() end
    end
    Refresh()
    panel:HookScript("OnShow", Refresh)

    return { relayout = function() end, refresh = Refresh }
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

function Perskan:RequestReload()
    self._reloadPending = true
    if self._reloadButton then self._reloadButton:Show() end
end

function Perskan:BuildConfig()
    if self._configBuilt then return end
    self._configBuilt = true

    local version = C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata(addonName, "Version") or ""

    window = CreateFrame("Frame", addonName .. "ConfigFrame", UIParent, "ButtonFrameTemplate")
    window:SetSize(760, 620)
    window:SetPoint("CENTER")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetFrameStrata("HIGH")
    window:Hide()
    self._configWindow = window

    -- Escape closes it, the way every stock panel behaves.
    tinsert(UISpecialFrames, window:GetName())

    if window.SetTitle then
        window:SetTitle("Perskan's Pack" .. (version ~= "" and ("  |cff808080" .. version .. "|r") or ""))
    end
    if window.PortraitContainer and window.PortraitContainer.portrait then
        window.PortraitContainer.portrait:SetTexture("Interface\\Icons\\ability_titankeeper_testofconfidence")
    elseif window.portrait then
        window.portrait:SetTexture("Interface\\Icons\\ability_titankeeper_testofconfidence")
    end

    -- Category list on the left, content on the right, both in stock insets.
    local sidebar = CreateFrame("Frame", nil, window, "InsetFrameTemplate")
    sidebar:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -64)
    sidebar:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 8, FOOTER_HEIGHT)
    sidebar:SetWidth(SIDEBAR_WIDTH)

    local contentInset = CreateFrame("Frame", nil, window, "InsetFrameTemplate")
    contentInset:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 6, 0)
    contentInset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, FOOTER_HEIGHT)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentInset)
    scrollFrame:SetPoint("TOPLEFT", contentInset, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentInset, "BOTTOMRIGHT", -22, 4)

    local scrollBar = CreateFrame("EventFrame", nil, contentInset, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 8, 0)
    if ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar then
        ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollBar)
    end

    contentChild = CreateFrame("Frame", nil, scrollFrame)
    contentChild:SetSize(ContentWidth(), 10)
    scrollFrame:SetScrollChild(contentChild)

    -- Reload prompt: a stock button that only appears once something asks for one.
    -- Centred in the strip below the insets, which end FOOTER_HEIGHT above the window's
    -- bottom edge.
    local reloadButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    reloadButton:SetSize(140, 22)
    reloadButton:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -10, FOOTER_BUTTON_Y)
    reloadButton:SetText("Reload UI")
    reloadButton:SetScript("OnClick", function() C_UI.Reload() end)
    reloadButton:Hide()

    -- A region of the button, so it shows and hides with it.
    local reloadText = reloadButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    reloadText:SetPoint("RIGHT", reloadButton, "LEFT", -10, 0)
    reloadText:SetText("Some changes need a UI reload to take effect.")
    reloadText:SetTextColor(1, 0.82, 0)

    self._reloadButton = reloadButton

    --------------------------------------------------------------------------------
    -- Pages and the category list
    --------------------------------------------------------------------------------

    local pages, refreshers, categoryButtons = {}, {}, {}

    local function ShowPage(key)
        for pageKey, page in pairs(pages) do
            page:SetShown(pageKey == key)
        end
        for buttonKey, button in pairs(categoryButtons) do
            button.Selected:SetShown(buttonKey == key)
            button.Label:SetFontObject(buttonKey == key and "GameFontNormal" or "GameFontHighlight")
        end
        scrollFrame:SetVerticalScroll(0)
        contentChild:SetHeight(pages[key] and pages[key]:GetHeight() or 10)
    end

    local listY = -TOP_PAD
    local function AddCategory(key, title, icon, builder)
        local page = CreateFrame("Frame", nil, contentChild)
        page:SetPoint("TOPLEFT", contentChild, "TOPLEFT", 0, 0)
        page:SetWidth(ContentWidth())
        page:Hide()
        pages[key] = page

        local button = CreateFrame("Button", nil, sidebar)
        button:SetSize(SIDEBAR_WIDTH - 12, 26)
        button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, listY)
        listY = listY - 27

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.5)

        local selected = button:CreateTexture(nil, "BACKGROUND")
        selected:SetAllPoints(button)
        selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        selected:SetBlendMode("ADD")
        selected:SetAlpha(0.7)
        selected:Hide()
        button.Selected = selected

        local iconTexture
        if icon then
            iconTexture = button:CreateTexture(nil, "ARTWORK")
            iconTexture:SetSize(18, 18)
            iconTexture:SetPoint("LEFT", button, "LEFT", 4, 0)
            iconTexture:SetTexture(icon)
            iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", iconTexture or button, iconTexture and "RIGHT" or "LEFT", 6, 0)
        label:SetJustifyH("LEFT")
        label:SetText(title)
        button.Label = label

        button:SetScript("OnClick", function()
            ShowPage(key)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)

        categoryButtons[key] = button
        refreshers[#refreshers + 1] = builder(page)
        page:SetHeight(page:GetHeight())
    end

    for _, category in ipairs(addon.configSchema) do
        AddCategory(category.key, category.title, category.icon, function(page)
            return BuildCategoryPanel(page, category)
        end)
    end
    listY = listY - 10
    AddCategory("profiles", "Profiles", "Interface\\Icons\\INV_Misc_Book_11", BuildProfilesPanel)

    function self:RefreshConfig()
        for _, entry in ipairs(refreshers) do
            pcall(entry.refresh)
        end
        for key, page in pairs(pages) do
            if page:IsShown() then
                contentChild:SetHeight(page:GetHeight())
            end
        end
    end

    self._relayoutActive = function()
        for _, entry in ipairs(refreshers) do
            pcall(entry.relayout)
        end
        for _, page in pairs(pages) do
            if page:IsShown() then
                contentChild:SetHeight(page:GetHeight())
            end
        end
    end

    window:HookScript("OnShow", function()
        self:RefreshConfig()
        if self._reloadPending then reloadButton:Show() end
    end)

    ShowPage(addon.configSchema[1] and addon.configSchema[1].key or "profiles")

    -- Discoverability: a stub in the game's AddOns options that opens this window.
    local panel = CreateFrame("Frame")
    panel.name = "Perskan's Pack"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Perskan's Pack")
    local message = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    message:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    message:SetText("Type /perskan (or /pp) to open the settings window.")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 26)
    open:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -16)
    open:SetText("Open Settings")
    open:SetScript("OnClick", function() Perskan:OpenConfig() end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function Perskan:OpenConfig()
    if not self._configWindow then
        self:BuildConfig()
    end
    if self._configWindow then
        self._configWindow:SetShown(not self._configWindow:IsShown())
    end
end
