-- CVar-backed settings (camera, nameplate visibility, raid/pvp frames, sound, loot).
--
-- These all apply live from their config handlers via SetCVar; this module re-asserts
-- them on every PLAYER_ENTERING_WORLD so a zone change or Blizzard reset can't clobber
-- them. Exposed as Perskan:ApplyCVars() and called from Core.lua's PLAYER_ENTERING_WORLD.

local function SafeSetCVar(cvar, value)
    if value == nil then return end
    -- A single bad CVar name on one interface version shouldn't abort the rest.
    pcall(SetCVar, cvar, value)
end

function Perskan:ApplyCVars()
    local profile = self.db.profile

    SafeSetCVar("Sound_AmbienceVolume", profile.soundAmbienceVolume)
    SafeSetCVar("cameraYawMoveSpeed", profile.cameraYawMoveSpeed)
    SafeSetCVar("cameraPivot", profile.cameraPivot and 1 or 0)
    SafeSetCVar("cameraDistanceMaxZoomFactor", profile.cameraDistanceMaxZoomFactor)
    SafeSetCVar("nameplateOtherBottomInset", profile.nameplateOtherBottomInset)
    SafeSetCVar("nameplateOtherTopInset", profile.nameplateOtherTopInset)

    -- Nameplate clickable size via the API rather than a CVar.
    if profile.nameplateWidth and C_NamePlate and C_NamePlate.SetNamePlateSize then
        C_NamePlate.SetNamePlateSize(profile.nameplateWidth, profile.nameplateClickableHeight or 65)
        -- C_NamePlateManager may be absent on older interface versions in the multi-toc;
        -- guard it so a nil namespace can't abort the remaining CVars.
        if C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets and Enum and Enum.NamePlateType then
            pcall(C_NamePlateManager.SetNamePlateHitTestInsets, Enum.NamePlateType.Enemy, 1, 1, -10, -10)
            pcall(C_NamePlateManager.SetNamePlateHitTestInsets, Enum.NamePlateType.Friendly, 1, 1, -10, -10)
        end
    end

    SafeSetCVar("autoLootDefault", profile.autoLootDefault)
    SafeSetCVar("alwaysShowNameplates", profile.alwaysShowNameplates)
    SafeSetCVar("nameplateShowAll", profile.nameplateShowAll)
    SafeSetCVar("nameplateShowEnemies", profile.nameplateShowEnemies)
    SafeSetCVar("nameplateShowEnemyMinions", profile.nameplateShowEnemyMinions)
    SafeSetCVar("nameplateShowFriendlyMinions", profile.nameplateShowFriendlyMinions)
    SafeSetCVar("raidFramesDisplayAggroHighlight", profile.raidFramesDisplayAggroHighlight)
    SafeSetCVar("raidFramesDisplayClassColor", profile.raidFramesDisplayClassColor)
    SafeSetCVar("raidOptionDisplayMainTankAndAssist", profile.raidOptionDisplayMainTankAndAssist)
    SafeSetCVar("pvpFramesDisplayClassColor", profile.pvpFramesDisplayClassColor)
    SafeSetCVar("nameplateShowSelf", profile.nameplateShowSelf)
    SafeSetCVar("damageMeterEnabled", profile.enableDamageMeter)
end

-- Expose the safe setter so config handlers can apply a single CVar live.
function Perskan:SetCVarValue(cvar, value)
    SafeSetCVar(cvar, value)
end

-- Apply nameplate clickable size live (used by the width/height sliders). Protected
-- calls, so skip in combat and rely on the next PLAYER_ENTERING_WORLD.
function Perskan:ApplyNameplateSize()
    if InCombatLockdown() then return end
    local profile = self.db.profile
    if C_NamePlate and C_NamePlate.SetNamePlateSize then
        C_NamePlate.SetNamePlateSize(profile.nameplateWidth or 240, profile.nameplateClickableHeight or 65)
    end
    if C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets and Enum and Enum.NamePlateType then
        pcall(C_NamePlateManager.SetNamePlateHitTestInsets, Enum.NamePlateType.Enemy, 1, 1, -10, -10)
        pcall(C_NamePlateManager.SetNamePlateHitTestInsets, Enum.NamePlateType.Friendly, 1, 1, -10, -10)
    end
end
