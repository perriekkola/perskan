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
        cameraDistanceMaxZoomFactor = 2.5,
        nameplatePersonalShowAlways = 0,
        encounterBarScale = 0.8,
        highlightStealableAuras = true,
        objectiveTrackerScale = 0.95,
        reanchorDetailsWindows = true,
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
        moveMinimapUp = false,
        hideHotkeys = false,
        hideSocialButton = false,
        hideBagsBar = false
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
        spacer1 = {
            type = "description",
            name = " ",
            order = 20
        },
        header2 = {
            type = "header",
            name = "UI modifciations",
            order = 21
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
            order = 22
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
            order = 22
        },
        moveMinimapUp = {
            type = "toggle",
            name = "Move Minimap Up",
            desc = "Move the Minimap slightly upwards.",
            get = function(info)
                return Perskan.db.profile.moveMinimapUp
            end,
            set = function(info, value)
                Perskan.db.profile.moveMinimapUp = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 23
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
            order = 24
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
            order = 25
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
            order = 26
        },
        spacer2 = {
            type = "description",
            name = " ",
            order = 27
        },
        header3 = {
            type = "header",
            name = "Highlight all stealable auras",
            order = 28
        },
        highlightStealableAuras = {
            type = "toggle",
            name = "Highlight Stealable Auras",
            desc = "Toggle highlighting of stealable auras on the target frame.",
            get = function(info)
                return Perskan.db.profile.highlightStealableAuras or false
            end,
            set = function(info, value)
                Perskan.db.profile.highlightStealableAuras = value
                StaticPopup_Show("RELOAD_UI")
            end,
            order = 29
        }
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
    Settings.OpenToCategory(addonName)
end
