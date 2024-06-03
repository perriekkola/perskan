local Perskan = CreateFrame("Frame")

local function Perskan_OnLoad()
    -- Scale buffs on target/focus frame
    local buffSize = 20
    hooksecurefunc("TargetFrame_UpdateBuffAnchor", function(_, buff)
        buff:SetSize(buffSize, buffSize)
    end)
    hooksecurefunc("TargetFrame_UpdateDebuffAnchor", function(_, debuff)
        debuff:SetSize(buffSize, buffSize)
    end)

    -- Move ToT
    TargetFrameToT:ClearAllPoints()
    TargetFrameToT:SetPoint("TOPLEFT", TargetFrame, "BOTTOMRIGHT", -80, 22)

    -- Set a stealable texture even if you have no purge
    local function TargetFrame_UpdateAuras(self)
        for buff in self.auraPools:GetPool("TargetBuffFrameTemplate"):EnumerateActive() do
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID(buff.unit, buff.auraInstanceID);
            buff.Stealable:SetShown(data.isStealable or data.dispelName == "Magic");

            local stealableSize = buffSize + 8
            buff.Stealable:SetSize(stealableSize, stealableSize)
            buff.Stealable:SetPoint("CENTER", buff, "CENTER")
        end
    end

    hooksecurefunc(TargetFrame, "UpdateAuras", TargetFrame_UpdateAuras);
    hooksecurefunc(FocusFrame, "UpdateAuras", TargetFrame_UpdateAuras);

    -- Scale various UI frames
    EncounterBar:SetScale(0.8)
end

Perskan:RegisterEvent("PLAYER_ENTERING_WORLD")
Perskan:SetScript("OnEvent", Perskan_OnLoad)
