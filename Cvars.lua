local CVars = CreateFrame("Frame")
CVars:HookScript("OnEvent", function()
    -- Prevent ambience volume increase
    SetCVar("Sound_AmbienceVolume", 0.1)

    -- Camera fixes
    SetCVar("cameraYawMoveSpeed", 90)

    -- Misc
    C_CVar.SetCVar("cameraPivot", 0)
    C_CVar.SetCVar("nameplateOtherBottomInset", 0.1)
    C_CVar.SetCVar("nameplateOtherTopInset", 0.09)
    C_CVar.SetCVar("nameplateOtherBottomInset", -1) --  0.1
    C_CVar.SetCVar("cameraDistanceMaxZoomFactor", 2.3) -- 1.9 
end);
CVars:RegisterEvent("PLAYER_LOGIN")
