-- Frame scaling: encounter bar, talking head, XP/status bar, extra action button, and -
-- on WoW Forever only - an explicit XP bar width.
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

-- Runs fn once the named global exists, then stops listening.
local function WhenFrameExists(globalName, fn)
    if _G[globalName] then
        fn()
        return
    end

    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_ENTERING_WORLD")
    waiter:RegisterEvent("ADDON_LOADED")
    waiter:SetScript("OnEvent", function(self)
        if _G[globalName] then
            fn()
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end
    end)
end

-- Width is not the manager's to give: the scale option drives StatusTrackingBarManager,
-- but the frame that actually draws the bar - and the one whose width means anything -
-- is MainStatusTrackingBarContainer. The manager is only a fallback for a client that
-- doesn't carry the container.
local function XpBarWidthFrame()
    return _G.MainStatusTrackingBarContainer or _G.StatusTrackingBarManager
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

-- What Blizzard would size the container to on its own: the manager's expected width,
-- scaled by Edit Mode's Size percentage when the layout carries one
-- (EditModeStatusTrackingBarSystemMixin:UpdateSystemSetting does the same sum).
local function BlizzardXpBarWidth(frame)
    local manager = _G.StatusTrackingBarManager
    if not (manager and manager.GetExpectedWidth) then return nil end

    local ok, width = pcall(manager.GetExpectedWidth, manager)
    if not ok or type(width) ~= "number" then return nil end

    local sizeSetting = Enum and Enum.EditModeStatusTrackingBarSetting
        and Enum.EditModeStatusTrackingBarSetting.Size
    if sizeSetting and frame.HasSetting and frame.GetSettingValue then
        local okHas, has = pcall(frame.HasSetting, frame, sizeSetting)
        if okHas and has then
            local okValue, percent = pcall(frame.GetSettingValue, frame, sizeSetting)
            if okValue and type(percent) == "number" and percent > 0 then
                width = width * percent / 100
            end
        end
    end
    return width
end

-- Resizing the container moves only its frame art and divider ticks. The fill bars
-- inside keep the width they were last laid out at until the manager's
-- CheckForLayoutChange - the same call Edit Mode makes after its own resize - sizes them
-- again off the container. The rested tick is placed against the bar's width, so it
-- goes after.
local function RelayoutXpBar()
    local manager = _G.StatusTrackingBarManager
    if not manager then return end
    if type(manager.CheckForLayoutChange) == "function" then
        pcall(manager.CheckForLayoutChange, manager)
    end
    if type(manager.UpdateBarTicks) == "function" then
        pcall(manager.UpdateBarTicks, manager)
    end
end

-- 0 means leave Blizzard's own width alone, the same way a castbar height of 0 does on
-- nameplates. Anything else is held against Blizzard's resizes - Edit Mode uses SetSize,
-- not SetWidth, on login, layout changes and its Size slider - by hooks on both. The
-- hooks only flag the change: the correction runs on the next frame from our own
-- frame, so none of it happens inside Edit Mode's execution, and it lands after
-- whatever layout pass Blizzard runs straight after its resize.
local applyingXpBarWidth = false
local xpBarWidthTouched = false
local xpBarWidthDriver

local function XpBarWidthDriver()
    if not xpBarWidthDriver then
        xpBarWidthDriver = CreateFrame("Frame")
        xpBarWidthDriver:Hide()
        xpBarWidthDriver:SetScript("OnUpdate", function(self)
            self:Hide()
            Perskan:ApplyXpBarWidth()
        end)
        xpBarWidthDriver:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            Perskan:ApplyXpBarWidth()
        end)
    end
    return xpBarWidthDriver
end

-- Next frame, from our own frame.
local function QueueXpBarWidth()
    XpBarWidthDriver():Show()
end

function Perskan:ApplyXpBarWidth()
    -- The relayout below sizes frames of its own; nothing it does should loop back here.
    if applyingXpBarWidth then return end

    local frame = XpBarWidthFrame()
    if not frame then return end

    local width = self.db.profile.xpBarWidth or 0
    local wanted
    if width > 0 then
        wanted = width
    elseif xpBarWidthTouched then
        -- Back to 0 after we held a width: hand it back to Blizzard's own, once.
        wanted = BlizzardXpBarWidth(frame)
    else
        return
    end
    if not wanted or wanted <= 0 then return end

    -- Edit Mode lays the bottom bars out against this container; leave it be in combat
    -- if anything protected depends on it, and catch up afterwards.
    if InCombatLockdown() and frame:IsProtected() then
        XpBarWidthDriver():RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    applyingXpBarWidth = true
    if math.abs(frame:GetWidth() - wanted) > 0.5 then
        frame:SetWidth(wanted)
    end
    RelayoutXpBar()
    applyingXpBarWidth = false

    xpBarWidthTouched = width > 0

    if not frame._perskanWidthHooked then
        frame._perskanWidthHooked = true
        local function OnResized()
            if applyingXpBarWidth then return end
            if (Perskan.db.profile.xpBarWidth or 0) > 0 then
                QueueXpBarWidth()
            end
        end
        hooksecurefunc(frame, "SetWidth", OnResized)
        hooksecurefunc(frame, "SetSize", OnResized)
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

    WhenFrameExists("MainStatusTrackingBarContainer", function()
        Perskan:ApplyXpBarWidth()
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
