local Perskan = CreateFrame("Frame")

local function Perskan_OnLoad()
    -- Check if there is a secondary status tracking bar
    local bottomMargin = 20

    if SecondaryStatusTrackingBarContainer:IsVisible() then
        bottomMargin = 40
    end

    -- Move actionbars and override edit mode
    local LibEditModeOverride = LibStub("LibEditModeOverride-1.0")
    LibEditModeOverride:LoadLayouts()
    LibEditModeOverride:ReanchorFrame(MainMenuBar, "BOTTOM", UIParent, "BOTTOM", 0, bottomMargin)
    LibEditModeOverride:ReanchorFrame(MultiBarBottomLeft, "BOTTOM", MainMenuBar, "TOP", 0, 4)
    LibEditModeOverride:ReanchorFrame(MultiBarBottomRight, "BOTTOM", MultiBarBottomLeft, "TOP", 0, 1)

    -- Check if MultiBarBottomRight is activated, then move stance and pet bar
    local bottomLeftState, bottomRightState, sideRightState, sideRight2State = GetActionBarToggles()
    if bottomRightState == false then
        LibEditModeOverride:ReanchorFrame(StanceBar, "BOTTOMLEFT", MultiBarBottomLeftButton1, "TOPLEFT", 0, 3)
        LibEditModeOverride:ReanchorFrame(PetActionBar, "BOTTOMRIGHT", MultiBarBottomLeftButton12, "TOPRIGHT", -12, 3)
    else
        LibEditModeOverride:ReanchorFrame(StanceBar, "BOTTOMLEFT", MultiBarBottomRightButton1, "TOPLEFT", 0, 3)
        LibEditModeOverride:ReanchorFrame(PetActionBar, "BOTTOMRIGHT", MultiBarBottomRightButton12, "TOPRIGHT", -12, 3)
    end

    LibEditModeOverride:ApplyChanges()

    -- Hard position UIParentBottomManagedFrameContainer
    local dummy = function()
    end
    UIParentBottomManagedFrameContainer:ClearAllPoints()
    UIParentBottomManagedFrameContainer:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
    UIParentBottomManagedFrameContainer.ClearAllPoints = dummy
    UIParentBottomManagedFrameContainer.SetPoint = dummy

    -- Scale various UI frames
    EncounterBar:SetScale(0.8)
end

Perskan:RegisterEvent("PLAYER_LOGIN")
Perskan:RegisterEvent("ACTIONBAR_SHOWGRID")
Perskan:SetScript("OnEvent", Perskan_OnLoad)
