local Perskan = CreateFrame("Frame")
defaultBottomMargin = 8
oneBarMargin = 20
twoBarMargin = 40

local function Perskan_OnLoad()
    local LibEditModeOverride = LibStub("LibEditModeOverride-1.0")

    -- Move actionbars and override edit mode
    if LibEditModeOverride:IsReady() then
        LibEditModeOverride:LoadLayouts()

        -- Check if there is a status tracking bar
        local bottomMargin = defaultBottomMargin
        if MainStatusTrackingBarContainer:IsVisible() then
            bottomMargin = oneBarMargin
        end
        if SecondaryStatusTrackingBarContainer:IsVisible() then
            bottomMargin = twoBarMargin
        end

        -- Reanchor actionbars
        LibEditModeOverride:ReanchorFrame(MainMenuBar, "BOTTOM", UIParent, "BOTTOM", 0, bottomMargin)
        LibEditModeOverride:ReanchorFrame(MultiBarBottomLeft, "BOTTOM", MainMenuBar, "TOP", 0, 4)
        LibEditModeOverride:ReanchorFrame(MultiBarBottomRight, "BOTTOM", MultiBarBottomLeft, "TOP", 0, 1)

        -- Check if MultiBarBottomRight is activated, then move stance and pet bar
        local bottomLeftState, bottomRightState, sideRightState, sideRight2State = GetActionBarToggles()
        if bottomRightState == false then
            LibEditModeOverride:ReanchorFrame(StanceBar, "BOTTOMLEFT", MultiBarBottomLeftButton1, "TOPLEFT", 0, 3)
            LibEditModeOverride:ReanchorFrame(PetActionBar, "BOTTOMRIGHT", MultiBarBottomLeftButton12, "TOPRIGHT", -2, 3)
        else
            LibEditModeOverride:ReanchorFrame(StanceBar, "BOTTOMLEFT", MultiBarBottomRightButton1, "TOPLEFT", 0, 3)
            LibEditModeOverride:ReanchorFrame(PetActionBar, "BOTTOMRIGHT", MultiBarBottomRightButton12, "TOPRIGHT", -2,
                3)
        end

        LibEditModeOverride:ApplyChanges()
    end

    -- Hard position UIParentBottomManagedFrameContainer
    local dummy = function()
    end
    UIParentBottomManagedFrameContainer:ClearAllPoints()
    UIParentBottomManagedFrameContainer:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
    UIParentBottomManagedFrameContainer.ClearAllPoints = dummy
    UIParentBottomManagedFrameContainer.SetPoint = dummy

    -- Scale various UI frames
    EncounterBar:SetScale(0.8)

    -- Hide gryphons
    MainMenuBar.EndCaps.LeftEndCap:Hide()
    MainMenuBar.EndCaps.RightEndCap:Hide()
end

Perskan:RegisterEvent("PLAYER_LOGIN")
Perskan:SetScript("OnEvent", Perskan_OnLoad)

SettingsPanel:HookScript("OnHide", Perskan_OnLoad)

local function MoveMainMenuBar(margin)
    MainMenuBar:ClearAllPoints()
    MainMenuBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, margin)
end

MainStatusTrackingBarContainer:HookScript("OnHide", function()
    MoveMainMenuBar(defaultBottomMargin)
end)

MainStatusTrackingBarContainer:HookScript("OnShow", function()
    MoveMainMenuBar(oneBarMargin)
end)

SecondaryStatusTrackingBarContainer:HookScript("OnHide", function()
    MoveMainMenuBar(oneBarMargin)
end)

SecondaryStatusTrackingBarContainer:HookScript("OnShow", function()
    MoveMainMenuBar(twoBarMargin)
end)
