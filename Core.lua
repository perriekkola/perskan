local addonName = ...
local details1 = _G["DetailsBaseFrame1"]
local details2 = _G["DetailsBaseFrame2"]
local mainDetailsHeight = 88
local secondaryDetailsHeight = 140

local function AdjustActionBars()
    if settingsLoaded then
        local id, name, description, icon, background, role = GetSpecializationInfo(GetSpecialization())
        local numActionBars = Perskan.db.profile[name] or 3

        for i = 2, 3 do
            local actionBarSetting = "PROXY_SHOW_ACTIONBAR_" .. i
            if i <= numActionBars then
                Settings.SetValue(actionBarSetting, true)
            else
                Settings.SetValue(actionBarSetting, false)
            end
        end
    end
end

local function ScaleUIFrames()
    EncounterBar:SetScale(Perskan.db.profile.encounterBarScale or 0.8)
    ObjectiveTrackerFrame:SetScale(Perskan.db.profile.objectiveTrackerScale or 1)
end

local function HighlightStealableAuras()
    local function TargetFrame_UpdateAuras(self)
        for buff in self.auraPools:GetPool("TargetBuffFrameTemplate"):EnumerateActive() do
            local buffSize = buff.GetHeight(buff)
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID(buff.unit, buff.auraInstanceID)
            buff.Stealable:SetShown(data.isStealable or data.dispelName == "Magic")
            local stealableSize = buffSize + 2
            buff.Stealable:SetSize(stealableSize, stealableSize)
            buff.Stealable:SetPoint("CENTER", buff, "CENTER")
        end
    end

    if Perskan.db.profile.highlightStealableAuras then
        hooksecurefunc(TargetFrame, "UpdateAuras", TargetFrame_UpdateAuras)
        hooksecurefunc(FocusFrame, "UpdateAuras", TargetFrame_UpdateAuras)
    end
end

local function ReanchorDetailsWindows()
    if not Perskan.db.profile.reanchorDetailsWindow then
        return
    end

    if not IsAddOnLoaded("Details") then
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
    elseif Boss1TargetFrame:IsVisible() then
        anchor = BossTargetFrameContainer
        x = 2
    elseif VehicleSeatIndicator:IsVisible() then
        anchor = VehicleSeatIndicator
        x = 2
    elseif DurabilityFrame:IsVisible() then
        anchor = DurabilityFrame
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

local function HookReanchorDetailsWindows()
    hooksecurefunc(QuestObjectiveTracker, "Update", ReanchorDetailsWindows)
    ObjectiveTrackerFrame:HookScript("OnShow", ReanchorDetailsWindows)
    VehicleSeatIndicator:HookScript("OnShow", ReanchorDetailsWindows)
    Boss1TargetFrame:HookScript("OnShow", ReanchorDetailsWindows)
    ObjectiveTrackerFrame:HookScript("OnHide", ReanchorDetailsWindows)
    VehicleSeatIndicator:HookScript("OnHide", ReanchorDetailsWindows)
    Boss1TargetFrame:HookScript("OnHide", ReanchorDetailsWindows)

    for i = 1, 5 do
        local frame = _G["ArenaEnemyMatchFrame" .. i]
        if frame then
            frame:HookScript("OnShow", ReanchorDetailsWindows)
            frame:HookScript("OnHide", ReanchorDetailsWindows)
        end
    end
end

local function AdjustDetailsHeight(window, maxHeight)
    if not IsAddOnLoaded("Details") then
        return
    end

    local baseHeight = 32
    local heightPerPlayer = 28
    local numGroupMembers

    if IsActiveBattlefieldArena() then
        numGroupMembers = 6
    else
        numGroupMembers = GetNumGroupMembers() + 1
    end

    window:SetHeight(math.min(baseHeight + (numGroupMembers * heightPerPlayer), maxHeight))
end

local function ResizeAllDetailsWindows()
    if not IsAddOnLoaded("Details") then
        return
    end

    AdjustDetailsHeight(details1, mainDetailsHeight)
    AdjustDetailsHeight(details2, secondaryDetailsHeight)

    ReanchorDetailsWindows()
end

function Perskan:InitializeCVars()
    SetCVar("Sound_AmbienceVolume", self.db.profile.soundAmbienceVolume)
    SetCVar("cameraYawMoveSpeed", self.db.profile.cameraYawMoveSpeed)
    SetCVar("cameraPivot", self.db.profile.cameraPivot and 1 or 0)
    SetCVar("nameplateOtherBottomInset", self.db.profile.nameplateOtherBottomInset)
    SetCVar("nameplateOtherTopInset", self.db.profile.nameplateOtherTopInset)
    SetCVar("cameraDistanceMaxZoomFactor", self.db.profile.cameraDistanceMaxZoomFactor)
end

function Perskan:OnEnable()
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("SETTINGS_LOADED")
    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_LOGIN", "InitializeCVars")
end

function Perskan:ACTIVE_TALENT_GROUP_CHANGED()
    AdjustActionBars()
end

function Perskan:QUEST_LOG_UPDATE()
    ReanchorDetailsWindows()
end

function Perskan:PLAYER_ENTERING_WORLD()
    AdjustActionBars()
end

function Perskan:GROUP_ROSTER_UPDATE()
    ResizeAllDetailsWindows()
end

function Perskan:SETTINGS_LOADED()
    settingsLoaded = true
    CreateSpecSliders(AdjustActionBars)

    AdjustActionBars()
    HighlightStealableAuras()
    ScaleUIFrames()
    ReanchorDetailsWindows()
    HookReanchorDetailsWindows()
    ResizeAllDetailsWindows()
end
