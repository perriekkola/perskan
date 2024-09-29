-- Scale various UI frames
local function ScaleUIFrames()
    EncounterBar:SetScale(Perskan.db.profile.encounterBarScale or 0.8)
end

-- Highlight stealable auras
local function HighlightStealableAuras()
    local function UpdateAuras(self)
        for buff in self.auraPools:GetPool("TargetBuffFrameTemplate"):EnumerateActive() do
            -- local buffSize = buff:GetHeight()
            local buffSize = 21
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

-- Move minimap
Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -7, -38)

-- Hide quick join toast button
QuickJoinToastButton:Hide()

-- Function to hide HotKey and BPHotKey elements for all ActionButtons
local function HideActionButtonHotKeys()
    local function HideHotKeys(button)
        if button.TextOverlayContainer then
            button.TextOverlayContainer:Hide()
        end
    end

    for i = 1, 12 do
        local actionButton = _G["ActionButton" .. i]
        if actionButton then
            HideHotKeys(actionButton)
        end
    end

    for i = 1, 12 do
        local multiBarBottomLeftButton = _G["MultiBarBottomLeftButton" .. i]
        if multiBarBottomLeftButton then
            HideHotKeys(multiBarBottomLeftButton)
        end

        local multiBarBottomRightButton = _G["MultiBarBottomRightButton" .. i]
        if multiBarBottomRightButton then
            HideHotKeys(multiBarBottomRightButton)
        end

        local multiBarRightButton = _G["MultiBarRightButton" .. i]
        if multiBarRightButton then
            HideHotKeys(multiBarRightButton)
        end

        local multiBarLeftButton = _G["MultiBarLeftButton" .. i]
        if multiBarLeftButton then
            HideHotKeys(multiBarLeftButton)
        end
    end
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
    SetCVar("nameplateShowEnemyMinions", profile.nameplateShowEnemyMinions)
    SetCVar("nameplateShowFriendlyMinions", profile.nameplateShowFriendlyMinions)
    SetCVar("raidFramesDisplayAggroHighlight", profile.raidFramesDisplayAggroHighlight)
    SetCVar("raidFramesDisplayClassColor", profile.raidFramesDisplayClassColor)
    SetCVar("raidOptionDisplayMainTankAndAssist", profile.raidOptionDisplayMainTankAndAssist)
    SetCVar("pvpFramesDisplayClassColor", profile.pvpFramesDisplayClassColor)
    SetCVar("nameplateShowSelf", profile.nameplateShowSelf)
    SetCVar("nameplateHideHealthAndPower", profile.nameplateHideHealthAndPower)
    SetCVar("NameplatePersonalShowAlways", profile.nameplatePersonalShowAlways)
end

-- Variable to track the last time the event handler was executed
local lastTalentGroupChangeTime = 0
local debounceDelay = 1 -- 1 second debounce delay

-- Events
function Perskan:OnEnable()
    HighlightStealableAuras()
    ScaleUIFrames()
    HideActionButtonHotKeys()

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Perskan:PLAYER_ENTERING_WORLD()
    InitializeCVars(self)
end
