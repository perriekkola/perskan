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
        C_Timer.After(1, AdjustActionBars)
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

-- Set ObjectiveTrackerHeight to smaller than edit mode settings
local isSettingHeight = false

local function SetObjectiveTrackerHeight()
    if not isSettingHeight then
        isSettingHeight = true
        ObjectiveTrackerFrame:SetHeight(340)
        isSettingHeight = false
    end
end

hooksecurefunc(ObjectiveTrackerFrame, "SetHeight", function()
    SetObjectiveTrackerHeight()
end)

-- Hide Details when some frames are shown to prevent overlap with objective tracker
local framesToCheck = {DurabilityFrame, VehicleSeatIndicator}

local function ToggleDetailsWindows()
    if not C_AddOns.IsAddOnLoaded("Details") then
        return
    end

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

-- Reanchor Details and set width to Perskan defaults
local function ReanchorDetailsWindows()
    if not C_AddOns.IsAddOnLoaded("Details") then
        return
    end

    details1.baseframe:SetWidth(254)
    details2.baseframe:SetWidth(254)

    if details2 then
        details2.baseframe:ClearAllPoints()
        details2.baseframe:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -2, 100)
    end

    if details1 then
        details1.baseframe:ClearAllPoints()
        details1.baseframe:SetPoint("BOTTOMLEFT", details2.baseframe, "TOPLEFT", 0, 20)
    end
end

-- Resize Details windows to fit group size
local function AdjustDetailsHeight(instance, maxHeight, isHealingWindow)
    if not C_AddOns.IsAddOnLoaded("Details") then
        return
    end

    if not instance then
        return
    end

    local baseHeight = 26
    local heightPerPlayer = 24

    local numGroupMembers = IsActiveBattlefieldArena() and 6 or GetNumGroupMembers()
    numGroupMembers = math.max(numGroupMembers, 1)

    local numHealers = 0
    if isHealingWindow then
        for i = 1, numGroupMembers do
            local role = UnitGroupRolesAssigned("party" .. i)
            if role == "HEALER" then
                numHealers = numHealers + 1
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
    if not C_AddOns.IsAddOnLoaded("Details") then
        return
    end

    AdjustDetailsHeight(details1, mainDetailsMaxHeight, true)
    AdjustDetailsHeight(details2, secondaryDetailsMaxHeight)
    ReanchorDetailsWindows()
end

-- Function to expand Details windows to max size
local function ExpandDetailsWindows()
    if not C_AddOns.IsAddOnLoaded("Details") then
        return
    end

    -- Expand details1
    if details1 then
        local pos_table1 = details1:CreatePositionTable()
        pos_table1.h = mainDetailsMaxHeight
        details1:RestorePositionFromPositionTable(pos_table1)
    end

    -- Expand details2
    if details2 then
        local pos_table2 = details2:CreatePositionTable()
        pos_table2.h = secondaryDetailsMaxHeight
        details2:RestorePositionFromPositionTable(pos_table2)
    end

    ReanchorDetailsWindows()
end

-- Create the Expand/Minimize text
local function CreateToggleText()
    if not details2 then
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
local function InitializeCVars()
    local profile = self.db.profile
    SetCVar("Sound_AmbienceVolume", profile.soundAmbienceVolume)
    SetCVar("cameraYawMoveSpeed", profile.cameraYawMoveSpeed)
    SetCVar("cameraPivot", profile.cameraPivot and 1 or 0)
    SetCVar("nameplateOtherBottomInset", profile.nameplateOtherBottomInset)
    SetCVar("nameplateOtherTopInset", profile.nameplateOtherTopInset)
    SetCVar("cameraDistanceMaxZoomFactor", profile.cameraDistanceMaxZoomFactor)
end

-- Events
function Perskan:OnEnable()
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", AdjustActionBars)
    self:RegisterEvent("SETTINGS_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", OnEventPlayerEnteringWorld)
    self:RegisterEvent("PLAYER_LOGIN", InitializeCVars)
end

function Perskan:PLAYER_ENTERING_WORLD()
    SetObjectiveTrackerHeight()
    ResizeAllDetailsWindows()
end

function Perskan:SETTINGS_LOADED()
    settingsLoaded = true
    CreateSpecSliders(AdjustActionBars)

    AdjustActionBars()
    HighlightStealableAuras()
    ScaleUIFrames()
    HookToggleDetailsWindows()
    ResizeAllDetailsWindows()
    CreateToggleText()
end
