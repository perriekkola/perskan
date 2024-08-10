local addonName = ...

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

-- Need to create settings sliders here since we need to access AdjustActionBars function
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
