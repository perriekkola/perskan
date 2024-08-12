local addonName = ...
local details = _G.Details
local details1, details2

if details then
    details1 = details:GetInstance(1)
    details2 = details:GetInstance(2)
end

local function AdjustActionBars()
    if InCombatLockdown() then
        return
    end

    if settingsLoaded then
        local id, name = GetSpecializationInfo(GetSpecialization())

        local numActionBars = Perskan.db.profile[name] or 3

        for i = 2, 3 do
            local actionBarSetting = "PROXY_SHOW_ACTIONBAR_" .. i
            Settings.SetValue(actionBarSetting, i <= numActionBars)
        end
    end
end

local function ScaleUIFrames()
    EncounterBar:SetScale(Perskan.db.profile.encounterBarScale or 0.8)
    ObjectiveTrackerFrame:SetScale(Perskan.db.profile.objectiveTrackerScale or 1)
end

local function HighlightStealableAuras()
    local function UpdateAuras(self)
        for buff in self.auraPools:GetPool("TargetBuffFrameTemplate"):EnumerateActive() do
            local buffSize = buff:GetHeight()
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID(buff.unit, buff.auraInstanceID)
            buff.Stealable:SetShown(data.isStealable or data.dispelName == "Magic")
            local stealableSize = buffSize + 2
            buff.Stealable:SetSize(stealableSize, stealableSize)
            buff.Stealable:SetPoint("CENTER", buff, "CENTER")
        end
    end

    if Perskan.db.profile.highlightStealableAuras then
        hooksecurefunc(TargetFrame, "UpdateAuras", UpdateAuras)
        hooksecurefunc(FocusFrame, "UpdateAuras", UpdateAuras)
    end
end

local isSettingHeight = false

local function SetObjectiveTrackerHeight()
    if InCombatLockdown() then
        return
    end

    if not isSettingHeight then
        isSettingHeight = true
        ObjectiveTrackerFrame:SetHeight(340)
        isSettingHeight = false
    end
end

hooksecurefunc(ObjectiveTrackerFrame, "SetHeight", function()
    SetObjectiveTrackerHeight()
end)

local function ToggleDetailsWindows()
    local framesToCheck = {DurabilityFrame, VehicleSeatIndicator, Boss1TargetFrame}
    local shouldHide = false

    for _, frame in ipairs(framesToCheck) do
        if frame:IsShown() then
            shouldHide = true
            break
        end
    end

    if shouldHide then
        details1:HideWindow()
        details2:HideWindow()
    else
        details1:ShowWindow()
        details2:ShowWindow()
    end
end

local function HookToggleDetailsWindows()
    for _, frame in ipairs(framesToCheck) do
        if frame then
            frame:HookScript("OnShow", ToggleDetailsWindows)
            frame:HookScript("OnHide", ToggleDetailsWindows)
        end
    end
end

local function InitializeCVars()
    local profile = self.db.profile
    SetCVar("Sound_AmbienceVolume", profile.soundAmbienceVolume)
    SetCVar("cameraYawMoveSpeed", profile.cameraYawMoveSpeed)
    SetCVar("cameraPivot", profile.cameraPivot and 1 or 0)
    SetCVar("nameplateOtherBottomInset", profile.nameplateOtherBottomInset)
    SetCVar("nameplateOtherTopInset", profile.nameplateOtherTopInset)
    SetCVar("cameraDistanceMaxZoomFactor", profile.cameraDistanceMaxZoomFactor)
end

function Perskan:OnEnable()
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", AdjustActionBars)
    self:RegisterEvent("SETTINGS_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", SetObjectiveTrackerHeight)
    self:RegisterEvent("PLAYER_LOGIN", InitializeCVars)
end

function Perskan:SETTINGS_LOADED()
    settingsLoaded = true
    CreateSpecSliders(AdjustActionBars)

    AdjustActionBars()
    HighlightStealableAuras()
    ScaleUIFrames()
    HookToggleDetailsWindows()
end
