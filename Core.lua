local addonName = "Perskan"
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

local options = {
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

local function AdjustActionBars()
    if settingsLoaded then
        local id, name, description, icon, background, role = GetSpecializationInfo(GetSpecialization())
        local numActionBars = Perskan.db.profile[name] or 3

        for i = 2, 3 do
            local actionBarSetting = "PROXY_SHOW_ACTIONBAR_" .. i
            if i <= numActionBars then
                Settings.SetValue(actionBarSetting, true)
            else
                Settings.SetValue(actionBarSetting, false)
            end
        end
    end
end

local function ScaleUIFrames()
    EncounterBar:SetScale(Perskan.db.profile.encounterBarScale or 0.8)
end

local function HighlightStealableAuras()
    local function TargetFrame_UpdateAuras(self)
        for buff in self.auraPools:GetPool("TargetBuffFrameTemplate"):EnumerateActive() do
            local buffSize = buff.GetHeight(buff)
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID(buff.unit, buff.auraInstanceID)
            buff.Stealable:SetShown(data.isStealable or data.dispelName == "Magic")
            local stealableSize = buffSize + 2
            buff.Stealable:SetSize(stealableSize, stealableSize)
            buff.Stealable:SetPoint("CENTER", buff, "CENTER")
        end
    end

    if Perskan.db.profile.highlightStealableAuras then
        hooksecurefunc(TargetFrame, "UpdateAuras", TargetFrame_UpdateAuras)
        hooksecurefunc(FocusFrame, "UpdateAuras", TargetFrame_UpdateAuras)
    end
end

function Perskan:InitializeCVars()
    SetCVar("Sound_AmbienceVolume", self.db.profile.soundAmbienceVolume)
    SetCVar("cameraYawMoveSpeed", self.db.profile.cameraYawMoveSpeed)
    SetCVar("cameraPivot", self.db.profile.cameraPivot and 1 or 0)
    SetCVar("nameplateOtherBottomInset", self.db.profile.nameplateOtherBottomInset)
    SetCVar("nameplateOtherTopInset", self.db.profile.nameplateOtherTopInset)
    SetCVar("cameraDistanceMaxZoomFactor", self.db.profile.cameraDistanceMaxZoomFactor)
end

local function CreateSpecSliders()
    local numSpecs = GetNumSpecializations()

    for i = 1, numSpecs do
        local id, name, description, icon, background, role = GetSpecializationInfo(i)
        options.args["spec" .. i] = {
            type = "range",
            name = name,
            desc = description,
            min = 1,
            max = 3,
            step = 1,
            get = function(info)
                return Perskan.db.profile[name] or 3
            end,
            set = function(info, value)
                Perskan.db.profile[name] = value
                AdjustActionBars()
            end
        }
    end
end

function Perskan:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)
    AC:RegisterOptionsTable(addonName .. "_Options", options)
    self.optionsFrame = ACD:AddToBlizOptions(addonName .. "_Options", addonName)

    local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    AC:RegisterOptionsTable(addonName .. "_Profiles", profiles)
    ACD:AddToBlizOptions(addonName .. "_Profiles", "Profiles", addonName)

    self:RegisterChatCommand(string.lower(addonName), "SlashCommand")
end

function Perskan:OnEnable()
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("SETTINGS_LOADED")
    self:RegisterEvent("PLAYER_LOGIN", "InitializeCVars")
end

function Perskan:ACTIVE_TALENT_GROUP_CHANGED()
    AdjustActionBars()
end

function Perskan:SETTINGS_LOADED()
    settingsLoaded = true
    AdjustActionBars()
    HighlightStealableAuras()
    ScaleUIFrames()
    CreateSpecSliders()
end

function Perskan:SlashCommand(msg)
    Settings.OpenToCategory(addonName)
end
