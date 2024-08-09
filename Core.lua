local Perskan = CreateFrame("Frame")
local settingsLoaded = false

local function Perskan_OnLoad(self, event, ...)
    -- Scale various UI frames
    EncounterBar:SetScale(0.8)

    -- Set a stealable texture even if you have no purge
    local function TargetFrame_UpdateAuras(self)
        for buff in self.auraPools:GetPool("TargetBuffFrameTemplate"):EnumerateActive() do
            local buffSize = buff.GetHeight(buff)
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID(buff.unit, buff.auraInstanceID)
            buff.Stealable:SetShown(data.isStealable or data.dispelName == "Magic")
            local stealableSize = buffSize + 2
            buff.Stealable:SetSize(stealableSize, stealableSize)
            buff.Stealable:SetPoint("CENTER", buff, "CENTER")
        end
    end

    hooksecurefunc(TargetFrame, "UpdateAuras", TargetFrame_UpdateAuras)
    hooksecurefunc(FocusFrame, "UpdateAuras", TargetFrame_UpdateAuras)

    -- Toggle action bars based on spec
    if event == "SETTINGS_LOADED" then
        settingsLoaded = true
    end

    if settingsLoaded then
        local specsToCheck = {"Devastation", "Retribution"}

        local function isSpecInList(specName, specList)
            for _, name in ipairs(specList) do
                if name == specName then
                    return true
                end
            end
            return false
        end

        local id, name, description, icon, background, role = GetSpecializationInfo(GetSpecialization())

        if isSpecInList(name, specsToCheck) then
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_3", false)
        else
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_3", true)
        end
    end

end

Perskan:RegisterEvent("PLAYER_ENTERING_WORLD")
Perskan:RegisterEvent("SETTINGS_LOADED")
Perskan:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
Perskan:SetScript("OnEvent", Perskan_OnLoad)
