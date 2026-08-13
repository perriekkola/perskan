-- Unit-frame aura tweaks:
--   * force cooldown countdown numbers on target/focus/player/boss/party auras
--   * cooldown countdown numbers on raid/party compact frames
--   * resize target/focus aura icons
--
-- All three apply live from the settings window. The hot paths (UNIT_AURA and the
-- CompactUnitFrame_UpdateAuras hook) are debounced to a single pending pass and skip
-- cooldowns already in the desired state, avoiding the per-event table churn and font
-- resets the old code did on every aura change in a raid.
--
-- The profile table is read fresh each pass (never cached at module scope): AceDB
-- repoints db.profile to a new table on a profile switch, so a cached reference would
-- go stale.

--------------------------------------------------------------------------------
-- Shared: apply/scale a cooldown's countdown font
--------------------------------------------------------------------------------

-- Locate (and cache) the countdown FontString on a cooldown frame. Only positive
-- results are cached, because the fontstring is created lazily the first time
-- countdown numbers are enabled.
local function GetCooldownText(cooldown)
    if cooldown._perskanText then
        return cooldown._perskanText
    end
    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            cooldown._perskanText = region
            return region
        end
    end
    return nil
end

-- Set a cooldown to show or hide numbers, scaling the font when shown. A per-frame
-- state token skips redundant work on the hot update path.
local function ConfigureCooldown(cooldown, baseSize, show, scale)
    if not cooldown or not cooldown.SetHideCountdownNumbers then return end

    local token = (show and "1" or "0") .. ":" .. tostring(scale) .. ":" .. tostring(baseSize)
    if cooldown._perskanState == token then return end
    cooldown._perskanState = token

    cooldown:SetHideCountdownNumbers(not show)

    if not show then return end

    local text = GetCooldownText(cooldown)
    if text then
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, baseSize * scale, flags)
        end
    end
end

--------------------------------------------------------------------------------
-- Aura cooldown numbers (target/focus/player/boss/party)
--------------------------------------------------------------------------------

local function ProcessUnitFrameCooldowns(unitFrame, show, scale)
    if not unitFrame then return end

    if unitFrame.auraPools then
        for auraFrame in unitFrame.auraPools:EnumerateActive() do
            if auraFrame.Cooldown then
                ConfigureCooldown(auraFrame.Cooldown, 12, show, scale)
            end
        end
    end

    for _, child in ipairs({ unitFrame:GetChildren() }) do
        if child.Cooldown then
            ConfigureCooldown(child.Cooldown, 12, show, scale)
        end
    end
end

local function ProcessAllAuraCooldowns()
    local profile = Perskan.db.profile
    local show = profile.showAuraCooldownNumbers
    local scale = profile.auraCooldownNumbersScale or 0.75

    ProcessUnitFrameCooldowns(TargetFrame, show, scale)
    ProcessUnitFrameCooldowns(FocusFrame, show, scale)
    ProcessUnitFrameCooldowns(PlayerFrame, show, scale)
    for i = 1, 8 do
        ProcessUnitFrameCooldowns(_G["Boss" .. i .. "TargetFrame"], show, scale)
    end
    for i = 1, 4 do
        ProcessUnitFrameCooldowns(_G["PartyMemberFrame" .. i], show, scale)
    end
end

local auraCdPending = false
local function ScheduleAuraCooldowns()
    if auraCdPending then return end
    auraCdPending = true
    C_Timer.After(0.1, function()
        auraCdPending = false
        ProcessAllAuraCooldowns()
    end)
end

function Perskan:ApplyAuraCooldownNumbers()
    ProcessAllAuraCooldowns()
end

--------------------------------------------------------------------------------
-- Raid/party compact frame cooldown numbers
--------------------------------------------------------------------------------

local function ProcessRaidFrameAuras(unitFrame, show, scale)
    if not unitFrame then return end

    local lists = { unitFrame.buffFrames, unitFrame.debuffFrames, unitFrame.dispelDebuffFrames }
    for _, list in ipairs(lists) do
        if list then
            for _, auraFrame in ipairs(list) do
                local cooldown = auraFrame.cooldown or auraFrame.Cooldown
                if cooldown then
                    ConfigureCooldown(cooldown, 12, show, scale)
                end
            end
        end
    end
end

local function ProcessAllRaidFrames()
    local profile = Perskan.db.profile
    local show = profile.showRaidFrameAuraCooldowns
    local scale = profile.raidFrameAuraCooldownScale or 0.75

    if CompactRaidFrameContainer then
        local function ProcessContainer(container)
            if not container then return end
            for _, child in ipairs({ container:GetChildren() }) do
                if child.unit then
                    ProcessRaidFrameAuras(child, show, scale)
                end
                ProcessContainer(child)
            end
        end
        ProcessContainer(CompactRaidFrameContainer)
    end

    if CompactPartyFrame then
        for _, child in ipairs({ CompactPartyFrame:GetChildren() }) do
            if child.unit then
                ProcessRaidFrameAuras(child, show, scale)
            end
        end
    end

    for i = 1, 5 do
        local memberFrame = _G["CompactPartyFrameMember" .. i]
        if memberFrame then
            ProcessRaidFrameAuras(memberFrame, show, scale)

            local centerIcon = _G["CompactPartyFrameMember" .. i .. "Icon"]
            if centerIcon then
                local cd = centerIcon.cooldown or centerIcon.Cooldown
                if cd then ConfigureCooldown(cd, 18, show, scale) end
                if centerIcon.CenterDefensiveBuff then
                    local dcd = centerIcon.CenterDefensiveBuff.cooldown or centerIcon.CenterDefensiveBuff.Cooldown
                    if dcd then ConfigureCooldown(dcd, 18, show, scale) end
                end
            end

            local memberCooldown = _G["CompactPartyFrameMember" .. i .. "Cooldown"]
            if memberCooldown then
                ConfigureCooldown(memberCooldown, 18, show, scale)
            end
        end
    end

    for i = 1, 40 do
        ProcessRaidFrameAuras(_G["CompactRaidFrame" .. i], show, scale)
    end
end

local raidCdPending = false
local function ScheduleRaidCooldowns()
    if raidCdPending then return end
    raidCdPending = true
    C_Timer.After(0.05, function()
        raidCdPending = false
        ProcessAllRaidFrames()
    end)
end

function Perskan:ApplyRaidFrameAuraCooldowns()
    ProcessAllRaidFrames()
end

--------------------------------------------------------------------------------
-- Target/focus aura icon size
--------------------------------------------------------------------------------

local function ProcessAuraSize(unitFrame, size)
    if not unitFrame or not unitFrame.auraPools then return end
    for auraFrame in unitFrame.auraPools:EnumerateActive() do
        auraFrame:SetSize(size, size)
    end
end

local function ProcessTargetFocusSize()
    local size = Perskan.db.profile.targetFocusAuraSize or 20
    ProcessAuraSize(TargetFrame, size)
    ProcessAuraSize(FocusFrame, size)
end

function Perskan:ApplyTargetFocusAuraSize()
    ProcessTargetFocusSize()
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

Perskan:RegisterModule("Auras", function(self)
    -- Aura cooldown numbers + target/focus size share the same event set.
    local auraFrame = CreateFrame("Frame")
    auraFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    auraFrame:RegisterEvent("UNIT_AURA")
    auraFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    auraFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    auraFrame:SetScript("OnEvent", function(_, event, unit)
        -- Only target/focus aura churn matters for these features.
        if event == "UNIT_AURA" and unit ~= "target" and unit ~= "focus" then
            return
        end
        if Perskan.db.profile.showAuraCooldownNumbers then
            ScheduleAuraCooldowns()
        end
        ProcessTargetFocusSize()
    end)

    -- Late-loading frames after login.
    C_Timer.After(2, function()
        if Perskan.db.profile.showAuraCooldownNumbers then ProcessAllAuraCooldowns() end
        ProcessTargetFocusSize()
    end)

    -- Raid frame cooldown numbers.
    if type(CompactUnitFrame_UpdateAuras) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            local profile = Perskan.db.profile
            if profile.showRaidFrameAuraCooldowns then
                ProcessRaidFrameAuras(frame, true, profile.raidFrameAuraCooldownScale or 0.75)
            end
        end)
    end

    local raidFrame = CreateFrame("Frame")
    raidFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    raidFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    raidFrame:SetScript("OnEvent", function()
        if Perskan.db.profile.showRaidFrameAuraCooldowns then
            ScheduleRaidCooldowns()
        end
    end)
end)
