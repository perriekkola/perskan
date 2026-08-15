-- Target/focus frame aura icon size.
--
-- 12.0 moved unit-frame auras into engine-owned AuraContainer/AuraButton widgets.
-- The individual buff/debuff frames (and their cooldowns) live in the forbidden
-- object table now, so the old `auraPools` sweep quietly stopped doing anything and
-- the cooldown-number options that used to live in this file can't be implemented
-- at all any more - there is no public API to unhide those countdowns.
--
-- What the container does expose publicly is the aura size, which is what this
-- drives. The 11.x pool walk is kept as a fallback for clients that still have it.

-- Blizzard ships 17/21 for small/large auras; keep that 4px gap between the two so
-- important auras stay visibly bigger at any setting.
local LARGE_AURA_BONUS = 4

local function GetAuraContainer(unitFrame)
    if not unitFrame or type(unitFrame.GetAuraContainer) ~= "function" then return nil end
    local ok, container = pcall(unitFrame.GetAuraContainer, unitFrame)
    if ok then return container end
    return nil
end

local function ApplyAuraSize(unitFrame, size)
    local container = GetAuraContainer(unitFrame)
    if container and container.SetSmallAuraSize then
        -- The container is a restricted object: anything unexpected here should be a
        -- no-op rather than an error thrown into Blizzard's aura update.
        pcall(function()
            container:SetSmallAuraSize(size)
            container:SetLargeAuraSize(size + LARGE_AURA_BONUS)
        end)
        return
    end

    -- 11.x: aura frames were addon-visible and sized individually.
    if unitFrame and unitFrame.auraPools then
        for auraFrame in unitFrame.auraPools:EnumerateActive() do
            auraFrame:SetSize(size, size)
        end
    end
end

local function ApplyToTargetAndFocus()
    local size = Perskan.db.profile.targetFocusAuraSize or 20
    ApplyAuraSize(TargetFrame, size)
    ApplyAuraSize(FocusFrame, size)
end

function Perskan:ApplyTargetFocusAuraSize()
    ApplyToTargetAndFocus()
end

Perskan:RegisterModule("Auras", function(self)
    -- The container keeps the size across target changes, so these events are only
    -- insurance against a frame that wasn't created yet at login.
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    eventFrame:SetScript("OnEvent", ApplyToTargetAndFocus)

    C_Timer.After(2, ApplyToTargetAndFocus)
end)
