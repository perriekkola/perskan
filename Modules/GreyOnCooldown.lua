-- Desaturate action button icons while the ability is on cooldown or unusable.
--
-- Ported from GreyOnCooldown 2.0.1 by Millán - Sanguino (GPLv3) so the standalone
-- addon isn't needed alongside this one. Scope is the default UI: Blizzard's action
-- bars, the stance/possess/override bars, the extra action button, spell flyouts and
-- the pet bar. Upstream's LibActionButton / Bartender4 / Dominos integrations are
-- deliberately not carried over.
--
-- Everything toggles live. Hooks are installed the first time the feature is switched
-- on and stay inert while it's off; switching off restores every icon we touched.
--
-- The global cooldown is deliberately ignored - greying every icon on every button
-- press is exactly what this feature is not for.

local GCD = 1.88

-- 12.0 turned cooldown durations into secret objects that can only be resolved
-- through a curve; 11.x still hands out plain numbers. Both paths are kept and picked
-- by feature detection rather than by interface version.
local hasSecretDurations = (C_ActionBar and C_ActionBar.GetActionCooldownDuration
    and C_Spell and C_Spell.GetSpellCooldownDuration and C_CurveUtil) and true or false

local IsUsableActionFn = (C_ActionBar and C_ActionBar.IsUsableAction) or IsUsableAction
local GetActionCooldownFn = GetActionCooldown

local hookedButtons = {}     -- button -> "action" | "pet"
local registeredSpells = {}  -- spellID -> { [button] = true }
local enabled = false        -- mirrors the profile flag; hooks early-out on false
local hooksInstalled = false

local UpdateButton

--------------------------------------------------------------------------------
-- Button enumeration
--------------------------------------------------------------------------------

local BUTTON_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarLeftButton",
    "MultiBarRightButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
    "StanceButton",
    "PossessButton",
    "OverrideActionBarButton",
    "ExtraActionButton",
}

local function ForEachActionButton(fn)
    local count = NUM_ACTIONBAR_BUTTONS or 12
    for _, prefix in ipairs(BUTTON_PREFIXES) do
        for i = 1, count do
            local button = _G[prefix .. i]
            if button then fn(button) end
        end
    end
    -- Flyout buttons are created on demand; sweep the whole range each time.
    for i = 1, 40 do
        local button = _G["SpellFlyoutPopupButton" .. i]
        if button then fn(button) end
    end
end

local function ForEachPetButton(fn)
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local button = _G["PetActionButton" .. i]
        if button then fn(button) end
    end
end

--------------------------------------------------------------------------------
-- Spell registry
--
-- SPELL_UPDATE_COOLDOWN is the only event that reports whether a cooldown is the
-- GCD, so buttons are indexed by the spell they currently hold and refreshed from
-- that event rather than polling.
--------------------------------------------------------------------------------

-- Spells that share a cooldown with each other (Evoker's Deep Breath variants):
-- updating one has to refresh the buttons holding the others.
local RELATED_SPELLS = {
    [372608] = { 372610 },
    [372610] = { 372608 },
    [403092] = { 372608, 372610 },
    [425782] = { 372608, 372610 },
    [372606] = { 372608, 372610 },
}

local function RegisterButtonSpell(button, spellID)
    local previous = button._perskanGOCSpell
    if previous == spellID then return end

    if previous and registeredSpells[previous] then
        registeredSpells[previous][button] = nil
    end
    if spellID then
        local bucket = registeredSpells[spellID]
        if not bucket then
            bucket = {}
            registeredSpells[spellID] = bucket
        end
        bucket[button] = true
    end
    button._perskanGOCSpell = spellID
end

local function RefreshActionSpell(button)
    local spellID
    local action = button.action
    if action then
        local actionType, id, actionSubType = GetActionInfo(action)
        if actionType == "spell" or actionSubType == "spell" or actionSubType == "pet" then
            spellID = id
        end
    end
    RegisterButtonSpell(button, spellID)
    UpdateButton(button)
end

local function RefreshPetSpell(button)
    local index = button.index or button.id
    local spellID
    if index then
        local _, _, _, _, _, _, id = GetPetActionInfo(index)
        spellID = id
    end
    RegisterButtonSpell(button, spellID)
    UpdateButton(button)
end

--------------------------------------------------------------------------------
-- Desaturation
--------------------------------------------------------------------------------

local desaturationCurve, desaturationCurveGCD

-- Step curves let a secret duration decide the desaturation without ever exposing
-- the number: anything above the step point resolves to 1, zero resolves to 0.
local function EnsureCurves()
    if desaturationCurve or not hasSecretDurations then return end

    desaturationCurve = C_CurveUtil.CreateCurve()
    desaturationCurve:SetType(Enum.LuaCurveType.Step)
    desaturationCurve:AddPoint(0, 0)
    desaturationCurve:AddPoint(0.001, 1)

    -- Used where isOnGCD isn't reported (item macros), so the GCD itself is the step.
    desaturationCurveGCD = C_CurveUtil.CreateCurve()
    desaturationCurveGCD:SetType(Enum.LuaCurveType.Step)
    desaturationCurveGCD:AddPoint(0, 0)
    desaturationCurveGCD:AddPoint(GCD, 1)
end

local function ApplyDuration(icon, duration, useGCDCurve)
    if not duration then
        icon:SetDesaturation(0)
    elseif type(duration) == "number" then
        icon:SetDesaturation(duration > 0 and 1 or 0)
    elseif duration.HasSecretValues and duration:HasSecretValues() then
        icon:SetDesaturation(duration:EvaluateRemainingDuration(
            useGCDCurve and desaturationCurveGCD or desaturationCurve))
    else
        icon:SetDesaturation(duration:GetRemainingDuration() > 0 and 1 or 0)
    end
end

-- True when the button should be greyed because the action can't be used at all
-- (out of range, no target, ...) or because resources are missing.
local function ShouldGreyAsUnusable(profile, isUsable, notEnoughMana)
    if profile.greyOnCooldownUnusable and not (isUsable or notEnoughMana) then
        return true
    end
    if profile.greyOnCooldownNoResources and notEnoughMana and not isUsable then
        return true
    end
    return false
end

-- 12.x: resolve an action slot's cooldown to a duration (secret object, number or
-- nil for "no cooldown worth greying"), plus whether the GCD curve should be used.
local function ResolveModernActionDuration(action, isOnGCD)
    local duration = C_ActionBar.GetActionCooldownDuration(action, true)
    local useGCDCurve = false

    if duration and type(duration) ~= "number" and duration.HasSecretValues and duration:HasSecretValues() then
        local actionType, actionID, actionSubType = GetActionInfo(action)
        if actionType == "item" then
            -- Item cooldowns stay numeric, so the GCD has to be excluded by hand.
            local _, durationSeconds, enableCooldownTimer = C_Item.GetItemCooldown(actionID)
            if isOnGCD == nil then
                isOnGCD = (enableCooldownTimer and durationSeconds > 0 and durationSeconds <= GCD) or false
            end
            return (not isOnGCD) and durationSeconds or nil, false
        end

        if isOnGCD == nil then
            local info = C_ActionBar.GetActionCooldown(action)
            if info then
                isOnGCD = info.isOnGCD or false
                -- Macros that cast an item don't report isOnGCD reliably.
                if not isOnGCD and actionType == "macro" and actionSubType == "item" then
                    useGCDCurve = true
                end
            end
        end
        return (not isOnGCD) and duration or nil, useGCDCurve
    end

    if not isOnGCD then
        local info = C_ActionBar.GetActionCooldown(action)
        if info then
            isOnGCD = info.isOnGCD
                or (issecretvalue and not issecretvalue(info.activeCategory) and info.activeCategory == 2316)
                or false
            if not isOnGCD and duration and type(duration) ~= "number" then
                local actionType, _, actionSubType = GetActionInfo(action)
                if actionType ~= "spell" and actionSubType ~= "spell" and actionSubType ~= "pet" then
                    isOnGCD = (info.isEnabled and duration:GetRemainingDuration() > 0
                        and duration:GetTotalDuration() <= GCD) or false
                end
            end
        end
    end
    return (not isOnGCD) and duration or nil, false
end

-- 11.x fallback: plain numeric cooldowns, with anything up to the GCD ignored.
local function LegacyActionDuration(action)
    if not GetActionCooldownFn then return nil end
    local start, duration, enable = GetActionCooldownFn(action)
    if enable and enable ~= 0 and start and start > 0 and duration and duration > GCD then
        return duration
    end
    return nil
end

local function LegacySpellDuration(spellID)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info then return nil end
    if info.isEnabled and info.startTime and info.startTime > 0
        and info.duration and info.duration > GCD then
        return info.duration
    end
    return nil
end

local function UpdateActionButton(button, isOnGCD)
    local icon = button.icon
    if not icon then return end

    local profile = Perskan.db.profile
    local action, spellID = button.action, button.spellID

    if action then
        if profile.greyOnCooldownUnusable or profile.greyOnCooldownNoResources then
            local isUsable, notEnoughMana = IsUsableActionFn(action)
            if ShouldGreyAsUnusable(profile, isUsable, notEnoughMana) then
                icon:SetDesaturation(1)
                return
            end
        end

        if hasSecretDurations then
            ApplyDuration(icon, ResolveModernActionDuration(action, isOnGCD))
        else
            ApplyDuration(icon, LegacyActionDuration(action))
        end
        return
    end

    if spellID then
        if profile.greyOnCooldownUnusable or profile.greyOnCooldownNoResources then
            local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
            if ShouldGreyAsUnusable(profile, isUsable, notEnoughMana) then
                icon:SetDesaturation(1)
                return
            end
        end

        if hasSecretDurations then
            if isOnGCD == nil then
                local info = C_Spell.GetSpellCooldown(spellID)
                if info then
                    isOnGCD = info.isOnGCD
                        or (issecretvalue and not issecretvalue(info.activeCategory) and info.activeCategory == 2316)
                        or false
                end
            end
            ApplyDuration(icon, (not isOnGCD) and C_Spell.GetSpellCooldownDuration(spellID, true) or nil)
        else
            ApplyDuration(icon, LegacySpellDuration(spellID))
        end
        return
    end

    icon:SetDesaturation(0)
end

local function UpdatePetButton(button)
    local icon = button.icon
    local index = button.index or button.id
    if not icon or not index or not GetPetActionInfo(index) then return end

    local profile = Perskan.db.profile
    if not profile.greyOnCooldownPetBar then
        icon:SetDesaturation(0)
        return
    end

    if profile.greyOnCooldownUnusable and not GetPetActionSlotUsable(index) then
        icon:SetDesaturation(1)
        return
    end

    local _, duration, enable = GetPetActionCooldown(index)
    icon:SetDesaturation((enable and duration and duration > GCD) and 1 or 0)
end

UpdateButton = function(button, isOnGCD)
    if not enabled then return end
    if hookedButtons[button] == "pet" then
        UpdatePetButton(button)
    else
        UpdateActionButton(button, isOnGCD)
    end
end

local function ResetButton(button)
    if button.icon then
        button.icon:SetDesaturation(0)
    end
end

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

local function OnButtonUpdated(button)
    UpdateButton(button)
end

local function OnCooldownUpdated(cooldown)
    UpdateButton(cooldown:GetParent())
end

local function HookActionButton(button)
    if hookedButtons[button] then return end
    hookedButtons[button] = "action"

    if button.cooldown then
        button.cooldown:HookScript("OnCooldownDone", OnCooldownUpdated)
        button.cooldown:HookScript("OnShow", OnCooldownUpdated)
        button.cooldown:HookScript("OnHide", OnCooldownUpdated)
    end
    if type(button.Update) == "function" then
        hooksecurefunc(button, "Update", OnButtonUpdated)
    end
    if type(button.UpdateUsable) == "function" then
        hooksecurefunc(button, "UpdateUsable", OnButtonUpdated)
    end
    -- Keeps the spell registry in step with whatever the slot holds now.
    if type(button.UpdateAction) == "function" then
        hooksecurefunc(button, "UpdateAction", RefreshActionSpell)
    end

    RefreshActionSpell(button)
end

local function HookPetButton(button)
    if hookedButtons[button] then return end
    hookedButtons[button] = "pet"

    if button.cooldown then
        button.cooldown:HookScript("OnCooldownDone", OnCooldownUpdated)
        button.cooldown:HookScript("OnShow", OnCooldownUpdated)
        button.cooldown:HookScript("OnHide", OnCooldownUpdated)
    end
    if type(button.Update) == "function" then
        hooksecurefunc(button, "Update", OnButtonUpdated)
    end

    RefreshPetSpell(button)
end

local function HookSpellFlyout()
    if not SpellFlyout or type(SpellFlyout.Toggle) ~= "function" then return end
    -- Flyout buttons are created lazily; by the time this post-hook runs the ones
    -- this flyout needs exist, and hooking is idempotent.
    hooksecurefunc(SpellFlyout, "Toggle", function()
        for i = 1, 40 do
            local button = _G["SpellFlyoutPopupButton" .. i]
            if button then HookActionButton(button) end
        end
    end)
end

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    EnsureCurves()
    HookSpellFlyout()

    if type(ActionButton_UpdateCooldown) == "function" then
        hooksecurefunc("ActionButton_UpdateCooldown", OnButtonUpdated)
    end

    if PetActionBar and type(PetActionBar.UpdateCooldowns) == "function" then
        hooksecurefunc(PetActionBar, "UpdateCooldowns", function(bar)
            if not enabled or not bar.actionButtons then return end
            for _, button in ipairs(bar.actionButtons) do
                if hookedButtons[button] == "pet" then
                    RefreshPetSpell(button)
                end
            end
        end)
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(_, event, spellID, baseSpellID)
        if not enabled then return end

        if event == "PLAYER_ENTERING_WORLD" then
            -- Bars that only exist after a zone in (vehicle/override bars).
            Perskan:ApplyGreyOnCooldown()
            return
        end

        spellID = spellID or baseSpellID
        if not spellID then return end

        local function UpdateRegistered(id)
            local bucket = registeredSpells[id]
            if not bucket then return end
            local info = C_Spell.GetSpellCooldown(id)
            if not info then return end
            for button in pairs(bucket) do
                UpdateButton(button, info.isOnGCD or false)
            end
        end

        UpdateRegistered(spellID)
        for _, related in ipairs(RELATED_SPELLS[spellID] or {}) do
            UpdateRegistered(related)
        end
    end)
end

--------------------------------------------------------------------------------
-- Apply / setup
--------------------------------------------------------------------------------

function Perskan:ApplyGreyOnCooldown()
    local profile = self.db.profile
    enabled = profile.greyOnCooldown and true or false

    if not enabled then
        for button in pairs(hookedButtons) do
            ResetButton(button)
        end
        return
    end

    InstallHooks()
    ForEachActionButton(HookActionButton)
    if profile.greyOnCooldownPetBar then
        ForEachPetButton(HookPetButton)
    end

    for button in pairs(hookedButtons) do
        UpdateButton(button)
    end
end

Perskan:RegisterModule("GreyOnCooldown", function(self)
    self:ApplyGreyOnCooldown()
end)
