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

-- Function to resize buff/debuff icons on target and focus frames
local function SetupTargetFocusAuraSize()
    local function ProcessUnitFrameAuras(unitFrame)
        if not unitFrame then return end

        local size = Perskan.db.profile.targetFocusAuraSize or 20

        -- Modern WoW uses auraPools for all auras
        if unitFrame.auraPools then
            for auraFrame in unitFrame.auraPools:EnumerateActive() do
                auraFrame:SetSize(size, size)
            end
        end
    end

    local function ProcessTargetAndFocusFrames()
        ProcessUnitFrameAuras(TargetFrame)
        ProcessUnitFrameAuras(FocusFrame)
    end

    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:RegisterEvent("UNIT_AURA")
    setupFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    setupFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")

    setupFrame:SetScript("OnEvent", function(self, event, unit)
        -- Only process for target/focus aura changes
        if event == "UNIT_AURA" and unit ~= "target" and unit ~= "focus" then
            return
        end
        ProcessTargetAndFocusFrames()
    end)
end

-- Set width, height and scale of DamageMeter session windows
local function SetupDamageMeterSize()
    local hookedWindows = {}
    local originalSetWidth = {}
    local originalSetHeight = {}
    local originalSetScale = {}
    local hookedDamageMeterParent = false
    local originalDamageMeterSetWidth = nil
    local originalDamageMeterSetHeight = nil

    local function GetAllDamageMeterSessionWindows()
        local windows = {}
        local i = 1
        while true do
            local window = _G["DamageMeterSessionWindow" .. i]
            if window then
                table.insert(windows, window)
                i = i + 1
            else
                break
            end
        end
        return windows
    end

    local function ApplyScaleToWindow(window)
        local scale = Perskan.db.profile.damageMeterScale
        local setScaleFunc = originalSetScale[window] or window.SetScale
        if scale then
            setScaleFunc(window, scale)
        end
    end

    local function ApplyDamageMeterSettings()
        local width = Perskan.db.profile.damageMeterWidth
        local height = Perskan.db.profile.damageMeterHeight

        -- Apply width and height to DamageMeter parent frame (controls primary window)
        -- Primary window has ~43px more padding than secondary windows for width
        if DamageMeter then
            if not hookedDamageMeterParent then
                hookedDamageMeterParent = true
                originalDamageMeterSetWidth = DamageMeter.SetWidth
                DamageMeter.SetWidth = function(self, w)
                    local ourWidth = Perskan.db.profile.damageMeterWidth
                    originalDamageMeterSetWidth(self, ourWidth and (ourWidth - 43) or w)
                end
                originalDamageMeterSetHeight = DamageMeter.SetHeight
                DamageMeter.SetHeight = function(self, h)
                    local ourHeight = Perskan.db.profile.damageMeterHeight
                    originalDamageMeterSetHeight(self, ourHeight and (ourHeight - 10) or h)
                end
            end
            if width then
                originalDamageMeterSetWidth(DamageMeter, width - 43)
            end
            if height then
                originalDamageMeterSetHeight(DamageMeter, height * 0.8)
            end
        end

        -- Apply width, height and scale to all session windows
        for _, window in ipairs(GetAllDamageMeterSessionWindows()) do
            -- Apply width directly to all session windows
            if width then
                if not originalSetWidth[window] then
                    originalSetWidth[window] = window.SetWidth
                    window.SetWidth = function(self, w)
                        local ourWidth = Perskan.db.profile.damageMeterWidth
                        originalSetWidth[self](self, ourWidth or w)
                    end
                end
                originalSetWidth[window](window, width)
            end

            -- Apply height directly to all session windows
            if height then
                if not originalSetHeight[window] then
                    originalSetHeight[window] = window.SetHeight
                    window.SetHeight = function(self, h)
                        local ourHeight = Perskan.db.profile.damageMeterHeight
                        originalSetHeight[self](self, ourHeight or h)
                    end
                end
                originalSetHeight[window](window, height)
            end

            if not hookedWindows[window] then
                hookedWindows[window] = true

                originalSetScale[window] = window.SetScale
                window.SetScale = function(self, s)
                    local ourScale = Perskan.db.profile.damageMeterScale
                    originalSetScale[self](self, ourScale or s)
                end

                window:HookScript("OnShow", function(self)
                    ApplyScaleToWindow(self)
                end)
            end

            ApplyScaleToWindow(window)
        end

        -- Anchor to MicroMenu if enabled
        if Perskan.db.profile.damageMeterAnchorToMicroMenu and MicroMenu then
            -- Anchor primary window (DamageMeter) to top right of MicroMenu
            if DamageMeter then
                DamageMeter:ClearAllPoints()
                DamageMeter:SetPoint("BOTTOMRIGHT", MicroMenu, "TOPRIGHT", 20, 0)
            end

            -- Anchor secondary windows to the left of the primary
            local windows = GetAllDamageMeterSessionWindows()
            for i = 2, #windows do
                local window = windows[i]
                local prevWindow = windows[i - 1]
                window:ClearAllPoints()
                window:SetPoint("BOTTOMRIGHT", prevWindow, "BOTTOMLEFT", 30, 0)
            end
        end
    end

    Perskan.ApplyDamageMeterSettings = ApplyDamageMeterSettings

    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:RegisterEvent("ADDON_LOADED")

    local initialized = false
    setupFrame:SetScript("OnEvent", function(self, event, arg1)
        if DamageMeterSessionWindow1 and not initialized then
            initialized = true
            ApplyDamageMeterSettings()
        end
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

    -- Set nameplate width using the API
    if profile.nameplateWidth then
        C_NamePlate.SetNamePlateSize(profile.nameplateWidth, 45)
    end
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

-- Shared function to reposition BuffBarCooldownViewer (called by both anchor functions)
-- BuffBars anchor above ExtraQuestButton if visible, otherwise above the container
local function RepositionBuffBarAboveWidget()
    if not BuffBarCooldownViewer or not UIParentBottomManagedFrameContainer then return end
    if InCombatLockdown() then return end

    BuffBarCooldownViewer:ClearAllPoints()

    -- Check if ExtraQuestButton exists, is visible, and anchoring is enabled
    if Perskan.db.profile.anchorExtraQuestButton and ExtraQuestButton and ExtraQuestButton:IsShown() then
        -- Anchor above ExtraQuestButton
        BuffBarCooldownViewer:SetPoint("BOTTOM", ExtraQuestButton, "TOP", 0, 15)
    else
        -- Anchor above the managed frame container
        BuffBarCooldownViewer:SetPoint("BOTTOM", UIParentBottomManagedFrameContainer, "TOP", 0, 20)
    end

    -- Reposition bar containers if sorting is enabled
    if Perskan.db.profile.sortBuffBarsUpward then
        RepositionBuffBarContainers()
    end
end

-- Function to anchor ExtraQuestButton above the widget container
-- Note: We don't use AddManagedFrame to avoid tainting the container (causes combat errors)
local function AnchorExtraQuestButton()
    if not Perskan.db.profile.anchorExtraQuestButton then
        return
    end

    local function RepositionExtraQuestButton()
        if not ExtraQuestButton or not UIParentBottomManagedFrameContainer then return end
        if InCombatLockdown() then return end

        -- Position above the managed frame container
        ExtraQuestButton:ClearAllPoints()
        ExtraQuestButton:SetPoint("BOTTOM", UIParentBottomManagedFrameContainer, "TOP", 0, 20)

        -- Also reposition buff bars since they depend on ExtraQuestButton visibility
        if Perskan.db.profile.anchorBuffBarsToWidgetFrame then
            RepositionBuffBarAboveWidget()
        end
    end

    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:RegisterEvent("ADDON_LOADED")
    setupFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    local initialized = false
    setupFrame:SetScript("OnEvent", function(self, event, ...)
        if ExtraQuestButton and UIParentBottomManagedFrameContainer then
            if not initialized then
                -- Hook layout to reposition dynamically when container changes
                hooksecurefunc(UIParentBottomManagedFrameContainer, "Layout", function()
                    if not InCombatLockdown() then
                        RepositionExtraQuestButton()
                    end
                end)

                -- Hook ExtraQuestButton show/hide to update buff bar position
                ExtraQuestButton:HookScript("OnShow", function()
                    if not InCombatLockdown() and Perskan.db.profile.anchorBuffBarsToWidgetFrame then
                        RepositionBuffBarAboveWidget()
                    end
                end)
                ExtraQuestButton:HookScript("OnHide", function()
                    if not InCombatLockdown() and Perskan.db.profile.anchorBuffBarsToWidgetFrame then
                        RepositionBuffBarAboveWidget()
                    end
                end)

                -- Initial position
                RepositionExtraQuestButton()

                initialized = true
                self:UnregisterEvent("PLAYER_ENTERING_WORLD")
                self:UnregisterEvent("ADDON_LOADED")
            end

            -- Re-anchor after leaving combat
            if event == "PLAYER_REGEN_ENABLED" then
                RepositionExtraQuestButton()
            end
        end
    end)
end

-- Function to anchor BuffBarCooldownViewer above the widget (and above ExtraQuestButton if visible)
-- Note: We don't use AddManagedFrame to avoid tainting the container (causes combat errors)
local function AnchorBuffBarsToWidgetFrame()
    if not Perskan.db.profile.anchorBuffBarsToWidgetFrame then
        return
    end

    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:RegisterEvent("ADDON_LOADED")
    setupFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    local initialized = false
    setupFrame:SetScript("OnEvent", function(self, event, ...)
        if BuffBarCooldownViewer and UIParentBottomManagedFrameContainer then
            if not initialized then
                -- Hook layout to reposition dynamically when container changes
                hooksecurefunc(UIParentBottomManagedFrameContainer, "Layout", function()
                    if not InCombatLockdown() then
                        RepositionBuffBarAboveWidget()
                    end
                end)

                -- Initial position
                RepositionBuffBarAboveWidget()

                -- Set up buff bar sorting if enabled
                if Perskan.db.profile.sortBuffBarsUpward then
                    CollectBuffBarContainers()
                    RepositionBuffBarContainers()
                end

                initialized = true
                self:UnregisterEvent("PLAYER_ENTERING_WORLD")
                self:UnregisterEvent("ADDON_LOADED")
            end

            -- Re-anchor after leaving combat
            if event == "PLAYER_REGEN_ENABLED" then
                RepositionBuffBarAboveWidget()
            end
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
                RepositionBuffBarContainers()
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
    SetupTargetFocusAuraSize()
    SetupDamageMeterSize()
    AnchorBuffBarsToWidgetFrame()
    AnchorExtraQuestButton()
    SetupBuffBarSorting()

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Perskan:PLAYER_ENTERING_WORLD()
    InitializeCVars(self)
end
