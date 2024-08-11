local addonName = ...
local details = _G.Details
local details1 = details:GetInstance(1)
local details2 = details:GetInstance(2)
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

local function HasQuestItemInObjectiveTracker()
    local numQuestWatches = C_QuestLog.GetNumQuestWatches()
    if not numQuestWatches then
        return false
    end

    for i = 1, numQuestWatches do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID then
            local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questID)
            if item then
                return true
            end
        end
    end
    return false
end

local function ReanchorDetailsWindows()
    if (InCombatLockdown() and HasQuestItemInObjectiveTracker()) or not Perskan.db.profile.reanchorDetailsWindow or
        not C_AddOns.IsAddOnLoaded("Details") then
        return
    end

    details1.baseframe:SetWidth(254)
    details2.baseframe:SetWidth(254)

    local anchor, x
    local highestArenaFrame = nil

    for i = 1, 5 do
        local frame = _G["ArenaEnemyMatchFrame" .. i]
        if frame and frame:IsVisible() then
            highestArenaFrame = frame
        end
    end

    if ObjectiveTrackerFrame:IsVisible() then
        if not QuestObjectiveTracker:IsVisible() then
            anchor = ObjectiveTrackerFrame.Header
            x = 2
        else
            anchor = ObjectiveTrackerFrame.NineSlice.Center
            x = 10
        end
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
        details1.baseframe:ClearAllPoints()
        details1.baseframe:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", x, -50)
    end

    if details2 then
        details2.baseframe:ClearAllPoints()
        details2.baseframe:SetPoint("TOPLEFT", details1.baseframe, "BOTTOMLEFT", 0, -20)
    end
end

local function AdjustDetailsHeight(instance, maxHeight)
    if not C_AddOns.IsAddOnLoaded("Details") then
        return
    end

    if not instance then
        return
    end

    local baseHeight = 32
    local heightPerPlayer = 27
    local numGroupMembers = IsActiveBattlefieldArena() and 6 or GetNumGroupMembers()
    numGroupMembers = math.max(numGroupMembers, 1)
    local newHeight = math.min(baseHeight + (numGroupMembers * heightPerPlayer), maxHeight)

    local pos_table = instance:CreatePositionTable()
    pos_table.h = newHeight
    instance:RestorePositionFromPositionTable(pos_table)
end

local function ResizeAllDetailsWindows()
    if not C_AddOns.IsAddOnLoaded("Details") then
        return
    end

    AdjustDetailsHeight(details1, mainDetailsHeight)
    AdjustDetailsHeight(details2, secondaryDetailsHeight)
    ReanchorDetailsWindows()
end

local function ToggleDetailsWindows()
    if not details1 or not details2 then
        return
    end

    details1:ShowWindow()
    details2:ShowWindow()

    if not ObjectiveTrackerFrame:IsVisible() then
        ResizeAllDetailsWindows()
        local trackerHeight = ObjectiveTrackerFrame.NineSlice.Center:GetHeight()
        return
    end

    C_Timer.After(0.1, function()
        if not ObjectiveTrackerFrame:IsVisible() then
            return
        end

        local trackerHeight = ObjectiveTrackerFrame.NineSlice.Center:GetHeight()

        if trackerHeight > 310 then
            details1:HideWindow()
            details2:HideWindow()
        else
            details1:ShowWindow()
            details2:ShowWindow()
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
    self:RegisterEvent("QUEST_LOG_UPDATE", ToggleDetailsWindows)
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
