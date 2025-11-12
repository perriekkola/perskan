-- Modify various UI frames
local function ModifyUI()
    -- Scale EncounterBar
    EncounterBar:SetScale(Perskan.db.profile.encounterBarScale or 0.8)

    -- Move minimap
    if Perskan.db.profile.moveMinimapUp then
        Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -7, -35)
    end

    -- Hide quick join toast button
    if Perskan.db.profile.hideSocialButton then
        QuickJoinToastButton:Hide()
    end

    if Perskan.db.profile.talkingHeadScale then
        hooksecurefunc(TalkingHeadFrame, "PlayCurrent", function()
            TalkingHeadFrame:SetScale(Perskan.db.profile.talkingHeadScale)
        end)
    end

    if Perskan.db.profile.xpBarScale then
        -- Create a frame to handle the StatusTrackingBarManager scaling
        local scaleFrame = CreateFrame("Frame")
        scaleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        scaleFrame:RegisterEvent("PLAYER_LOGIN")
        scaleFrame:RegisterEvent("ADDON_LOADED")
        
        scaleFrame:SetScript("OnEvent", function(self, event, ...)
            if StatusTrackingBarManager then
                -- Set scale and hook OnShow to maintain scale
                StatusTrackingBarManager:SetScale(Perskan.db.profile.xpBarScale)
                if not self.hooked then
                    hooksecurefunc(StatusTrackingBarManager, "SetScale", function(frame, scale)
                        if scale ~= Perskan.db.profile.xpBarScale then
                            frame:SetScale(Perskan.db.profile.xpBarScale)
                        end
                    end)
                    self.hooked = true
                end
            end
        end)
    end

    if Perskan.db.profile.extraActionButtonScale then
       -- Create a frame to handle the StatusTrackingBarManager scaling
       local scaleFrame = CreateFrame("Frame")
       scaleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
       scaleFrame:RegisterEvent("PLAYER_LOGIN")
       scaleFrame:RegisterEvent("ADDON_LOADED")
       
       scaleFrame:SetScript("OnEvent", function(self, event, ...)
           if ExtraAbilityContainer then
               -- Set scale and hook OnShow to maintain scale
               ExtraAbilityContainer:SetScale(Perskan.db.profile.extraActionButtonScale)
               if not self.hooked then
                   hooksecurefunc(ExtraAbilityContainer, "SetScale", function(frame, scale)
                       if scale ~= Perskan.db.profile.extraActionButtonScale then
                           frame:SetScale(Perskan.db.profile.extraActionButtonScale)
                       end
                   end)
                   self.hooked = true
               end
           end
       end)
    end

    if Perskan.db.profile.addChatSizes then
        CHAT_FONT_HEIGHTS = {
            [1] = 7,
            [2] = 8,
            [3] = 9,
            [4] = 10,
            [5] = 11,
            [6] = 12,
            [7] = 13,
            [8] = 14,
            [9] = 15,
            [10] = 16,
            [11] = 17,
            [12] = 18,
            [13] = 19,
            [14] = 20,
            [15] = 21,
            [16] = 22,
            [17] = 23,
            [18] = 24
         };	
    end
end

-- Function to hide HotKey and BPHotKey elements for all ActionButtons
local function HideActionButtonHotKeys()
    if not Perskan.db.profile.hideHotkeys then
        return
    end

    local function HideHotKeys(button)
        if button.HotKey then
            button.HotKey:Hide()
            button.HotKey:SetAlpha(0)
            hooksecurefunc(button.HotKey, "Show", function(self)
                self:Hide()
            end)
        end
        if button.BPHotKey then
            button.BPHotKey:Hide()
            button.BPHotKey:SetAlpha(0)
            hooksecurefunc(button.BPHotKey, "Show", function(self)
                self:Hide()
            end)
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

-- Function to hide the BagsBar
local function HideBagsBar()
    if Perskan.db.profile.hideBagsBar then
        BagsBar:Hide()
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
    ModifyUI()
    HideActionButtonHotKeys()
    HideBagsBar()

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Perskan:PLAYER_ENTERING_WORLD()
    InitializeCVars(self)
end
