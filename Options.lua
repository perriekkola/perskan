local addonName = ...
Perskan = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

-- WoW Forever is a Classic-line client on interface 16xxx. Several things this addon has
-- settings for simply do not exist there - delves, the talking head frame, the cooldown
-- viewer's tracked bars, and the nameplate spell-name and name-outline pieces - so their
-- controls are hidden rather than left to do nothing. Castbar height still applies there. Detected by interface version, the
-- same 16000-20000 range AceDB-3.0 uses for its own Forever handling, because there is no
-- single API to feature-detect all of them. Retail is untouched.
local buildInterfaceVersion = select(4, GetBuildInfo())
local isForeverClient = type(buildInterfaceVersion) == "number"
    and buildInterfaceVersion > 16000
    and buildInterfaceVersion < 20000

function Perskan:IsForeverClient()
    return isForeverClient
end

local defaults = {
    profile = {
        -- Camera
        cameraYawMoveSpeed = 50,
        cameraPivot = false,
        cameraDistanceMaxZoomFactor = 2.5,
        -- Nameplates
        nameplateOtherBottomInset = 0.1,
        nameplateOtherTopInset = 0.09,
        nameplateWidth = 240,
        nameplateClickableHeight = 65,
        nameplateHealthbarHeight = 10.8,
        nameplateCastbarHeight = 0,
        nameplateCastbarNameInside = false,
        nameplateCastbarNameInset = 4,
        nameplateNameOutline = false,
        nameplateFriendlyClickThrough = false,
        -- On by default where they apply. The controls only exist on Forever, and a
        -- default that follows the client keeps a profile carried between the two doing
        -- the right thing in each: AceDB stores only what differs from the default, so
        -- an untouched setting reads false on retail and true on Forever.
        nameplateNamesRelevantOnly = isForeverClient,
        nameplateNameHostilityColor = isForeverClient,
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
        -- Delves
        delvePanelEnabled = true,
        delvePanelShown = false,
        delvePanelScale = 1,
        delvePanelWaypoints = true,
        delvePanelPoint = "CENTER",
        delvePanelRelativePoint = "CENTER",
        delvePanelX = 0,
        delvePanelY = 0,
        -- Unit Frame Auras
        targetFocusAuraSize = 20,
        -- Player Buffs
        filterPlayerBuffs = false,
        hiddenBuffs = {},
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
    -- "/pp delves" toggles the delve panel; everything else opens the settings window.
    local command = type(msg) == "string" and string.lower(strtrim and strtrim(msg) or msg) or ""

    if command == "delves" then
        if self.ToggleDelvePanel then
            self:ToggleDelvePanel()
        end
        return
    end

    -- Temporary, for the WoW Forever port; remove with the nameplate name display settled.
    if command == "nameplate" then
        if self.ReportNameplateNameDisplay then
            self:ReportNameplateNameDisplay()
        end
        return
    end

    if self.OpenConfig then
        self:OpenConfig()
    end
end
