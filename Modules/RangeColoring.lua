-- Colour action button icons by whether the action can actually be used right now:
-- red when the target is out of range, blue when you're short on power, dim grey when
-- it's unusable for any other reason.
--
-- Ported from tullaRange 12.1.3 by Tuller (MIT), using the event-driven range API
-- Blizzard added in 10.1.5 rather than an OnUpdate poll: buttons repaint from their
-- own UpdateUsable and from ActionButton_UpdateRangeIndicator.
--
-- This is the colour channel; Modules/GreyOnCooldown.lua owns desaturation. Keeping
-- them apart means the two features stack instead of fighting over the same icon
-- property (a greyed-out cooldown still reads as red when it's also out of range).

local COLORS = {
    normal   = { 1, 1, 1, 1 },
    oor      = { 1, 0.3, 0.1, 1 },
    oom      = { 0.1, 0.3, 1, 1 },
    unusable = { 0.4, 0.4, 0.4, 1 },
}

local registered = {}   -- button -> true
local iconState = {}    -- icon/hotkey region -> last state applied
local enabled = false
local hooksInstalled = false
local updateQueued = false

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

-- Macros named with a leading "#" get their usability from the spell they resolve to,
-- so a mana-starved macro reads as out of power instead of just "unusable".
local function GetActionState(slot)
    local actionType, id = GetActionInfo(slot)
    local isUsable, notEnoughMana

    if actionType == "macro" then
        local name = GetMacroInfo(id)
        if name and name:sub(1, 1) == "#" then
            local spellID = GetMacroSpell(id)
            if spellID then
                isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
            end
        end
    end

    if isUsable == nil then
        isUsable, notEnoughMana = IsUsableAction(slot)
    end

    local outOfRange = IsActionInRange(slot) == false
    if isUsable then
        return outOfRange and "oor" or "normal", outOfRange
    end
    return notEnoughMana and "oom" or "unusable", outOfRange
end

local function GetPetActionState(index)
    local _, _, _, _, _, _, spellID, checksRange, inRange = GetPetActionInfo(index)
    local outOfRange = checksRange and not inRange
    local isUsable, notEnoughMana

    if spellID then
        isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
    else
        isUsable = GetPetActionSlotUsable(index)
        notEnoughMana = false
    end

    if isUsable then
        return outOfRange and "oor" or "normal", outOfRange
    end
    return notEnoughMana and "oom" or "unusable", outOfRange
end

--------------------------------------------------------------------------------
-- Painting
--------------------------------------------------------------------------------

local function PaintRegion(region, state)
    if not region then return end
    iconState[region] = state
    local color = COLORS[state] or COLORS.normal
    region:SetVertexColor(color[1], color[2], color[3], color[4])
end

local function UpdateActionButton(button)
    if not enabled or not button.icon or not button.action then return end

    local state, outOfRange = GetActionState(button.action)
    PaintRegion(button.icon, state)

    if Perskan.db.profile.rangeColoringHotkeys then
        PaintRegion(button.HotKey, outOfRange and "oor" or "normal")
    end
end

-- The range event only ever moves a button between normal and out-of-range; leave any
-- other state (no power, unusable) alone so it isn't stomped by a range tick.
local function UpdateActionButtonRange(button, checksRange, inRange)
    if not enabled or not registered[button] then return end

    local outOfRange = checksRange and not inRange

    local function Retint(region)
        if not region then return end
        local current = iconState[region]
        if current == "normal" and outOfRange then
            PaintRegion(region, "oor")
        elseif current == "oor" and not outOfRange then
            PaintRegion(region, "normal")
        end
    end

    Retint(button.icon)
    if Perskan.db.profile.rangeColoringHotkeys then
        Retint(button.HotKey)
    end
end

local function UpdatePetBar(bar)
    if not enabled or not Perskan.db.profile.rangeColoringPetBar then return end
    if not bar or not bar.actionButtons or not PetHasActionBar() then return end

    for index, button in pairs(bar.actionButtons) do
        if button.icon and button.icon:IsVisible() then
            PaintRegion(button.icon, (GetPetActionState(index)))
        end
    end
end

-- Hand a button back to Blizzard's own colouring.
local function ResetButton(button)
    if button.icon then
        iconState[button.icon] = nil
    end
    if button.HotKey then
        iconState[button.HotKey] = nil
    end
    if type(button.UpdateUsable) == "function" then
        button:UpdateUsable()
    elseif button.icon then
        button.icon:SetVertexColor(1, 1, 1, 1)
    end
end

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

local function RegisterActionButton(button)
    if registered[button] then return end
    registered[button] = true
    if type(button.UpdateUsable) == "function" then
        hooksecurefunc(button, "UpdateUsable", UpdateActionButton)
    end
end

local function InstallHooks()
    if hooksInstalled then return end
    if not (ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.ForEachFrame) then return end
    hooksInstalled = true

    ActionBarButtonEventsFrame:ForEachFrame(RegisterActionButton)
    hooksecurefunc(ActionBarButtonEventsFrame, "RegisterFrame", function(_, button)
        RegisterActionButton(button)
        UpdateActionButton(button)
    end)

    if type(ActionButton_UpdateRangeIndicator) == "function" then
        hooksecurefunc("ActionButton_UpdateRangeIndicator", UpdateActionButtonRange)
    end

    if PetActionBar then
        if type(PetActionBar.Update) == "function" then
            hooksecurefunc(PetActionBar, "Update", UpdatePetBar)
        end
        -- The pet's own power isn't covered by the action bar's update events.
        local petFrame = CreateFrame("Frame")
        petFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "pet")
        petFrame:SetScript("OnEvent", function() UpdatePetBar(PetActionBar) end)
    end
end

-- Repaint everything, coalesced to one pass per frame.
local function RequestUpdate()
    if updateQueued then return end
    updateQueued = true
    C_Timer.After(1 / 30, function()
        updateQueued = false
        if not enabled then return end
        if ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.ForEachFrame then
            ActionBarButtonEventsFrame:ForEachFrame(UpdateActionButton)
        end
        UpdatePetBar(PetActionBar)
    end)
end

--------------------------------------------------------------------------------
-- Apply / setup
--------------------------------------------------------------------------------

function Perskan:ApplyRangeColoring()
    local wasEnabled = enabled
    enabled = self.db.profile.rangeColoring and true or false

    if not enabled then
        if wasEnabled then
            for button in pairs(registered) do
                ResetButton(button)
            end
            if PetActionBar and PetActionBar.actionButtons then
                for _, button in pairs(PetActionBar.actionButtons) do
                    ResetButton(button)
                end
            end
        end
        return
    end

    InstallHooks()
    RequestUpdate()
end

Perskan:RegisterModule("RangeColoring", function(self)
    self:ApplyRangeColoring()

    -- Usability changes already arrive through each button's own UpdateUsable; this is
    -- only here to catch bars that come into existence on a zone in.
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        if enabled then RequestUpdate() end
    end)
end)
