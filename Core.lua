local addonName = "Perskan"
Perskan = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local f = CreateFrame("Frame")

local settingsLoaded = false

local defaults = {
    profile = {
        message = "Welcome Home!",
        showOnScreen = true
    }
}

local options = {
    name = addonName,
    handler = Perskan,
    type = "group",
    args = {
        msg = {
            type = "input",
            name = "Message",
            desc = "The message to be displayed when you get home.",
            usage = "<Your message>",
            get = "GetMessage",
            set = "SetMessage"
        },
        showOnScreen = {
            type = "toggle",
            name = "Show on Screen",
            desc = "Toggles the display of the message on the screen.",
            get = "IsShowOnScreen",
            set = "ToggleShowOnScreen"
        }
    }
}

local function InitialSetup()
    -- Scale various UI frames
    EncounterBar:SetScale(0.8)

    -- Set a stealable texture even if you have no purge
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

    hooksecurefunc(TargetFrame, "UpdateAuras", TargetFrame_UpdateAuras)
    hooksecurefunc(FocusFrame, "UpdateAuras", TargetFrame_UpdateAuras)
end

local function AdjustActionBars()
    if settingsLoaded then
        local specsToCheck = {"Devastation", "Retribution"}

        local function isSpecInList(specName, specList)
            for _, name in ipairs(specList) do
                if name == specName then
                    return true
                end
            end
            return false
        end

        local id, name, description, icon, background, role = GetSpecializationInfo(GetSpecialization())

        if isSpecInList(name, specsToCheck) then
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_3", false)
        else
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_3", true)
        end
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
end

function Perskan:ACTIVE_TALENT_GROUP_CHANGED()
    AdjustActionBars()
end

function Perskan:SETTINGS_LOADED()
    settingsLoaded = true
    InitialSetup()
    AdjustActionBars()
end

function Perskan:SlashCommand(msg)
    Settings.OpenToCategory(addonName)
end

function Perskan:GetMessage(info)
    return self.db.profile.message
end

function Perskan:SetMessage(info, value)
    self.db.profile.message = value
end

function Perskan:IsShowOnScreen(info)
    return self.db.profile.showOnScreen
end

function Perskan:ToggleShowOnScreen(info, value)
    self.db.profile.showOnScreen = value
end
