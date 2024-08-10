local addonName = ...

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

local function DetailsAnchor()
    if not Perskan.db.profile.reanchorDetailsWindow then
        return
    end

    if not IsAddOnLoaded("Details") then
        return
    end

    local details1 = _G["DetailsBaseFrame1"]
    local details2 = _G["DetailsBaseFrame2"]

    local anchor, x
    local mainDetailsHeight = 88
    local secondaryDetailsHeight = 140

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

        --[[ C_Timer.After(0.1, function()
            local trackerHeight = ObjectiveTrackerFrame.NineSlice.Center:GetHeight()
            if ObjectiveTrackerFrame:IsVisible() and trackerHeight > 285 then
                details1:SetHeight(0)
            else
                details1:SetHeight(mainDetailsHeight)
            end
        end) ]]
    end
    if details2 then
        details2:ClearAllPoints()
        details2:SetPoint("TOPLEFT", details1, "BOTTOMLEFT", 0, -20)
    end

    local function adjustHeight()
        local currentSegment = Details:GetCurrentCombat()
        local damageActorList = currentSegment:GetActorList(DETAILS_ATTRIBUTE_DAMAGE)
        local healingActorList = currentSegment:GetActorList(DETAILS_ATTRIBUTE_HEAL)

        local totalDamagePlayers = #damageActorList
        local totalHealPlayers = #healingActorList

        local baseHeight = 28
        local heightPerPlayer = 20

        local healHeight = baseHeight + (totalHealPlayers * heightPerPlayer)
        local damageHeight = baseHeight + (totalDamagePlayers * heightPerPlayer)

        details1:SetHeight(healHeight)
        details2:SetHeight(damageHeight)
    end

    adjustHeight()
end

local function HookDetailsAnchor()
    hooksecurefunc(QuestObjectiveTracker, "Update", DetailsAnchor)
    ObjectiveTrackerFrame:HookScript("OnShow", DetailsAnchor)
    VehicleSeatIndicator:HookScript("OnShow", DetailsAnchor)
    Boss1TargetFrame:HookScript("OnShow", DetailsAnchor)
    ObjectiveTrackerFrame:HookScript("OnHide", DetailsAnchor)
    VehicleSeatIndicator:HookScript("OnHide", DetailsAnchor)
    Boss1TargetFrame:HookScript("OnHide", DetailsAnchor)

    for i = 1, 5 do
        local frame = _G["ArenaEnemyMatchFrame" .. i]
        if frame then
            frame:HookScript("OnShow", DetailsAnchor)
            frame:HookScript("OnHide", DetailsAnchor)
        end
    end
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
    self:RegisterEvent("PLAYER_LOGIN", "InitializeCVars")
end

function Perskan:ACTIVE_TALENT_GROUP_CHANGED()
    AdjustActionBars()
end

function Perskan:QUEST_LOG_UPDATE()
    DetailsAnchor()
end

function Perskan:PLAYER_ENTERING_WORLD()
    AdjustActionBars()
end

function Perskan:SETTINGS_LOADED()
    settingsLoaded = true
    AdjustActionBars()
    HighlightStealableAuras()
    ScaleUIFrames()
    CreateSpecSliders(AdjustActionBars)
    HookDetailsAnchor()
    DetailsAnchor()
end
