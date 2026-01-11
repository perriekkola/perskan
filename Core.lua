-- Modify various UI frames
local function ModifyUI()
    -- Scale EncounterBar
    EncounterBar:SetScale(Perskan.db.profile.encounterBarScale or 0.8)

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

-- Function to hide macro text (Name) elements for all ActionButtons
local function HideActionButtonMacroText()
    if not Perskan.db.profile.hideMacroText then
        return
    end

    local function HideMacroText(button)
        if button.Name then
            button.Name:Hide()
            button.Name:SetAlpha(0)
            hooksecurefunc(button.Name, "Show", function(self)
                self:Hide()
            end)
        end
    end

    for i = 1, 12 do
        local actionButton = _G["ActionButton" .. i]
        if actionButton then
            HideMacroText(actionButton)
        end
    end

    for i = 1, 12 do
        local multiBarBottomLeftButton = _G["MultiBarBottomLeftButton" .. i]
        if multiBarBottomLeftButton then
            HideMacroText(multiBarBottomLeftButton)
        end

        local multiBarBottomRightButton = _G["MultiBarBottomRightButton" .. i]
        if multiBarBottomRightButton then
            HideMacroText(multiBarBottomRightButton)
        end

        local multiBarRightButton = _G["MultiBarRightButton" .. i]
        if multiBarRightButton then
            HideMacroText(multiBarRightButton)
        end

        local multiBarLeftButton = _G["MultiBarLeftButton" .. i]
        if multiBarLeftButton then
            HideMacroText(multiBarLeftButton)
        end
    end
end

-- Function to hide the BagsBar
local function HideBagsBar()
    if Perskan.db.profile.hideBagsBar then
        BagsBar:Hide()
    end
end

-- Function to force show cooldown numbers on aura icons
local function SetupAuraCooldownNumbers()
    if not Perskan.db.profile.showAuraCooldownNumbers then
        return
    end

    local function EnableCooldownNumbers(frame)
        if frame and frame.Cooldown then
            frame.Cooldown:SetHideCountdownNumbers(false)

            -- Apply scale to the cooldown text
            local scale = Perskan.db.profile.auraCooldownNumbersScale or 0.75
            for _, region in pairs({frame.Cooldown:GetRegions()}) do
                if region:GetObjectType() == "FontString" then
                    local font, _, flags = region:GetFont()
                    if font then
                        region:SetFont(font, 12 * scale, flags)
                    end
                end
            end
        end
    end

    local function ProcessUnitFrameAuras(unitFrame)
        if not unitFrame then return end

        -- Modern WoW uses auraPools
        if unitFrame.auraPools then
            for auraFrame in unitFrame.auraPools:EnumerateActive() do
                EnableCooldownNumbers(auraFrame)
            end
        end

        -- Also check children directly for frames with Cooldown
        for _, child in ipairs({unitFrame:GetChildren()}) do
            if child.Cooldown then
                EnableCooldownNumbers(child)
            end
        end
    end

    local function ProcessAllUnitFrames()
        -- Process main unit frames
        ProcessUnitFrameAuras(TargetFrame)
        ProcessUnitFrameAuras(FocusFrame)
        ProcessUnitFrameAuras(PlayerFrame)

        -- Boss frames
        for i = 1, 8 do
            ProcessUnitFrameAuras(_G["Boss" .. i .. "TargetFrame"])
        end

        -- Party frames
        for i = 1, 4 do
            ProcessUnitFrameAuras(_G["PartyMemberFrame" .. i])
        end
    end

    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:RegisterEvent("UNIT_AURA")
    setupFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    setupFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")

    setupFrame:SetScript("OnEvent", function(self, event, ...)
        -- Delay processing to ensure frames are ready
        C_Timer.After(0.1, ProcessAllUnitFrames)
    end)

    -- Also run periodically for the first few seconds to catch late-loading frames
    C_Timer.After(1, ProcessAllUnitFrames)
    C_Timer.After(2, ProcessAllUnitFrames)
    C_Timer.After(3, ProcessAllUnitFrames)
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

-- Shared state for BuffBarCooldownViewer sorting
local buffBarSortingState = {
    allContainers = {},
    containerHeight = nil,
    containerSpacing = 2,
    parentFrame = nil,
    initialized = false,
}

-- Collect all child containers that have an Icon
local function CollectBuffBarContainers()
    wipe(buffBarSortingState.allContainers)

    buffBarSortingState.parentFrame = BuffBarCooldownViewer
    if not buffBarSortingState.parentFrame then
        return
    end

    for _, child in ipairs({buffBarSortingState.parentFrame:GetChildren()}) do
        if child.Icon then
            table.insert(buffBarSortingState.allContainers, child)
            if not buffBarSortingState.containerHeight then
                buffBarSortingState.containerHeight = child:GetHeight()
            end
        end
    end
end

-- Reposition visible containers to stack upward
local function RepositionBuffBarContainers()
    if not Perskan.db.profile.sortBuffBarsUpward or not buffBarSortingState.parentFrame then
        return
    end

    -- Recalculate height if needed
    if not buffBarSortingState.containerHeight and #buffBarSortingState.allContainers > 0 then
        buffBarSortingState.containerHeight = buffBarSortingState.allContainers[1]:GetHeight()
    end

    local visibleIndex = 0
    for _, container in ipairs(buffBarSortingState.allContainers) do
        if container:IsVisible() then
            container:ClearAllPoints()
            container:SetPoint("BOTTOMLEFT", buffBarSortingState.parentFrame, "BOTTOMLEFT", 0, visibleIndex * (buffBarSortingState.containerHeight + buffBarSortingState.containerSpacing))
            visibleIndex = visibleIndex + 1
        end
    end
end

-- Function to anchor BuffBarCooldownViewer to UIParentBottomManagedFrameContainer dynamically
local function AnchorBuffBarsToWidgetFrame()
    if not Perskan.db.profile.anchorBuffBarsToWidgetFrame then
        return
    end

    local function CenterBuffBarAndReposition()
        if BuffBarCooldownViewer then
            local _, relativeTo, _, _, yOfs = BuffBarCooldownViewer:GetPoint(1)
            if relativeTo then
                BuffBarCooldownViewer:ClearAllPoints()
                BuffBarCooldownViewer:SetPoint("TOP", relativeTo, "TOP", 0, (yOfs or 0) + 5)
            end
        end
        -- Also reposition the bar containers after layout changes
        C_Timer.After(0.01, RepositionBuffBarContainers)
    end

    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:RegisterEvent("ADDON_LOADED")

    setupFrame:SetScript("OnEvent", function(self, event, ...)
        if BuffBarCooldownViewer and UIParentBottomManagedFrameContainer then
            -- Set up BuffBarCooldownViewer as a managed frame
            BuffBarCooldownViewer:SetParent(UIParentBottomManagedFrameContainer)
            BuffBarCooldownViewer.layoutIndex = 1 -- Lower than cast bar (2) to be on top
            BuffBarCooldownViewer.IsInDefaultPosition = function() return true end

            -- Ensure the frame reports its size for layout calculations
            local height = BuffBarCooldownViewer:GetHeight()
            if height == 0 then
                BuffBarCooldownViewer:SetHeight(150) -- Default height if not set
            end

            -- Add to managed frame container
            UIParentBottomManagedFrameContainer:AddManagedFrame(BuffBarCooldownViewer)

            -- Hook layout to center horizontally and reposition bars after each update
            hooksecurefunc(UIParentBottomManagedFrameContainer, "Layout", CenterBuffBarAndReposition)

            -- Trigger layout update and center
            UIParentBottomManagedFrameContainer:Layout()

            self:UnregisterAllEvents()
        end
    end)
end

-- Function to anchor ExtraQuestButton to UIParentBottomManagedFrameContainer below cast bar
local function AnchorExtraQuestButton()
    if not Perskan.db.profile.anchorExtraQuestButton then
        return
    end

    local function CenterExtraQuestButton()
        if ExtraQuestButton then
            local _, relativeTo, _, _, yOfs = ExtraQuestButton:GetPoint(1)
            if relativeTo then
                ExtraQuestButton:ClearAllPoints()
                ExtraQuestButton:SetPoint("TOP", relativeTo, "TOP", 0, (yOfs or 0) - 15)
            end
        end
    end

    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:RegisterEvent("ADDON_LOADED")

    setupFrame:SetScript("OnEvent", function(self, event, ...)
        if ExtraQuestButton and UIParentBottomManagedFrameContainer then
            -- Set up ExtraQuestButton as a managed frame
            ExtraQuestButton:SetParent(UIParentBottomManagedFrameContainer)
            ExtraQuestButton.layoutIndex = 3 -- Higher than cast bar (2) to be below it
            ExtraQuestButton.IsInDefaultPosition = function() return true end

            -- Ensure the frame reports its size for layout calculations
            local height = ExtraQuestButton:GetHeight()
            if height == 0 then
                ExtraQuestButton:SetHeight(50) -- Default height if not set
            end

            -- Add to managed frame container
            UIParentBottomManagedFrameContainer:AddManagedFrame(ExtraQuestButton)

            -- Hook layout to center horizontally after each update
            hooksecurefunc(UIParentBottomManagedFrameContainer, "Layout", CenterExtraQuestButton)

            -- Trigger layout update and center
            UIParentBottomManagedFrameContainer:Layout()

            self:UnregisterAllEvents()
        end
    end)
end

-- Function to sort BuffBarCooldownViewer bars upward without gaps
local function SetupBuffBarSorting()
    if not Perskan.db.profile.sortBuffBarsUpward then
        return
    end

    -- Setup frame to initialize after BuffBarCooldownViewer loads
    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:RegisterEvent("ADDON_LOADED")
    setupFrame:RegisterEvent("UNIT_AURA")

    setupFrame:SetScript("OnEvent", function(self, event, arg1, ...)
        if event == "UNIT_AURA" then
            -- Only reposition when player's auras change
            if arg1 == "player" then
                -- Small delay to let BuffBarCooldownViewer update first
                C_Timer.After(0.01, RepositionBuffBarContainers)
            end
            return
        end

        -- Initial setup on login/load
        CollectBuffBarContainers()

        if #buffBarSortingState.allContainers > 0 and not buffBarSortingState.initialized then
            RepositionBuffBarContainers()
            buffBarSortingState.initialized = true
        end
    end)
end

-- Events
function Perskan:OnEnable()
    ModifyUI()
    HideActionButtonHotKeys()
    HideActionButtonMacroText()
    HideBagsBar()
    SetupAuraCooldownNumbers()
    AnchorBuffBarsToWidgetFrame()
    AnchorExtraQuestButton()
    SetupBuffBarSorting()

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Perskan:PLAYER_ENTERING_WORLD()
    InitializeCVars(self)
end
