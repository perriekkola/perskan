local addonName = ...
Perskan = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")

local defaults = {
    profile = {
        soundAmbienceVolume = 0.1,
        cameraYawMoveSpeed = 90,
        cameraPivot = false,
        nameplateOtherBottomInset = 0.1,
        nameplateOtherTopInset = 0.09,
        nameplateWidth = 240,
        cameraDistanceMaxZoomFactor = 2.5,
        nameplatePersonalShowAlways = 0,
        encounterBarScale = 1,
        talkingHeadScale = 1,
        xpBarScale = 1,
        extraActionButtonScale = 1,
        reanchorDetailsWindows = true,
        addChatSizes = true,
        autoLootDefault = 1,
        alwaysShowNameplates = 1,
        nameplateShowAll = 1,
        nameplateShowEnemies = 1,
        nameplateShowEnemyMinions = 1,
        nameplateShowFriendlyMinions = 1,
        raidFramesDisplayAggroHighlight = 0,
        raidFramesDisplayClassColor = 1,
        raidOptionDisplayMainTankAndAssist = 0,
        pvpFramesDisplayClassColor = 1,
        nameplateShowSelf = 1,
        nameplateHideHealthAndPower = 1,
        hideHotkeys = false,
        hideMacroText = false,
        showAuraCooldownNumbers = false,
        auraCooldownNumbersScale = 0.75,
        targetFocusAuraSize = 20,
        hideSocialButton = false,
        hideBagsBar = false,
        sortBuffBarsUpward = true,
        anchorBuffBarsToWidgetFrame = true,
        anchorExtraQuestButton = false,
        damageMeterWidth = 200,
        damageMeterHeight = 200,
        damageMeterScale = 1.0,
        damageMeterAnchorToMicroMenu = false,
        showRaidFrameAuraCooldowns = false,
        raidFrameAuraCooldownScale = 0.75,
    }
}

StaticPopupDialogs["RELOAD_UI"] = {
    text = "Changes to this setting require a UI reload. Do you want to reload the UI now?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- Debounced reload popup for sliders (waits until user stops dragging)
local reloadTimer = nil
local function ShowReloadUIDebounced()
    if reloadTimer then
        reloadTimer:Cancel()
    end
    reloadTimer = C_Timer.NewTimer(0.5, function()
        StaticPopup_Show("RELOAD_UI")
        reloadTimer = nil
    end)
end

options = {
    name = addonName,
    handler = Perskan,
    type = "group",
    args = {
        header1 = {
            type = "header",
            name = "CVars",
            order = 1
        },
        soundAmbienceVolume = {
            type = "range",
            name = "Sound Ambience Volume",
            desc = "Adjust the sound ambience volume.",
            min = 0,
            max = 1,
            step = 0.1,
            get = function(info)
                return Perskan.db.profile.soundAmbienceVolume
            end,
            set = function(info, value)
                Perskan.db.profile.soundAmbienceVolume = value
                SetCVar("Sound_AmbienceVolume", value)
            end,
            order = 2
        },
        cameraYawMoveSpeed = {
            type = "range",
            name = "Camera Yaw Move Speed",
            desc = "Adjust the camera yaw move speed.",
            min = 0,
            max = 100,
            step = 1,
            get = function(info)
                return Perskan.db.profile.cameraYawMoveSpeed
            end,
            set = function(info, value)
                Perskan.db.profile.cameraYawMoveSpeed = value
                SetCVar("cameraYawMoveSpeed", value)
            end,
            order = 3
        },
        cameraPivot = {
            type = "toggle",
            name = "Camera Pivot",
            desc = "Toggle the camera pivot.",
            get = function(info)
                return Perskan.db.profile.cameraPivot
            end,
            set = function(info, value)
                Perskan.db.profile.cameraPivot = value
                SetCVar("cameraPivot", value and 1 or 0)
            end,
            order = 4
        },
        nameplateOtherBottomInset = {
            type = "range",
            name = "Nameplate Other Bottom Inset",
            desc = "Adjust the nameplate other bottom inset.",
            min = -1,
            max = 1,
            step = 0.01,
            get = function(info)
                return Perskan.db.profile.nameplateOtherBottomInset
            end,
            set = function(info, value)
                Perskan.db.profile.nameplateOtherBottomInset = value
                SetCVar("nameplateOtherBottomInset", value)
            end,
            order = 5
        },
        nameplateOtherTopInset = {
            type = "range",
            name = "Nameplate Other Top Inset",
            desc = "Adjust the nameplate other top inset.",
            min = -1,
            max = 1,
            step = 0.01,
            get = function(info)
                return Perskan.db.profile.nameplateOtherTopInset
            end,
            set = function(info, value)
                Perskan.db.profile.nameplateOtherTopInset = value
                SetCVar("nameplateOtherTopInset", value)
            end,
            order = 6
        },
        nameplateWidth = {
            type = "range",
            name = "Nameplate Width",
            desc = "Adjust the width of nameplates.",
            min = 120,
            max = 400,
            step = 5,
            get = function(info)
                return Perskan.db.profile.nameplateWidth
            end,
            set = function(info, value)
                Perskan.db.profile.nameplateWidth = value
                if not InCombatLockdown() then
                    C_NamePlate.SetNamePlateSize(value, 45)
                end
            end,
            order = 7
        },
        cameraDistanceMaxZoomFactor = {
            type = "range",
            name = "Camera Distance Max Zoom Factor",
            desc = "Adjust the camera distance max zoom factor.",
            min = 1,
            max = 2.5,
            step = 0.1,
            get = function(info)
                return Perskan.db.profile.cameraDistanceMaxZoomFactor
            end,
            set = function(info, value)
                Perskan.db.profile.cameraDistanceMaxZoomFactor = value
                SetCVar("cameraDistanceMaxZoomFactor", value)
            end,
            order = 7
        },
        addChatSizes = {
            type = "toggle",
            name = "Add Chat Sizes",
            desc = "Toggle adding chat sizes.",
            get = function(info)
                return Perskan.db.profile.addChatSizes
            end,
            set = function(info, value)
                Perskan.db.profile.addChatSizes = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 8
        },
        autoLootDefault = {
            type = "toggle",
            name = "Auto Loot Default",
            desc = "Toggle auto loot default.",
            get = function(info)
                return Perskan.db.profile.autoLootDefault == 1
            end,
            set = function(info, value)
                Perskan.db.profile.autoLootDefault = value and 1 or 0
                SetCVar("autoLootDefault", value and 1 or 0)
            end,
            order = 8
        },
        alwaysShowNameplates = {
            type = "toggle",
            name = "Always Show Nameplates",
            desc = "Toggle always show nameplates.",
            get = function(info)
                return Perskan.db.profile.alwaysShowNameplates == 1
            end,
            set = function(info, value)
                Perskan.db.profile.alwaysShowNameplates = value and 1 or 0
                SetCVar("alwaysShowNameplates", value and 1 or 0)
            end,
            order = 9
        },
        nameplateShowAll = {
            type = "toggle",
            name = "Nameplate Show All",
            desc = "Toggle nameplate show all.",
            get = function(info)
                return Perskan.db.profile.nameplateShowAll == 1
            end,
            set = function(info, value)
                Perskan.db.profile.nameplateShowAll = value and 1 or 0
                SetCVar("nameplateShowAll", value and 1 or 0)
            end,
            order = 10
        },
        nameplateShowEnemies = {
            type = "toggle",
            name = "Nameplate Show Enemies",
            desc = "Toggle nameplate show enemies.",
            get = function(info)
                return Perskan.db.profile.nameplateShowEnemies == 1
            end,
            set = function(info, value)
                Perskan.db.profile.nameplateShowEnemies = value and 1 or 0
                SetCVar("nameplateShowEnemies", value and 1 or 0)
            end,
            order = 11
        },
        nameplateShowEnemyMinions = {
            type = "toggle",
            name = "Nameplate Show Enemy Minions",
            desc = "Toggle nameplate show enemy minions.",
            get = function(info)
                return Perskan.db.profile.nameplateShowEnemyMinions == 1
            end,
            set = function(info, value)
                Perskan.db.profile.nameplateShowEnemyMinions = value and 1 or 0
                SetCVar("nameplateShowEnemyMinions", value and 1 or 0)
            end,
            order = 12
        },
        nameplateShowFriendlyMinions = {
            type = "toggle",
            name = "Nameplate Show Friendly Minions",
            desc = "Toggle nameplate show friendly minions.",
            get = function(info)
                return Perskan.db.profile.nameplateShowFriendlyMinions == 1
            end,
            set = function(info, value)
                Perskan.db.profile.nameplateShowFriendlyMinions = value and 1 or 0
                SetCVar("nameplateShowFriendlyMinions", value and 1 or 0)
            end,
            order = 13
        },
        raidFramesDisplayAggroHighlight = {
            type = "toggle",
            name = "Raid Frames Display Aggro Highlight",
            desc = "Toggle raid frames display aggro highlight.",
            get = function(info)
                return Perskan.db.profile.raidFramesDisplayAggroHighlight == 1
            end,
            set = function(info, value)
                Perskan.db.profile.raidFramesDisplayAggroHighlight = value and 1 or 0
                SetCVar("raidFramesDisplayAggroHighlight", value and 1 or 0)
            end,
            order = 14
        },
        raidFramesDisplayClassColor = {
            type = "toggle",
            name = "Raid Frames Display Class Color",
            desc = "Toggle raid frames display class color.",
            get = function(info)
                return Perskan.db.profile.raidFramesDisplayClassColor == 1
            end,
            set = function(info, value)
                Perskan.db.profile.raidFramesDisplayClassColor = value and 1 or 0
                SetCVar("raidFramesDisplayClassColor", value and 1 or 0)
            end,
            order = 15
        },
        raidOptionDisplayMainTankAndAssist = {
            type = "toggle",
            name = "Raid Option Display Main Tank And Assist",
            desc = "Toggle raid option display main tank and assist.",
            get = function(info)
                return Perskan.db.profile.raidOptionDisplayMainTankAndAssist == 1
            end,
            set = function(info, value)
                Perskan.db.profile.raidOptionDisplayMainTankAndAssist = value and 1 or 0
                SetCVar("raidOptionDisplayMainTankAndAssist", value and 1 or 0)
            end,
            order = 16
        },
        pvpFramesDisplayClassColor = {
            type = "toggle",
            name = "PvP Frames Display Class Color",
            desc = "Toggle PvP frames display class color.",
            get = function(info)
                return Perskan.db.profile.pvpFramesDisplayClassColor == 1
            end,
            set = function(info, value)
                Perskan.db.profile.pvpFramesDisplayClassColor = value and 1 or 0
                SetCVar("pvpFramesDisplayClassColor", value and 1 or 0)
            end,
            order = 17
        },
        nameplateShowSelf = {
            type = "toggle",
            name = "Personal Resource Display",
            desc = "Toggle the personal resource display.",
            get = function(info)
                return Perskan.db.profile.nameplateShowSelf == 1
            end,
            set = function(info, value)
                Perskan.db.profile.nameplateShowSelf = value and 1 or 0
                SetCVar("nameplateShowSelf", value and 1 or 0)
            end,
            order = 18
        },
        nameplateHideHealthAndPower = {
            type = "toggle",
            name = "Hide Health and Power",
            desc = "Toggle hiding health and power on nameplates.",
            get = function(info)
                return Perskan.db.profile.nameplateHideHealthAndPower == 1
            end,
            set = function(info, value)
                Perskan.db.profile.nameplateHideHealthAndPower = value and 1 or 0
                SetCVar("nameplateHideHealthAndPower", value and 1 or 0)
            end,
            order = 19
        },
        nameplatePersonalShowAlways = {
            type = "toggle",
            name = "Nameplate Personal Show Always",
            desc = "Toggle nameplate personal show always.",
            get = function(info)
                return Perskan.db.profile.nameplatePersonalShowAlways == 1
            end,
            set = function(info, value)
                Perskan.db.profile.nameplatePersonalShowAlways = value and 1 or 0
                SetCVar("NameplatePersonalShowAlways", value and 1 or 0)
            end,
            order = 19
        },
        -- Frame Scaling
        spacer1 = {
            type = "description",
            name = " ",
            order = 100
        },
        headerFrameScaling = {
            type = "header",
            name = "Frame Scaling",
            order = 101
        },
        encounterBarScale = {
            type = "range",
            name = "Encounter Bar Scale",
            desc = "Adjust the scale of the encounter bar.",
            min = 0.5,
            max = 2.0,
            step = 0.1,
            get = function(info)
                return Perskan.db.profile.encounterBarScale or 0.8
            end,
            set = function(info, value)
                Perskan.db.profile.encounterBarScale = value
                EncounterBar:SetScale(value)
            end,
            order = 102
        },
        talkingHeadScale = {
            type = "range",
            name = "Talking Head Scale",
            desc = "Adjust the scale of the talking head.",
            min = 0.5,
            max = 2.0,
            step = 0.1,
            get = function(info)
                return Perskan.db.profile.talkingHeadScale or 0.8
            end,
            set = function(info, value)
                Perskan.db.profile.talkingHeadScale = value
            end,
            order = 103
        },
        xpBarScale = {
            type = "range",
            name = "XP Bar Scale",
            desc = "Adjust the scale of the XP bar.",
            min = 0.5,
            max = 2.0,
            step = 0.1,
            get = function(info)
                return Perskan.db.profile.xpBarScale or 0.8
            end,
            set = function(info, value)
                Perskan.db.profile.xpBarScale = value
                ShowReloadUIDebounced()
            end,
            order = 104
        },
        extraActionButtonScale = {
            type = "range",
            name = "Extra Action Button Scale",
            desc = "Adjust the scale of the extra action button.",
            min = 0.5,
            max = 2.0,
            step = 0.1,
            get = function(info)
                return Perskan.db.profile.extraActionButtonScale or 0.8
            end,
            set = function(info, value)
                Perskan.db.profile.extraActionButtonScale = value
                ShowReloadUIDebounced()
            end,
            order = 105
        },

        -- Action Bars
        spacer2 = {
            type = "description",
            name = " ",
            order = 200
        },
        headerActionBars = {
            type = "header",
            name = "Action Bars",
            order = 201
        },
        hideHotkeys = {
            type = "toggle",
            name = "Hide Hotkeys",
            desc = "Hide hotkeys on action buttons.",
            get = function(info)
                return Perskan.db.profile.hideHotkeys
            end,
            set = function(info, value)
                Perskan.db.profile.hideHotkeys = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 202
        },
        hideMacroText = {
            type = "toggle",
            name = "Hide Macro Text",
            desc = "Hide macro names on action buttons.",
            get = function(info)
                return Perskan.db.profile.hideMacroText
            end,
            set = function(info, value)
                Perskan.db.profile.hideMacroText = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 203
        },

        -- Unit Frame Auras
        spacer3 = {
            type = "description",
            name = " ",
            order = 300
        },
        headerUnitFrameAuras = {
            type = "header",
            name = "Unit Frame Auras",
            order = 301
        },
        targetFocusAuraSize = {
            type = "range",
            name = "Target/Focus Aura Size",
            desc = "Adjust the size of buff and debuff icons on target and focus frames.",
            min = 10,
            max = 40,
            step = 1,
            get = function(info)
                return Perskan.db.profile.targetFocusAuraSize or 20
            end,
            set = function(info, value)
                Perskan.db.profile.targetFocusAuraSize = value
                ShowReloadUIDebounced()
            end,
            order = 302
        },
        showAuraCooldownNumbers = {
            type = "toggle",
            name = "Show Aura Cooldown Numbers",
            desc = "Force show cooldown numbers on buff/debuff icons on unit frames.",
            get = function(info)
                return Perskan.db.profile.showAuraCooldownNumbers
            end,
            set = function(info, value)
                Perskan.db.profile.showAuraCooldownNumbers = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 304
        },
        auraCooldownNumbersScale = {
            type = "range",
            name = "Aura Cooldown Numbers Scale",
            desc = "Adjust the size of cooldown numbers on buff/debuff icons.",
            min = 0.3,
            max = 1.5,
            step = 0.1,
            get = function(info)
                return Perskan.db.profile.auraCooldownNumbersScale or 0.75
            end,
            set = function(info, value)
                Perskan.db.profile.auraCooldownNumbersScale = value
                ShowReloadUIDebounced()
            end,
            disabled = function()
                return not Perskan.db.profile.showAuraCooldownNumbers
            end,
            order = 305
        },
        showRaidFrameAuraCooldowns = {
            type = "toggle",
            name = "Show Raid Frame Aura Cooldowns",
            desc = "Show cooldown numbers on buff/debuff icons on raid frames.",
            get = function(info)
                return Perskan.db.profile.showRaidFrameAuraCooldowns
            end,
            set = function(info, value)
                Perskan.db.profile.showRaidFrameAuraCooldowns = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 306
        },
        raidFrameAuraCooldownScale = {
            type = "range",
            name = "Raid Frame Aura Cooldown Scale",
            desc = "Adjust the size of cooldown numbers on raid frame buff/debuff icons.",
            min = 0.3,
            max = 1.5,
            step = 0.1,
            get = function(info)
                return Perskan.db.profile.raidFrameAuraCooldownScale or 0.75
            end,
            set = function(info, value)
                Perskan.db.profile.raidFrameAuraCooldownScale = value
                ShowReloadUIDebounced()
            end,
            disabled = function()
                return not Perskan.db.profile.showRaidFrameAuraCooldowns
            end,
            order = 307
        },

        -- Hide UI Elements
        spacer4 = {
            type = "description",
            name = " ",
            order = 400
        },
        headerHideElements = {
            type = "header",
            name = "Hide UI Elements",
            order = 401
        },
        hideSocialButton = {
            type = "toggle",
            name = "Hide Social Button",
            desc = "Hide the social button.",
            get = function(info)
                return Perskan.db.profile.hideSocialButton
            end,
            set = function(info, value)
                Perskan.db.profile.hideSocialButton = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 402
        },
        hideBagsBar = {
            type = "toggle",
            name = "Hide Bags Bar",
            desc = "Hide the bags bar.",
            get = function(info)
                return Perskan.db.profile.hideBagsBar
            end,
            set = function(info, value)
                Perskan.db.profile.hideBagsBar = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 403
        },

        -- BuffBarCooldownViewer
        spacer5 = {
            type = "description",
            name = " ",
            order = 500
        },
        headerBuffBar = {
            type = "header",
            name = "Tracked Bars",
            order = 501
        },
        anchorBuffBarsToWidgetFrame = {
            type = "toggle",
            name = "Anchor to Cast Bar",
            desc = "Anchor BuffBarCooldownViewer above the cast bar. If Extra Quest Button anchoring is also enabled, buff bars will stack above it.",
            get = function(info)
                return Perskan.db.profile.anchorBuffBarsToWidgetFrame
            end,
            set = function(info, value)
                Perskan.db.profile.anchorBuffBarsToWidgetFrame = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 502
        },
        sortBuffBarsUpward = {
            type = "toggle",
            name = "Sort Bars Upward",
            desc = "Stack BuffBarCooldownViewer bars upward without gaps when cooldowns are inactive.",
            get = function(info)
                return Perskan.db.profile.sortBuffBarsUpward
            end,
            set = function(info, value)
                Perskan.db.profile.sortBuffBarsUpward = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 503
        },
        -- Extra Quest Button (only shown if addon is loaded)
        spacer6 = {
            type = "description",
            name = " ",
            order = 550,
            hidden = function()
                return not C_AddOns.IsAddOnLoaded("ExtraQuestButton")
            end
        },
        headerExtraQuestButton = {
            type = "header",
            name = "Extra Quest Button",
            order = 551,
            hidden = function()
                return not C_AddOns.IsAddOnLoaded("ExtraQuestButton")
            end
        },
        anchorExtraQuestButton = {
            type = "toggle",
            name = "Anchor Above Cast Bar",
            desc = "Anchor ExtraQuestButton above the cast bar (between cast bar and buff bars).",
            get = function(info)
                return Perskan.db.profile.anchorExtraQuestButton
            end,
            set = function(info, value)
                Perskan.db.profile.anchorExtraQuestButton = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 552,
            hidden = function()
                return not C_AddOns.IsAddOnLoaded("ExtraQuestButton")
            end
        },

        -- Damage Meter
        spacer7 = {
            type = "description",
            name = " ",
            order = 600
        },
        headerDamageMeter = {
            type = "header",
            name = "Damage Meter",
            order = 601
        },
        damageMeterWidth = {
            type = "range",
            name = "Width",
            desc = "Set the width of all DamageMeter session windows.",
            min = 100,
            max = 400,
            step = 5,
            get = function(info)
                return Perskan.db.profile.damageMeterWidth
            end,
            set = function(info, value)
                Perskan.db.profile.damageMeterWidth = value
                if Perskan.ApplyDamageMeterSettings then
                    Perskan.ApplyDamageMeterSettings()
                end
            end,
            order = 602
        },
        damageMeterHeight = {
            type = "range",
            name = "Height",
            desc = "Set the height of all DamageMeter session windows.",
            min = 50,
            max = 500,
            step = 5,
            get = function(info)
                return Perskan.db.profile.damageMeterHeight
            end,
            set = function(info, value)
                Perskan.db.profile.damageMeterHeight = value
                if Perskan.ApplyDamageMeterSettings then
                    Perskan.ApplyDamageMeterSettings()
                end
            end,
            order = 603
        },
        damageMeterScale = {
            type = "range",
            name = "Scale",
            desc = "Set the scale of all DamageMeter session windows.",
            min = 0.5,
            max = 2.0,
            step = 0.05,
            get = function(info)
                return Perskan.db.profile.damageMeterScale
            end,
            set = function(info, value)
                Perskan.db.profile.damageMeterScale = value
                if Perskan.ApplyDamageMeterSettings then
                    Perskan.ApplyDamageMeterSettings()
                end
            end,
            order = 604
        },
        damageMeterAnchorToMicroMenu = {
            type = "toggle",
            name = "Anchor to Micro Menu",
            desc = "Anchor DamageMeter windows to the top right of the Micro Menu. Secondary windows anchor to the left of the primary.",
            get = function(info)
                return Perskan.db.profile.damageMeterAnchorToMicroMenu
            end,
            set = function(info, value)
                Perskan.db.profile.damageMeterAnchorToMicroMenu = value
                if Perskan.ApplyDamageMeterSettings then
                    Perskan.ApplyDamageMeterSettings()
                end
            end,
            order = 605
        },

    }
}

function Perskan:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)
    AC:RegisterOptionsTable(addonName .. "_Options", options)
    self.optionsFrame = ACD:AddToBlizOptions(addonName .. "_Options", addonName)

    local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    AC:RegisterOptionsTable(addonName .. "_Profiles", profiles)
    ACD:AddToBlizOptions(addonName .. "_Profiles", "Profiles", addonName)

    self:RegisterChatCommand(string.lower(addonName), "SlashCommand")
end

function Perskan:SlashCommand(msg)
    -- Open AceConfigDialog directly instead of using Settings API
    ACD:Open(addonName .. "_Options")
end
