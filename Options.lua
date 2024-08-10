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
        encounterBarScale = 0.8,
        highlightStealableAuras = true
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
        spacer1 = {
            type = "description",
            name = " ",
            order = 8
        },
        header2 = {
            type = "header",
            name = "Encounter bar scale",
            order = 9
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
            order = 10
        },
        spacer2 = {
            type = "description",
            name = " ",
            order = 11
        },
        header3 = {
            type = "header",
            name = "Highlight all stealable auras",
            order = 12
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
            order = 13
        },
        spacer3 = {
            type = "description",
            name = " ",
            order = 14
        },
        header4 = {
            type = "header",
            name = "Amount of actionbars per specialization",
            order = 15
        },
        spacer4 = {
            type = "description",
            name = " ",
            order = 16
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
