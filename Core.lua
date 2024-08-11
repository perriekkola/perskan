local addonName = ...
local details1 = _G["DetailsBaseFrame1"]
local details2 = _G["DetailsBaseFrame2"]
local mainDetailsHeight = 88
local secondaryDetailsHeight = 140

local function AdjustActionBars()
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

local function ReanchorDetailsWindows()
    if not Perskan.db.profile.reanchorDetailsWindow or not IsAddOnLoaded("Details") then
        return
    end

    local anchor, x
    local highestArenaFrame = nil

    for i = 1, 5 do
        local frame = _G["ArenaEnemyMatchFrame" .. i]
        if frame and frame:IsVisible() then
            highestArenaFrame = frame
        end
    end

    if ObjectiveTrackerFrame:IsVisible() then
        anchor = ObjectiveTrackerFrame.NineSlice.Center
        x = 10
    elseif DurabilityFrame:IsVisible() then
        anchor = DurabilityFrame
        x = 2
    elseif Boss1TargetFrame:IsVisible() then
        anchor = BossTargetFrameContainer
        x = 2
    elseif VehicleSeatIndicator:IsVisible() then
        anchor = VehicleSeatIndicator
        x = 2
    elseif highestArenaFrame then
        anchor = highestArenaFrame
        x = 20
    else
        anchor = MinimapCompassTexture
        x = -1
    end

    if details1 then
        details1:ClearAllPoints()
        details1:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", x, -50)
    end
    if details2 then
        details2:ClearAllPoints()
        details2:SetPoint("TOPLEFT", details1, "BOTTOMLEFT", 0, -20)
    end
end

local function AdjustDetailsHeight(window, maxHeight)
    if not IsAddOnLoaded("Details") then
        return
    end

    local baseHeight = 32
    local heightPerPlayer = 27
    local numGroupMembers = IsActiveBattlefieldArena() and 6 or GetNumGroupMembers() + 1
    local newHeight = math.min(baseHeight + (numGroupMembers * heightPerPlayer), maxHeight)

    window:SetHeight(newHeight)
end

local function ResizeAllDetailsWindows()
    if not IsAddOnLoaded("Details") then
        return
    end

    AdjustDetailsHeight(details1, mainDetailsHeight)
    AdjustDetailsHeight(details2, secondaryDetailsHeight)
    ReanchorDetailsWindows()
end

local function ToggleDetailsWindows()
    ResizeAllDetailsWindows()

    if not ObjectiveTrackerFrame:IsVisible() then
        return
    end

    C_Timer.After(0.1, function()
        local trackerHeight = ObjectiveTrackerFrame.NineSlice.Center:GetHeight()
        if trackerHeight > 305 then
            details1:SetHeight(0)
        else
            ResizeAllDetailsWindows()
        end
    end)
end

local function HookReanchorDetailsWindows()
    local function HookFrame(frame)
        if frame then
            frame:HookScript("OnShow", ToggleDetailsWindows)
            frame:HookScript("OnHide", ToggleDetailsWindows)
        end
    end

    hooksecurefunc(QuestObjectiveTracker, "Update", ToggleDetailsWindows)
    HookFrame(ObjectiveTrackerFrame)
    HookFrame(VehicleSeatIndicator)
    HookFrame(Boss1TargetFrame)

    for i = 1, 5 do
        HookFrame(_G["ArenaEnemyMatchFrame" .. i])
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
    self:RegisterEvent("QUEST_LOG_UPDATE", ReanchorDetailsWindows)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", AdjustActionBars)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", ResizeAllDetailsWindows)
    self:RegisterEvent("PLAYER_LOGIN", InitializeCVars)
    self:RegisterEvent("SETTINGS_LOADED")
end

function Perskan:SETTINGS_LOADED()
    settingsLoaded = true
    CreateSpecSliders(AdjustActionBars)

    AdjustActionBars()
    HighlightStealableAuras()
    ScaleUIFrames()
    HookReanchorDetailsWindows()
    ToggleDetailsWindows()
end
