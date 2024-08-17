local details = _G.Details
local details1, details2

local mainDetailsMaxHeight = 80
local secondaryDetailsMaxHeight = 134

if details then
    details1 = details:GetInstance(1)
    details2 = details:GetInstance(2)
end

-- Adjust amount of action bars according to specialization
local function AdjustActionBars()
    if InCombatLockdown() then
        return
    end

    local id, name = GetSpecializationInfo(GetSpecialization())

    local numActionBars = Perskan.db.profile[name] or 3

    for i = 2, 3 do
        local actionBarSetting = "PROXY_SHOW_ACTIONBAR_" .. i
        Settings.SetValue(actionBarSetting, i <= numActionBars)
    end
end

-- Scale various UI frames
local function ScaleUIFrames()
    EncounterBar:SetScale(Perskan.db.profile.encounterBarScale or 0.8)
    ObjectiveTrackerFrame:SetScale(Perskan.db.profile.objectiveTrackerScale or 1)
end

-- Highlight stealable auras
local function HighlightStealableAuras()
    local function UpdateAuras(self)
        for buff in self.auraPools:GetPool("TargetBuffFrameTemplate"):EnumerateActive() do
            local buffSize = buff:GetHeight()
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID(buff.unit, buff.auraInstanceID)
            buff.Stealable:SetShown(data.isStealable or data.dispelName == "Magic")
            local stealableSize = buffSize + 4
            buff.Stealable:SetSize(stealableSize, stealableSize)
            buff.Stealable:SetPoint("CENTER", buff, "CENTER")
        end
    end

    if Perskan.db.profile.highlightStealableAuras then
        hooksecurefunc(TargetFrame, "UpdateAuras", UpdateAuras)
        hooksecurefunc(FocusFrame, "UpdateAuras", UpdateAuras)
    end
end

-- Reanchor Details and set width to Perskan defaults
local function ReanchorDetailsWindows()
    if not C_AddOns.IsAddOnLoaded("Details") or not Perskan.db.profile.reanchorDetailsWindows or not details1.baseframe or
        not details2.baseframe then
        return
    end

    local detailsWidth = 268

    details1.baseframe:SetWidth(detailsWidth)
    details2.baseframe:SetWidth(detailsWidth)

    local anchor, x
    local highestArenaFrame = nil

    for i = 1, 5 do
        local frame = _G["ArenaEnemyMatchFrame" .. i]
        if frame and frame:IsVisible() then
            highestArenaFrame = frame
        end
    end

    if ObjectiveTrackerFrame:IsVisible() then
        if not QuestObjectiveTracker:IsVisible() and not CampaignQuestObjectiveTracker:IsVisible() and
            not WorldQuestObjectiveTracker:IsVisible() and not AchievementObjectiveTracker:IsVisible() and
            not AdventureObjectiveTracker:IsVisible() and not ScenarioObjectiveTracker:IsVisible() and
            not MonthlyActivitiesObjectiveTracker:IsVisible() and not BonusObjectiveTracker:IsVisible() and
            not ProfessionsRecipeTracker:IsVisible() then
            anchor = ObjectiveTrackerFrame.Header
            x = 2
        else
            anchor = ObjectiveTrackerFrame.NineSlice.Center
            x = 18
        end
    elseif DurabilityFrame:IsVisible() then
        anchor = DurabilityFrame
        x = 4
    elseif Boss1TargetFrame:IsVisible() then
        anchor = BossTargetFrameContainer
        x = 4
    elseif VehicleSeatIndicator:IsVisible() then
        anchor = VehicleSeatIndicator
        x = 4
    elseif highestArenaFrame then
        anchor = highestArenaFrame
        x = 20
    else
        anchor = MinimapCompassTexture
        x = 1
    end

    details1.baseframe:ClearAllPoints()
    details1.baseframe:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", x, -50)

    details2.baseframe:ClearAllPoints()
    details2.baseframe:SetPoint("TOPLEFT", details1.baseframe, "BOTTOMLEFT", 0, -20)
end

ObjectiveTrackerFrame.Header.MinimizeButton:HookScript("OnClick", ReanchorDetailsWindows)

local framesToHook = {ObjectiveTrackerFrame, VehicleSeatIndicator, DurabilityFrame, Boss1TargetFrame}

for i = 1, 5 do
    table.insert(framesToHook, _G["ArenaEnemyMatchFrame" .. i])
end

local function HookFrameEvents(frame)
    frame:HookScript("OnShow", ReanchorDetailsWindows)
    frame:HookScript("OnHide", ReanchorDetailsWindows)
end

for _, frame in ipairs(framesToHook) do
    HookFrameEvents(frame)
end

-- Resize Details windows to fit group size
local function AdjustDetailsHeight(instance, maxHeight, isHealingWindow)
    if not C_AddOns.IsAddOnLoaded("Details") or not Perskan.db.profile.reanchorDetailsWindows or not instance then
        return
    end

    local baseHeight = 26
    local heightPerPlayer = 24

    local numGroupMembers = IsActiveBattlefieldArena() and 6 or GetNumGroupMembers()
    numGroupMembers = math.max(numGroupMembers, 1)

    local numHealers = 0
    if isHealingWindow then
        local specIndex = GetSpecialization()
        if specIndex then
            local role = GetSpecializationRole(specIndex)
            if role == "HEALER" then
                numHealers = numHealers + 1
            end
        end

        if not IsInRaid() then
            for i = 1, numGroupMembers - 1 do
                local role = UnitGroupRolesAssigned("party" .. i)
                if role == "HEALER" then
                    numHealers = numHealers + 1
                end
            end
        else
            for i = 1, numGroupMembers do
                local role = UnitGroupRolesAssigned("raid" .. i)
                if role == "HEALER" then
                    numHealers = numHealers + 1
                end
            end
        end
    end

    local newHeight
    if isHealingWindow then
        newHeight = baseHeight + (numHealers * heightPerPlayer)
    else
        newHeight = baseHeight + (numGroupMembers * heightPerPlayer)
    end

    newHeight = math.min(newHeight, maxHeight)

    local pos_table = instance:CreatePositionTable()
    pos_table.h = newHeight
    instance:RestorePositionFromPositionTable(pos_table)
end

local function ResizeAllDetailsWindows()
    if not C_AddOns.IsAddOnLoaded("Details") or not Perskan.db.profile.reanchorDetailsWindows then
        return
    end

    AdjustDetailsHeight(details1, mainDetailsMaxHeight, true)
    AdjustDetailsHeight(details2, secondaryDetailsMaxHeight)
    ReanchorDetailsWindows()
end

-- Hide Details when tracker is too tall
local function ToggleDetailsWindows()
    if not Perskan.db.profile.reanchorDetailsWindows then
        return
    end

    ResizeAllDetailsWindows()
    ReanchorDetailsWindows()

    C_Timer.After(0.1, function()
        if not ObjectiveTrackerFrame:IsVisible() then
            return
        end

        local trackerHeight = ObjectiveTrackerFrame.NineSlice.Center:GetHeight()

        if trackerHeight > 350 then
            details1:HideWindow()
            details2:HideWindow()
        else
            details1:ShowWindow()
            details2:ShowWindow()
            ResizeAllDetailsWindows()
            ReanchorDetailsWindows()
        end
    end)
end

-- Function to expand Details windows to max size
local function ExpandDetailsWindows()
    if not C_AddOns.IsAddOnLoaded("Details") or not Perskan.db.profile.reanchorDetailsWindows then
        return
    end

    if details1 then
        local pos_table1 = details1:CreatePositionTable()
        pos_table1.h = mainDetailsMaxHeight
        details1:RestorePositionFromPositionTable(pos_table1)
    end

    if details2 then
        local pos_table2 = details2:CreatePositionTable()
        pos_table2.h = secondaryDetailsMaxHeight
        details2:RestorePositionFromPositionTable(pos_table2)
    end

    ReanchorDetailsWindows()
end

-- Create the Expand/Minimize text
local function CreateToggleText()
    if not Perskan.db.profile.reanchorDetailsWindows or not details1.baseframe or not details2.baseframe then
        return
    end

    local textFrame = CreateFrame("Frame", "DetailsToggleTextFrame", details2.baseframe)
    textFrame:SetFrameStrata("HIGH")
    textFrame:SetSize(200, 20)
    textFrame:SetPoint("BOTTOM", details2.baseframe, "BOTTOM", 0, -3)
    textFrame:EnableMouse(true)

    local text = textFrame:CreateFontString("DetailsToggleText", "OVERLAY", "GameFontNormal")
    text:SetAllPoints()
    text:SetText("Expand")
    text:SetAlpha(0)
    text:SetFont(text:GetFont(), 12)

    local function UpdateText()
        if isExpanded then
            text:SetText("Minimize")
        else
            text:SetText("Expand")
        end
    end

    textFrame:SetScript("OnMouseDown", function()
        isExpanded = not isExpanded
        UpdateText()
        if isExpanded then
            ExpandDetailsWindows()
        else
            ResizeAllDetailsWindows()
        end
    end)

    textFrame:SetScript("OnEnter", function()
        text:SetAlpha(1)
    end)

    textFrame:SetScript("OnLeave", function()
        text:SetAlpha(0)
    end)
end

-- Set CVars according to Perskan's preferences
local function InitializeCVars(self)
    local profile = self.db.profile
    SetCVar("Sound_AmbienceVolume", profile.soundAmbienceVolume)
    SetCVar("cameraYawMoveSpeed", profile.cameraYawMoveSpeed)
    SetCVar("cameraPivot", profile.cameraPivot and 1 or 0)
    SetCVar("nameplateOtherBottomInset", profile.nameplateOtherBottomInset)
    SetCVar("nameplateOtherTopInset", profile.nameplateOtherTopInset)
    SetCVar("cameraDistanceMaxZoomFactor", profile.cameraDistanceMaxZoomFactor)
    SetCVar("autoLootDefault", 1)
    SetCVar("alwaysShowNameplates", 1)
    SetCVar("nameplateShowAll", 1)
    SetCVar("nameplateShowEnemies", 1)
    SetCVar("nameplateShowFriends", 1)
    SetCVar("nameplateShowEnemyMinions", 1)
    SetCVar("nameplateShowFriendlyMinions", 1)
    SetCVar("raidFramesDisplayAggroHighlight", 0)
    SetCVar("raidFramesDisplayClassColor", 1)
    SetCVar("raidOptionDisplayMainTankAndAssist", 0)
    SetCVar("pvpFramesDisplayClassColor", 1)
    SetCVar("nameplateShowSelf", 0)
end

-- Events
function Perskan:OnEnable()
    HighlightStealableAuras()
    ScaleUIFrames()
    ToggleDetailsWindows()
    CreateToggleText()

    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- ObjectiveTrackerFrame events
    self:RegisterEvent("SCENARIO_UPDATE", ToggleDetailsWindows)
    self:RegisterEvent("SCENARIO_CRITERIA_UPDATE", ToggleDetailsWindows)
    self:RegisterEvent("CHALLENGE_MODE_START", ToggleDetailsWindows)
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", ToggleDetailsWindows)
    self:RegisterEvent("CHALLENGE_MODE_RESET", ToggleDetailsWindows)
    self:RegisterEvent("QUEST_WATCH_UPDATE", ToggleDetailsWindows)
    self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", ToggleDetailsWindows)
    self:RegisterEvent("CONTENT_TRACKING_UPDATE", ToggleDetailsWindows)

    -- Register events for role changes and group changes
    self:RegisterEvent("GROUP_ROSTER_UPDATE", ToggleDetailsWindows)
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", ToggleDetailsWindows)
    self:RegisterEvent("GROUP_LEFT", ToggleDetailsWindows)
    self:RegisterEvent("GROUP_JOINED", ToggleDetailsWindows)
end

function Perskan:PLAYER_ENTERING_WORLD()
    InitializeCVars(self)
    AdjustActionBars()
end

function Perskan:ACTIVE_TALENT_GROUP_CHANGED()
    AdjustActionBars()
    ResizeAllDetailsWindows()
end

SettingsPanel:HookScript("OnShow", function()
    CreateSpecSliders(AdjustActionBars)
end)
