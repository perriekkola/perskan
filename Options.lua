local addonName = ...
Perskan = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local defaults = {
    profile = {
        -- Camera
        cameraYawMoveSpeed = 90,
        cameraPivot = false,
        cameraDistanceMaxZoomFactor = 2.5,
        -- Nameplates
        nameplateOtherBottomInset = 0.1,
        nameplateOtherTopInset = 0.09,
        nameplateWidth = 240,
        nameplateClickableHeight = 65,
        nameplateHealthbarHeight = 10.8,
        nameplateCastbarHeight = 0,
        nameplateNameOutline = false,
        alwaysShowNameplates = 1,
        nameplateShowAll = 1,
        nameplateShowEnemies = 1,
        nameplateShowEnemyMinions = 1,
        nameplateShowFriendlyMinions = 1,
        -- Personal Resource Display
        nameplateShowSelf = 1,
        -- Raid Frames
        raidFramesDisplayAggroHighlight = 0,
        raidFramesDisplayClassColor = 1,
        raidOptionDisplayMainTankAndAssist = 0,
        pvpFramesDisplayClassColor = 1,
        -- Misc
        soundAmbienceVolume = 0.1,
        autoLootDefault = 1,
        addChatSizes = true,
        enableDamageMeter = 1,
        -- Frame Scaling
        encounterBarScale = 1,
        talkingHeadScale = 1,
        xpBarScale = 1,
        extraActionButtonScale = 1,
        -- Action Bars
        hideHotkeys = false,
        hideMacroText = false,
        greyOnCooldown = true,
        greyOnCooldownUnusable = true,
        greyOnCooldownNoResources = false,
        greyOnCooldownPetBar = true,
        rangeColoring = true,
        rangeColoringHotkeys = true,
        rangeColoringPetBar = true,
        -- Chat
        chatCopyButton = true,
        chatCopyMaxLines = 500,
        chatDisableFade = false,
        chatUrlLinks = true,
        chatUrlColor = { r = 0, g = 0.678, b = 1 },
        -- Key Bindings
        bindPadEnabled = true,
        -- World Map
        showDelvesOnContinentMap = true,
        delvesBountifulOnly = false,
        -- Unit Frame Auras
        targetFocusAuraSize = 20,
        -- Hide UI Elements
        hideSocialButton = false,
        hideBagsBar = false,
        -- Tracked Bars
        anchorBuffBarsToWidgetFrame = true,
        anchorExtraQuestButton = false,
        -- Damage Meter
        enableDamageMeterCustomization = false,
        damageMeterWidth = 200,
        damageMeterHeight = 200,
        damageMeterScale = 1.0,
        damageMeterHeights = {},
        damageMeterSpacing = 0,
        damageMeterAnchorEnabled = false,
        damageMeterAnchorPoint = "BOTTOMRIGHT",
        damageMeterAnchorXOffset = 0,
        damageMeterAnchorYOffset = 0,
        damageMeterMultiWindowAnchor = "left",
    }
}

Perskan.defaults = defaults

-- Lightweight module registry.
--
-- Each feature file registers a setup function here instead of Core.lua calling
-- everything by hand. OnEnable (Core.lua) iterates the registry, isolating each
-- module in a pcall so one broken feature can't abort the rest - the failure mode
-- the old defensive `if EncounterBar` guards were bolted on to survive.
--
-- optionalKey: when set, the module's setup only runs if profile[optionalKey] is
-- truthy at login. Modules that support live toggling leave this nil and gate
-- their own hooks internally, so a setting can be flipped without a reload.
Perskan.modules = {}

function Perskan:RegisterModule(name, setupFn, optionalKey)
    self.modules[#self.modules + 1] = { name = name, setup = setupFn, key = optionalKey }
end

-- Carry settings from renamed keys over to their replacements, once per profile.
-- Dropped keys (the aura cooldown-number options that 12.0's private aura system made
-- impossible) are simply left in the saved table; AceDB ignores what isn't in defaults.
local function MigrateProfile(profile)
    -- The damage meter's bottom-right-only anchor became a free anchor point.
    if profile.damageMeterAnchorBottomRight ~= nil then
        profile.damageMeterAnchorEnabled = profile.damageMeterAnchorBottomRight and true or false
        profile.damageMeterAnchorPoint = "BOTTOMRIGHT"
        profile.damageMeterAnchorBottomRight = nil
    end
end

function Perskan:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)
    MigrateProfile(self.db.profile)

    -- On a profile switch/copy/reset: re-apply live settings to the game and refresh
    -- the config window's controls so both reflect the new values immediately.
    local function OnProfileEvent()
        MigrateProfile(self.db.profile)
        if self.ApplyProfileSettings then
            self:ApplyProfileSettings()
        end
        if self.RefreshConfig then
            self:RefreshConfig()
        end
    end
    self.db.RegisterCallback(self, "OnProfileChanged", OnProfileEvent)
    self.db.RegisterCallback(self, "OnProfileCopied", OnProfileEvent)
    self.db.RegisterCallback(self, "OnProfileReset", OnProfileEvent)

    -- Build the standalone settings window (Config/Window.lua).
    if self.BuildConfig then
        self:BuildConfig()
    end

    self:RegisterChatCommand(string.lower(addonName), "SlashCommand")
    self:RegisterChatCommand("pp", "SlashCommand")
end

function Perskan:SlashCommand(msg)
    if self.OpenConfig then
        self:OpenConfig()
    end
end
