local details = _G.Details
local details1, details2

local mainDetailsMaxHeight = 80
local secondaryDetailsMaxHeight = 134

if details then
    details1 = details:GetInstance(1)
    details2 = details:GetInstance(2)
end

local details1Expanded = false
local details2Expanded = false

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

    local detailsWidth = 260

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

    local baseHeight = 28
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

    if not details1Expanded then
        AdjustDetailsHeight(details1, mainDetailsMaxHeight, true)
    end
    if not details2Expanded then
        AdjustDetailsHeight(details2, secondaryDetailsMaxHeight)
    end

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
local function ExpandDetailsWindow(parentFrame)
    if not C_AddOns.IsAddOnLoaded("Details") or not Perskan.db.profile.reanchorDetailsWindows then
        return
    end

    if parentFrame == details1 then
        local pos_table1 = details1:CreatePositionTable()
        pos_table1.h = mainDetailsMaxHeight
        details1:RestorePositionFromPositionTable(pos_table1)
    end

    if parentFrame == details2 then
        local pos_table2 = details2:CreatePositionTable()
        pos_table2.h = secondaryDetailsMaxHeight
        details2:RestorePositionFromPositionTable(pos_table2)
    end

    ReanchorDetailsWindows()
end

-- Create the Expand/Minimize button
local function CreateToggleButton(parentFrame, initialState)
    if not Perskan.db.profile.reanchorDetailsWindows or not parentFrame then
        return
    end

    local button =
        CreateFrame("Button", "DetailsToggleButton" .. parentFrame.baseframe:GetName(), parentFrame.baseframe)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(parentFrame.baseframe:GetFrameLevel() + 1)
    button:SetSize(16, 18)
    button:SetPoint("TOPRIGHT", parentFrame.baseframe, "TOPRIGHT", -8, 26)
    button:EnableMouse(true)

    local texCoords = {
        minus = {952 / 1024, 985 / 1024, 59 / 512, 96 / 512},
        minusPushed = {905 / 1024, 938 / 1024, 122 / 512, 160 / 512},
        plus = {905 / 1024, 938 / 1024, 161 / 512, 199 / 512},
        plusPushed = {905 / 1024, 938 / 1024, 202 / 512, 242 / 512},
        highlight = {943 / 1024, 976 / 1024, 161 / 512, 200 / 512}
    }

    local texture = button:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\QUESTFRAME\\QuestTracker2x")
    texture:SetAllPoints(button)
    texture:SetTexCoord(unpack(texCoords.minus))
    button:SetNormalTexture(texture)

    local pushedTexture = button:CreateTexture(nil, "ARTWORK")
    pushedTexture:SetTexture("Interface\\QUESTFRAME\\QuestTracker2x")
    pushedTexture:SetAllPoints(button)
    pushedTexture:SetTexCoord(unpack(texCoords.minusPushed))
    button:SetPushedTexture(pushedTexture)

    local highlightTexture = button:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetTexture("Interface\\QUESTFRAME\\QuestTracker2x")
    highlightTexture:SetAllPoints(button)
    highlightTexture:SetTexCoord(unpack(texCoords.highlight))
    highlightTexture:SetBlendMode("ADD")
    button:SetHighlightTexture(highlightTexture)

    local isExpanded = initialState

    local function UpdateButtonTextures()
        if isExpanded then
            texture:SetTexCoord(unpack(texCoords.minus))
            pushedTexture:SetTexCoord(unpack(texCoords.minusPushed))
        else
            texture:SetTexCoord(unpack(texCoords.plus))
            pushedTexture:SetTexCoord(unpack(texCoords.plusPushed))
        end
    end

    button:SetScript("OnClick", function()
        isExpanded = not isExpanded
        UpdateButtonTextures()

        if parentFrame == details1 then
            details1Expanded = isExpanded
        end

        if parentFrame == details2 then
            details2Expanded = isExpanded
        end

        if isExpanded then
            ExpandDetailsWindow(parentFrame)
        else
            ResizeAllDetailsWindows()
        end
    end)

    UpdateButtonTextures()
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
    SetCVar("autoLootDefault", profile.autoLootDefault)
    SetCVar("alwaysShowNameplates", profile.alwaysShowNameplates)
    SetCVar("nameplateShowAll", profile.nameplateShowAll)
    SetCVar("nameplateShowEnemies", profile.nameplateShowEnemies)
    SetCVar("nameplateShowFriends", profile.nameplateShowFriends)
    SetCVar("nameplateShowEnemyMinions", profile.nameplateShowEnemyMinions)
    SetCVar("nameplateShowFriendlyMinions", profile.nameplateShowFriendlyMinions)
    SetCVar("raidFramesDisplayAggroHighlight", profile.raidFramesDisplayAggroHighlight)
    SetCVar("raidFramesDisplayClassColor", profile.raidFramesDisplayClassColor)
    SetCVar("raidOptionDisplayMainTankAndAssist", profile.raidOptionDisplayMainTankAndAssist)
    SetCVar("pvpFramesDisplayClassColor", profile.pvpFramesDisplayClassColor)
    SetCVar("nameplateShowSelf", profile.nameplateShowSelf)
    SetCVar("nameplateHideHealthAndPower", profile.nameplateHideHealthAndPower)
end

-- Events
function Perskan:OnEnable()
    HighlightStealableAuras()
    ScaleUIFrames()
    ToggleDetailsWindows()
    -- CreateToggleText()
    CreateToggleButton(details1, details1Expanded)
    CreateToggleButton(details2, details2Expanded)

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
