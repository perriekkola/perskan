local Perskan = CreateFrame("Frame")

local function Perskan_OnLoad()
    -- Scale various UI frames
    EncounterBar:SetScale(0.8)

    -- Scale nameplate debuffs
    local function MoveDebuffs(self)
        if self.BuffFrame then
            self.BuffFrame:SetScale(1.1)
        end
    end
    hooksecurefunc("CompactUnitFrame_OnLoad", MoveDebuffs)
end

Perskan:RegisterEvent("PLAYER_ENTERING_WORLD")
Perskan:SetScript("OnEvent", Perskan_OnLoad)
