-- Frame scaling: encounter bar, talking head, XP/status bar, extra action button.
--
-- All four apply live from the settings window. The status-bar and extra-action
-- containers get a self-correcting SetScale hook so Blizzard can't reset them; the
-- waiter frame that installs it unregisters once done (the old code left it firing
-- on every zone and addon load forever).

local hookedManagers = {}

-- Installs a persistent, self-correcting scale on a container once it exists, then
-- stops listening. `getScale` is read live so the hook always tracks the current value.
local function InstallScaledContainer(globalName, getScale)
    if hookedManagers[globalName] then return end

    local function TryHook(self)
        local frame = _G[globalName]
        if not frame then return false end

        frame:SetScale(getScale())

        if not hookedManagers[globalName] then
            hookedManagers[globalName] = true
            hooksecurefunc(frame, "SetScale", function(f, scale)
                local wanted = getScale()
                if scale ~= wanted then
                    f:SetScale(wanted)
                end
            end)
        end
        return true
    end

    if TryHook() then return end

    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_ENTERING_WORLD")
    waiter:RegisterEvent("PLAYER_LOGIN")
    waiter:RegisterEvent("ADDON_LOADED")
    waiter:SetScript("OnEvent", function(self)
        if TryHook() then
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end
    end)
end

--------------------------------------------------------------------------------
-- Appliers (called live from the settings window)
--------------------------------------------------------------------------------

function Perskan:ApplyEncounterBarScale()
    if EncounterBar then
        EncounterBar:SetScale(self.db.profile.encounterBarScale or 1)
    end
end

function Perskan:ApplyXpBarScale()
    if StatusTrackingBarManager then
        StatusTrackingBarManager:SetScale(self.db.profile.xpBarScale or 1)
    end
end

function Perskan:ApplyExtraActionButtonScale()
    if ExtraAbilityContainer then
        ExtraAbilityContainer:SetScale(self.db.profile.extraActionButtonScale or 1)
    end
end

function Perskan:ApplyTalkingHeadScale()
    if TalkingHeadFrame then
        TalkingHeadFrame:SetScale(self.db.profile.talkingHeadScale or 1)
    end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

Perskan:RegisterModule("FrameScaling", function(self)
    self:ApplyEncounterBarScale()

    -- StatusTrackingBarManager and ExtraAbilityContainer persist their scale via hook.
    InstallScaledContainer("StatusTrackingBarManager", function()
        return Perskan.db.profile.xpBarScale or 1
    end)
    InstallScaledContainer("ExtraAbilityContainer", function()
        return Perskan.db.profile.extraActionButtonScale or 1
    end)

    -- TalkingHeadFrame lives in a load-on-demand addon; hook PlayCurrent so the scale
    -- is (re)applied each time a talking head plays.
    local function HookTalkingHead()
        if not TalkingHeadFrame or TalkingHeadFrame._perskanHooked then return end
        TalkingHeadFrame._perskanHooked = true
        hooksecurefunc(TalkingHeadFrame, "PlayCurrent", function()
            TalkingHeadFrame:SetScale(Perskan.db.profile.talkingHeadScale or 1)
        end)
    end

    if TalkingHeadFrame then
        HookTalkingHead()
    else
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("ADDON_LOADED")
        waiter:SetScript("OnEvent", function(frameSelf, _, loaded)
            if loaded == "Blizzard_TalkingHeadUI" or TalkingHeadFrame then
                HookTalkingHead()
                if TalkingHeadFrame then
                    frameSelf:UnregisterEvent("ADDON_LOADED")
                end
            end
        end)
    end
end)
