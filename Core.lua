local addonName = "Perskan"
Perskan = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local f = CreateFrame("Frame")

local settingsLoaded = false

local options = {
    name = addonName,
    handler = Perskan,
    type = "group",
    args = {
        header = {
            type = "header",
            name = "Amount of bars per specialization",
            order = 1
        },
        spacer = {
            type = "description",
            name = " ",
            order = 2
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
    CreateSpecSliders()
end

function Perskan:SlashCommand(msg)
    Settings.OpenToCategory(addonName)
end
