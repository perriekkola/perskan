local Perskan = CreateFrame("Frame")

local function Perskan_OnLoad()
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
end

Perskan:RegisterEvent("PLAYER_ENTERING_WORLD")
Perskan:SetScript("OnEvent", Perskan_OnLoad)
