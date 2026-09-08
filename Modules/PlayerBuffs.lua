-- Player buff row with a per-spell blacklist, built on 12.1's aura containers.
--
-- 12.0 took buff filtering away: the UnitAura APIs hand back secrets and unit-frame
-- auras became engine-owned, so an addon could no longer look at a buff and decide
-- not to draw it. 12.1 gave the filtering back, but only through the engine. An
-- AuraContainer tracks, filters, sorts and creates its own AuraButtons; we only dress
-- them up, and `candidateFilters.excludeSpellIDs` on an aura group *is* the blacklist.
-- Spell-ID matching is permitted for helpful auras on assistable units - the player
-- included - so hiding your own buffs is fair game again (the rule is spelled out in
-- ValidateCandidateFilters, Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua).
--
-- Blizzard's own BuffFrame is not part of that. In 12.1 it still builds its icons from
-- AuraUtil.ForEachAura into its own auraInfo table, with no filter hook to hand a
-- blacklist to (only the target frame was moved onto a ManagedAuraContainer). So this
-- module hides BuffFrame and draws the row from our own container. DebuffFrame is a
-- separate frame and is left alone.
--
-- Edit Mode still owns the buff frame. While it is open we stand aside completely -
-- our row hides, the default frame stays shown, so it can be moved and configured as
-- usual - and on the way out we read Blizzard's own layout back off
-- BuffFrame.AuraContainer (iconStride, iconPadding, iconScale, isHorizontal,
-- addIconsToRight/addIconsToTop) and anchor to the frame corner for corner. That way
-- the Edit Mode aura settings drive our row instead of being ignored.
--
-- Shift+right-click hides the buff under the cursor. The arrow at the end of the row
-- opens the hidden list, where shift+right-click puts one back.
--
-- Why hiding only works while auras are readable
-- ----------------------------------------------
-- AuraButtons carry Forbidden Aspects - UntrustedScriptExecution, ScriptedInput,
-- QueryFocus, AlwaysPropagateInput - so we cannot script them, cannot ask which one
-- the mouse is over, and IsShown returns a secret. "Which buff did I just click" has
-- to come from our own read of the aura list, and that read is only legal while auras
-- are not secret: out of combat, outside encounters, M+ and PvP. To land on the same
-- icon the container did, we read the same set the group asks for (HELPFUL minus the
-- blacklist) and sort it with the very comparator the container uses for
-- AuraContainerSortMethod.Default, AuraUtil.DefaultAuraCompare.
--
-- While auras are secret the shift overlay still arms, but as one pane that swallows
-- the click and says why - otherwise a shift+right-click would fall through to the
-- aura button and cancel the buff instead of hiding it.
--
-- Nothing here reads aura data out of a container, hooks an AuraButton, or writes to
-- one; the container is ours, and the filtering happens engine-side. That is what
-- keeps this clear of the cooldown viewer's secure-aura-map problem (see the comment
-- at the top of Modules/BuffBars.lua).

-- Fixed art sizes, from Blizzard's AuraButtonArtTemplate (a 30x30 icon in a 30x40
-- slot, the duration text filling the rest) and its CollapseAndExpandButton (15x30).
local ICON_SIZE   = 30
local SLOT_HEIGHT = 40
local ARROW_WIDTH = 15
local ICON_INSET  = SLOT_HEIGHT - ICON_SIZE   -- the icon sits at the top of its slot

-- Everything else is read off Blizzard's own buff container, so Edit Mode's aura
-- settings still drive the row: iconStride is icons per line, iconPadding the gap,
-- iconScale the size, isHorizontal the orientation, and addIconsToRight/addIconsToTop
-- the corner it grows from. Defaults here match AuraContainerTemplate's KeyValues
-- (stride 8, padding 5, growing leftwards and down from the top right) with
-- BUFF_MAX_DISPLAY worth of icons.
local layout = {
    perLine    = 8,
    spacing    = 5,
    scale      = 1,
    horizontal = true,
    toRight    = false,
    toTop      = false,
    maxAuras   = 32,
}

local function ReadBlizzardLayout()
    local auraContainer = BuffFrame and BuffFrame.AuraContainer
    if not auraContainer then return end

    layout.perLine    = tonumber(auraContainer.iconStride) or layout.perLine
    layout.spacing    = tonumber(auraContainer.iconPadding) or layout.spacing
    layout.scale      = tonumber(auraContainer.iconScale) or 1
    layout.horizontal = auraContainer.isHorizontal ~= false
    layout.toRight    = auraContainer.addIconsToRight and true or false
    layout.toTop      = auraContainer.addIconsToTop and true or false
    layout.maxAuras   = tonumber(BuffFrame.maxAuras) or layout.maxAuras

    if layout.perLine < 1 then layout.perLine = 1 end
    if layout.maxAuras < 1 then layout.maxAuras = 1 end
end

-- The corner the row grows out of, and the sign of an offset from it.
local function GrowthCorner()
    return (layout.toTop and "BOTTOM" or "TOP") .. (layout.toRight and "LEFT" or "RIGHT")
end

local function GrowthSigns()
    return layout.toRight and 1 or -1, layout.toTop and 1 or -1
end

-- Pitch along the line, and from one line to the next.
local function LinePitch()
    return (layout.horizontal and ICON_SIZE or SLOT_HEIGHT) + layout.spacing
end

local function CrossPitch()
    return (layout.horizontal and SLOT_HEIGHT or ICON_SIZE) + layout.spacing
end

local function LineCount()
    return math.ceil(layout.maxAuras / layout.perLine)
end

-- Span the flow layout may fill before it wraps to the next line.
local function MaximumLineSize()
    local primary = layout.horizontal and ICON_SIZE or SLOT_HEIGHT
    return layout.perLine * primary + (layout.perLine - 1) * layout.spacing
end

local function GridSize()
    local along = MaximumLineSize()
    local lines = LineCount()
    local across = lines * (layout.horizontal and SLOT_HEIGHT or ICON_SIZE)
        + (lines - 1) * layout.spacing
    if layout.horizontal then
        return along, across
    end
    return across, along
end

local holder, container, expander, hiddenPanel, combatPane
local overlays, hiddenRows = {}, {}
local ApplyLayout           -- defined once every frame it touches exists
local visibleAuras          -- index -> aura data, only while the shift overlay is armed
local armed = false

local function profile() return Perskan.db.profile end

-- The blacklist: [spellID] = true. Kept in the profile so it follows profile switches.
local function hiddenBuffs()
    local list = profile().hiddenBuffs
    if type(list) ~= "table" then
        list = {}
        profile().hiddenBuffs = list
    end
    return list
end

-- Saved variables can come back with the spell IDs as strings; the engine wants numbers.
local function BuildExcludeMap()
    local map = {}
    for key, on in pairs(hiddenBuffs()) do
        local spellID = tonumber(key)
        if spellID and on then
            map[spellID] = true
        end
    end
    return map
end

local function HiddenSpellIDs()
    local ids = {}
    for spellID in pairs(BuildExcludeMap()) do
        ids[#ids + 1] = spellID
    end
    return ids
end

local function SpellDisplay(spellID)
    local name, icon
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            name, icon = info.name, info.iconID
        end
    end
    if not name and C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    end
    if not icon and C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(spellID)
    end
    return name or ("Spell " .. spellID), icon or 134400
end

--------------------------------------------------------------------------------
-- Reading the buffs ourselves, to map a clicked slot back to a spell ID
--------------------------------------------------------------------------------

-- Stand-in for AuraUtil.DefaultAuraCompare on a client that doesn't expose it. Same
-- ordering: your own auras first, then priority auras, then ones you could apply,
-- then aura instance ID.
local function FallbackAuraCompare(a, b)
    local aMine = (a.sourceUnit ~= nil) and UnitIsUnit("player", a.sourceUnit) or false
    local bMine = (b.sourceUnit ~= nil) and UnitIsUnit("player", b.sourceUnit) or false
    if aMine ~= bMine then return aMine end
    if a.isPriorityAura ~= b.isPriorityAura then return a.isPriorityAura and true or false end
    if a.canApplyAura ~= b.canApplyAura then return a.canApplyAura and true or false end
    return (a.auraInstanceID or 0) < (b.auraInstanceID or 0)
end

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- The buffs the container is showing, in container order, or nil while auras are
-- secret. Every read goes through pcall: the index-based aura APIs raise a Lua error
-- from addon code the moment auras are secret, which is the state we bail out on.
local function ReadVisibleBuffs()
    if InCombatLockdown() then return nil end
    if not (AuraUtil and AuraUtil.ForEachAura) then return nil end

    local excluded = BuildExcludeMap()
    local auras, secret = {}, false

    local ok = pcall(AuraUtil.ForEachAura, "player", "HELPFUL", nil, function(auraData)
        if not auraData or IsSecret(auraData.spellId) or IsSecret(auraData.auraInstanceID) then
            secret = true
            return true
        end
        if not excluded[auraData.spellId] then
            auras[#auras + 1] = auraData
        end
        -- Read the lot: the container picks its maxFrameCount off the *sorted* list,
        -- so stopping early at the icon limit could keep a different set than it shows.
        return false
    end, true)

    if not ok or secret then return nil end

    table.sort(auras, AuraUtil.DefaultAuraCompare or FallbackAuraCompare)
    while #auras > layout.maxAuras do
        table.remove(auras)
    end
    return auras
end

--------------------------------------------------------------------------------
-- The container
--------------------------------------------------------------------------------

local function EnumValue(enumTable, key, fallback)
    local value = enumTable and enumTable[key]
    if type(value) == "number" then return value end
    return fallback
end

-- Dress one AuraButton. Called once per button the container creates; the button is
-- recycled between auras, so nothing here may assume which aura it holds.
local function InitAuraButton(button)
    -- Region for region, this is Blizzard's AuraButtonArtTemplate. The icon is drawn
    -- uncropped on purpose: WoW icon art has its border baked into the file, so
    -- trimming the edge (the usual 0.07-0.93 texcoords) is what makes an icon look
    -- borderless next to the default UI.
    button:SetSize(ICON_SIZE, SLOT_HEIGHT)

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOP", button, "TOP", 0, 0)
    button:SetIcon(icon)
    button.PerskanIcon = icon

    local duration = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    duration:SetPoint("TOP", icon, "BOTTOM", 0, 0)
    button:SetDurationText(duration)

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    button:SetApplicationCount(count, {})

    -- Right-click cancels, the way Blizzard's buff icons do. Cancelling is engine
    -- side (C_UnitAuras.CancelAuraByInstanceID on a secret instance ID), so it keeps
    -- working in combat where we can't read anything.
    if button.SetCancelAuraButtons then
        pcall(button.SetCancelAuraButtons, button, "RightButtonUp")
    end
end

-- Temporary weapon enchants get the border Blizzard draws on them.
local function InitEnchantButton(button)
    InitAuraButton(button)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-TempEnchant-Border")
    border:SetSize(32, 32)
    border:SetPoint("CENTER", button.PerskanIcon or button, "CENTER", 0, 0)
end

local function CreateContainer()
    if container then return true end
    if not (CreateFrame and BuffFrame) then return false end

    ReadBlizzardLayout()

    holder = CreateFrame("Frame", "PerskanPlayerBuffs", UIParent)
    holder:SetClampedToScreen(true)

    local created, frame = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    if not created or not frame then
        holder:Hide()
        holder = nil
        return false
    end
    container = frame

    local ok = pcall(function()
        container:SetUnit("player")
        container:AddAuraGroup("buffs", "HELPFUL", {
            maxFrameCount = layout.maxAuras,
            sortMethod = EnumValue(AuraContainerSortMethod, "Default", 0),
            sortDirection = EnumValue(AuraContainerSortDirection, "Normal", 0),
            candidateFilters = { excludeSpellIDs = BuildExcludeMap() },
            initializeFrame = InitAuraButton,
        })
    end)
    if not ok then
        container:Hide()
        container = nil
        holder:Hide()
        holder = nil
        return false
    end

    -- Temporary weapon enchants, after the buffs so the buff slots stay 1..N and the
    -- click mapping doesn't have to account for them.
    pcall(function()
        local slots = AuraContainerItemEnchantmentSlot
        if not slots then return end
        for _, slot in ipairs({ slots.MainHand, slots.OffHand, slots.Ranged }) do
            container:AddItemEnchantment(slot, { initializeFrame = InitEnchantButton })
        end
    end)

    return true
end

--------------------------------------------------------------------------------
-- Hiding Blizzard's buff frame
--------------------------------------------------------------------------------

-- Is Edit Mode holding the buff frame open? While it is, the frame is Blizzard's to
-- show, move and configure, and we keep out of the way entirely.
local function EditModeActive()
    if BuffFrame and BuffFrame.IsEditing then
        local ok, editing = pcall(BuffFrame.IsEditing, BuffFrame)
        if ok then return editing and true or false end
    end
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive then
        local ok, active = pcall(EditModeManagerFrame.IsEditModeActive, EditModeManagerFrame)
        if ok then return active and true or false end
    end
    return false
end

-- Same shape as Modules/HideElements.lua: hide it once and keep it hidden with a
-- gated hook, and only ever reverse our own hide. BuffFrame shows itself again from
-- its own aura update (self:SetShown), so both entry points need the hook.
local function HideBlizzardBuffFrame()
    local frame = BuffFrame
    if not frame then return end

    if not frame._perskanBuffRowHooked then
        frame._perskanBuffRowHooked = true
        local function reassert(self)
            if profile().filterPlayerBuffs and not EditModeActive() then
                self:Hide()
            end
        end
        hooksecurefunc(frame, "Show", reassert)
        hooksecurefunc(frame, "SetShown", function(self, shown)
            if shown then reassert(self) end
        end)
    end

    if not EditModeActive() then
        frame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Shift overlay: the click target that turns a slot into a spell ID
--------------------------------------------------------------------------------

-- Where slot `index`'s icon sits relative to the holder's growth corner, mirroring
-- the flow layout: along the line for perLine slots, then on to the next line. The
-- arrow takes the first ARROW_WIDTH pixels along the line.
local function SlotOffset(index)
    local line = math.floor((index - 1) / layout.perLine)
    local slot = (index - 1) % layout.perLine
    local xSign, ySign = GrowthSigns()
    local along = ARROW_WIDTH + slot * LinePitch()
    local across = line * CrossPitch()
    -- Growing upwards anchors from a BOTTOM corner, where the icon is a slot's worth
    -- of duration text above the bottom edge.
    local iconInset = layout.toTop and ICON_INSET or 0

    if layout.horizontal then
        return xSign * along, ySign * (across + iconInset)
    end
    return xSign * across, ySign * (along + iconInset)
end

local HideBuffAt

local function EnsureOverlay(index)
    local overlay = overlays[index]
    if overlay then return overlay end

    overlay = CreateFrame("Button", nil, holder)
    overlay:SetSize(ICON_SIZE, ICON_SIZE)
    -- Above the container's own buttons, but deaf to mouse motion so the aura
    -- button underneath still owns the tooltip.
    pcall(overlay.SetFrameLevel, overlay, container:GetFrameLevel() + 20)
    overlay:SetMouseMotionEnabled(false)
    -- Right-click only. Passing the other buttons through with
    -- SetPassThroughButtons is not an option: it is protected, so calling it from an
    -- addon raises ADDON_ACTION_BLOCKED. Swallowing shift+left/middle over an icon
    -- costs nothing - buffs have no action on those buttons.
    overlay:RegisterForClicks("RightButtonUp")

    local marker = overlay:CreateTexture(nil, "OVERLAY")
    marker:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    marker:SetSize(16, 16)
    marker:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 4, 4)

    local tint = overlay:CreateTexture(nil, "ARTWORK")
    tint:SetAllPoints(overlay)
    tint:SetColorTexture(0, 0, 0, 0.4)

    overlay:SetScript("OnClick", function(self)
        if IsShiftKeyDown() then
            HideBuffAt(self.slotIndex)
        end
    end)

    overlays[index] = overlay
    return overlay
end

-- One pane over the whole row for when we can't read the aura list. Without it a
-- shift+right-click would reach the aura button and cancel the buff.
local function EnsureCombatPane()
    if combatPane then return combatPane end

    combatPane = CreateFrame("Button", nil, holder)
    pcall(combatPane.SetFrameLevel, combatPane, container:GetFrameLevel() + 20)
    combatPane:SetMouseMotionEnabled(false)
    combatPane:RegisterForClicks("RightButtonUp")
    combatPane:SetScript("OnClick", function()
        Perskan:Print("Buffs can only be hidden while auras are readable - out of combat, "
            .. "and outside encounters, Mythic+ and rated PvP.")
    end)

    if ApplyLayout then ApplyLayout() end
    return combatPane
end

local function Disarm()
    armed = false
    visibleAuras = nil
    for _, overlay in pairs(overlays) do
        overlay:Hide()
    end
    if combatPane then combatPane:Hide() end
end

local function Arm()
    if not (container and holder) then return end
    if not profile().filterPlayerBuffs then return end
    if EditModeActive() then return end

    armed = true
    visibleAuras = ReadVisibleBuffs()

    if not visibleAuras then
        for _, overlay in pairs(overlays) do
            overlay:Hide()
        end
        EnsureCombatPane():Show()
        return
    end

    if combatPane then combatPane:Hide() end

    for index = 1, layout.maxAuras do
        if visibleAuras[index] then
            local overlay = EnsureOverlay(index)
            local corner = GrowthCorner()
            local x, y = SlotOffset(index)
            overlay:ClearAllPoints()
            overlay:SetPoint(corner, holder, corner, x, y)
            overlay.slotIndex = index
            overlay:Show()
        elseif overlays[index] then
            overlays[index]:Hide()
        end
    end
end

local function Rearm()
    if armed then Arm() end
end

--------------------------------------------------------------------------------
-- The hidden list
--------------------------------------------------------------------------------

local RefreshHiddenPanel

local function UnhideBuff(spellID)
    hiddenBuffs()[spellID] = nil
    -- Older saves may hold the ID as a string key.
    hiddenBuffs()[tostring(spellID)] = nil
    Perskan:ApplyPlayerBuffFilter()

    local name = SpellDisplay(spellID)
    Perskan:Print(("%s is visible again."):format(name))
end

function HideBuffAt(index)
    local aura = visibleAuras and index and visibleAuras[index]
    if not aura then return end

    hiddenBuffs()[aura.spellId] = true
    Perskan:ApplyPlayerBuffFilter()
    Perskan:Print(("Hiding %s. Shift+right-click it in the hidden list (the arrow at the "
        .. "end of the buff row) to bring it back."):format(aura.name or ("spell " .. aura.spellId)))
end

local function EnsureHiddenPanel()
    if hiddenPanel then return hiddenPanel end

    hiddenPanel = CreateFrame("Frame", nil, holder, "TooltipBackdropTemplate")
    hiddenPanel:SetSize(220, 40)
    hiddenPanel:SetFrameStrata("DIALOG")
    hiddenPanel:SetClampedToScreen(true)
    hiddenPanel:Hide()

    local title = hiddenPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", hiddenPanel, "TOPLEFT", 12, -10)
    title:SetText("Hidden Buffs")
    hiddenPanel.Title = title

    local hint = hiddenPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    hint:SetText("Shift+right-click to show again")
    hiddenPanel.Hint = hint

    local empty = hiddenPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    empty:SetText("Nothing hidden yet.")
    hiddenPanel.Empty = empty

    if ApplyLayout then ApplyLayout() end
    return hiddenPanel
end

local function EnsureHiddenRow(index)
    local row = hiddenRows[index]
    if row then return row end

    row = CreateFrame("Button", nil, hiddenPanel)
    row:SetSize(196, 22)
    row:RegisterForClicks("RightButtonUp")

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Icon = icon

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    row.Label = label

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetColorTexture(1, 1, 1, 0.1)

    row:SetScript("OnClick", function(self)
        if IsShiftKeyDown() and self.spellID then
            UnhideBuff(self.spellID)
        end
    end)

    hiddenRows[index] = row
    return row
end

function RefreshHiddenPanel()
    if not hiddenPanel then return end

    local ids = HiddenSpellIDs()
    local names = {}
    for _, spellID in ipairs(ids) do
        names[spellID] = (SpellDisplay(spellID))
    end
    table.sort(ids, function(a, b) return names[a] < names[b] end)

    for index, row in pairs(hiddenRows) do
        if not ids[index] then row:Hide() end
    end

    local previous
    for index, spellID in ipairs(ids) do
        local row = EnsureHiddenRow(index)
        local name, icon = SpellDisplay(spellID)
        row.spellID = spellID
        row.Icon:SetTexture(icon)
        row.Label:SetText(name)
        row:ClearAllPoints()
        if previous then
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
        else
            row:SetPoint("TOPLEFT", hiddenPanel.Hint, "BOTTOMLEFT", 0, -8)
        end
        row:Show()
        previous = row
    end

    hiddenPanel.Empty:SetShown(#ids == 0)
    hiddenPanel:SetHeight(58 + math.max(#ids, 1) * 24)
end

local function ToggleHiddenPanel()
    local panel = EnsureHiddenPanel()
    if panel:IsShown() then
        panel:Hide()
        return
    end
    RefreshHiddenPanel()
    panel:Show()
end

local function EnsureExpander()
    if expander then return expander end

    -- Same art as BuffFrame's own collapse button, a 10x16 `bag-arrow`, and the same
    -- spot: the corner the row grows out of. ApplyLayout sizes and places it.
    expander = CreateFrame("Button", nil, holder)

    local arrow = expander:CreateTexture(nil, "ARTWORK")
    arrow:SetAtlas("bag-arrow")
    arrow:SetPoint("CENTER", expander, "CENTER", 0, 0)
    expander.Arrow = arrow

    local highlight = expander:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAtlas("bag-arrow")
    highlight:SetPoint("CENTER", expander, "CENTER", 0, 0)
    highlight:SetAlpha(0.4)
    highlight:SetBlendMode("ADD")
    expander.Highlight = highlight

    expander:SetScript("OnClick", ToggleHiddenPanel)
    expander:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Hidden Buffs")
        GameTooltip:AddLine(("%d hidden"):format(#HiddenSpellIDs()), 1, 1, 1)
        GameTooltip:AddLine("Shift+right-click a buff to hide it.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    expander:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if ApplyLayout then ApplyLayout() end
    return expander
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

-- Push the mirrored numbers onto every frame. Safe to call whenever Blizzard's own
-- change: Edit Mode closing, a layout switch, or a frame we only just created.
function ApplyLayout()
    if not (holder and container) then return end

    local corner = GrowthCorner()
    local xSign, ySign = GrowthSigns()
    local gridWidth, gridHeight = GridSize()

    holder:SetScale(layout.scale)
    if layout.horizontal then
        holder:SetSize(gridWidth + ARROW_WIDTH, gridHeight)
    else
        holder:SetSize(gridWidth, gridHeight + ARROW_WIDTH)
    end
    -- Park on Blizzard's (hidden) buff frame corner for corner, so Edit Mode still
    -- decides where the row sits.
    holder:ClearAllPoints()
    holder:SetPoint(corner, BuffFrame, corner, 0, 0)

    pcall(function()
        container:ClearAllPoints()
        if layout.horizontal then
            container:SetPoint(corner, holder, corner, xSign * ARROW_WIDTH, 0)
        else
            container:SetPoint(corner, holder, corner, 0, ySign * ARROW_WIDTH)
        end

        container:SetFlowLayoutAxis(layout.horizontal and AnchorUtil.FlowLayoutAxis.Horizontal
            or AnchorUtil.FlowLayoutAxis.Vertical)
        container:SetFlowLayoutAnchorPoint(corner)
        container:SetFlowLayoutGrowthDirection(
            layout.toRight and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left,
            layout.toTop and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
        container:SetFlowLayoutMaximumLineSize(MaximumLineSize())

        container:SetAuraGroupMaxFrameCount("buffs", layout.maxAuras)
        container:SetAuraGroupLayout("buffs", {
            elementWidth = ICON_SIZE,
            elementHeight = SLOT_HEIGHT,
            elementSpacing = layout.spacing,
            lineSpacing = layout.spacing,
        })
        container:SetItemEnchantmentLayout({
            placement = EnumValue(CustomAuraContainerItemEnchantmentPlacement, "AfterAuraGroups", 1),
            elementWidth = ICON_SIZE,
            elementHeight = SLOT_HEIGHT,
            elementSpacing = layout.spacing,
            lineSpacing = layout.spacing,
        })
    end)

    if expander then
        expander:ClearAllPoints()
        expander:SetSize(layout.horizontal and ARROW_WIDTH or ICON_SIZE,
            layout.horizontal and ICON_SIZE or ARROW_WIDTH)
        expander:SetPoint(corner, holder, corner, 0, layout.toTop and ICON_INSET or 0)

        -- Point it away from the icons. Rotation only, the way
        -- CollapseAndExpandButtonMixin:UpdateOrientation does it - the texture stays
        -- 10x16 and an atlas texture can't be flipped with texcoords anyway.
        local rotation
        if layout.horizontal then
            rotation = layout.toRight and math.pi or 0
        else
            rotation = layout.toTop and (math.pi / 2) or (3 * math.pi / 2)
        end
        for _, texture in ipairs({ expander.Arrow, expander.Highlight }) do
            texture:SetSize(10, 16)
            texture:SetRotation(rotation)
        end
    end

    if combatPane then
        combatPane:ClearAllPoints()
        combatPane:SetSize(gridWidth, gridHeight)
        if layout.horizontal then
            combatPane:SetPoint(corner, holder, corner, xSign * ARROW_WIDTH, 0)
        else
            combatPane:SetPoint(corner, holder, corner, 0, ySign * ARROW_WIDTH)
        end
    end

    if hiddenPanel then
        -- Hangs off the arrow, away from the row.
        local side = layout.toRight and "LEFT" or "RIGHT"
        hiddenPanel:ClearAllPoints()
        hiddenPanel:SetPoint((layout.toTop and "BOTTOM" or "TOP") .. side,
            expander or holder, (layout.toTop and "TOP" or "BOTTOM") .. side,
            0, layout.toTop and 6 or -6)
    end
end

-- Edit Mode owns the buff frame while it is open: stand aside completely so it can
-- be moved and configured, then take its numbers when it closes. Blizzard shows the
-- frame itself on the way in (AuraFrameEditModeMixin:ShouldBeShown is true while
-- editing) and our hide hook defers to that, so there is nothing to show here.
local function ApplyEditModeState(editing)
    if editing then
        Disarm()
        if hiddenPanel then hiddenPanel:Hide() end
        if holder then holder:Hide() end
        return
    end

    ReadBlizzardLayout()
    ApplyLayout()
    if holder then holder:Show() end
    HideBlizzardBuffFrame()
end

--------------------------------------------------------------------------------
-- Live apply
--------------------------------------------------------------------------------

-- Push the blacklist into the container's aura group. The engine re-filters from
-- there, so nothing has to be redrawn by hand.
function Perskan:ApplyPlayerBuffFilter()
    if container then
        pcall(container.SetAuraGroupCandidateFilters, container, "buffs",
            { excludeSpellIDs = BuildExcludeMap() })
    end
    if hiddenPanel and hiddenPanel:IsShown() then
        RefreshHiddenPanel()
    end
    Rearm()
end

-- Also reachable from the settings window, for when the arrow is behind something.
function Perskan:ToggleHiddenBuffList()
    if not holder then
        self:Print("The filterable buff row isn't running - enable it under "
            .. "Unit Frames -> Player Buffs and reload.")
        return
    end
    ToggleHiddenPanel()
end

function Perskan:ClearHiddenBuffs()
    local list = hiddenBuffs()
    for key in pairs(list) do
        list[key] = nil
    end
    self:ApplyPlayerBuffFilter()
    self:Print("Hidden buff list cleared.")
end

function Perskan:CountHiddenBuffs()
    return #HiddenSpellIDs()
end

--------------------------------------------------------------------------------

Perskan:RegisterModule("PlayerBuffs", function(self)
    if not CreateContainer() then
        -- No aura containers on this client (pre-12.1): leave Blizzard's buff frame
        -- alone rather than hiding it with nothing to replace it.
        self:Print("Buff filtering needs Midnight 12.1's aura containers; leaving the "
            .. "default buff frame in place.")
        return
    end

    HideBlizzardBuffFrame()
    EnsureExpander()
    ApplyLayout()

    -- Follow Edit Mode in and out. hooksecurefunc, not HookScript: this must not run
    -- inside Blizzard's own execution (see the objective tracker rule in CLAUDE.md).
    if BuffFrame.SetIsEditing and not BuffFrame._perskanEditModeHooked then
        BuffFrame._perskanEditModeHooked = true
        hooksecurefunc(BuffFrame, "SetIsEditing", function(_, editing)
            ApplyEditModeState(editing and true or false)
        end)
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "MODIFIER_STATE_CHANGED" then
            if arg1 == "LSHIFT" or arg1 == "RSHIFT" then
                if IsShiftKeyDown() then Arm() else Disarm() end
            end
        elseif event == "UNIT_AURA" then
            -- The payload is secret in combat; we never read it, we just re-read the
            -- list ourselves when the overlay is up and that read is legal.
            if arg1 == "player" then Rearm() end
        elseif event == "PLAYER_REGEN_DISABLED" then
            if armed then Arm() end
        elseif event == "PLAYER_REGEN_ENABLED" then
            Rearm()
        elseif event == "PLAYER_ENTERING_WORLD" then
            HideBlizzardBuffFrame()
            ReadBlizzardLayout()
            ApplyLayout()
        elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
            -- A saved layout can move the frame or change the aura settings.
            ApplyEditModeState(EditModeActive())
        end
    end)
end, "filterPlayerBuffs")
