-- Nameplate tweaks: name outline, custom healthbar height and custom castbar height.
--
-- The hooks are installed unconditionally at login and gated internally by the
-- profile, so every setting can be changed live without a reload. Each exposes an
-- applier that re-runs over the currently visible nameplates for instant feedback.

local outlineHooked = false
local healthbarHooked = false

--------------------------------------------------------------------------------
-- Name outline
--------------------------------------------------------------------------------

local function ApplyOutlineToFontString(nameFS)
    local font, size, flags = nameFS:GetFont()
    if not font then return end

    -- Remember the flags Blizzard shipped so the outline can be cleanly removed later.
    if nameFS._perskanBaseFlags == nil then
        nameFS._perskanBaseFlags = flags or ""
    end

    if Perskan.db.profile.nameplateNameOutline then
        if not flags or not flags:find("OUTLINE") then
            nameFS._perskanChanging = true
            nameFS:SetFont(font, size, (flags and flags ~= "") and (flags .. ", OUTLINE") or "OUTLINE")
            nameFS._perskanChanging = false
        end
    else
        -- Restore the original flags if we previously added an outline.
        if flags and flags:find("OUTLINE") then
            nameFS._perskanChanging = true
            nameFS:SetFont(font, size, nameFS._perskanBaseFlags or "")
            nameFS._perskanChanging = false
        end
    end
end

local function HookNameplateName(frame)
    if not frame or not frame.name then return end

    if not frame._perskanOutlineHooked then
        frame._perskanOutlineHooked = true

        -- Blizzard calls SetFont directly on the fontstring; re-assert our choice
        -- afterwards (guarded against our own re-entrant SetFont).
        hooksecurefunc(frame.name, "SetFont", function(self)
            if self._perskanChanging then return end
            ApplyOutlineToFontString(self)
        end)
    end

    ApplyOutlineToFontString(frame.name)
end

local function ForEachNameplateFrame(fn)
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        local frame = nameplate and nameplate.UnitFrame
        if frame and not frame:IsForbidden() then
            pcall(fn, frame)
        end
    end
end

function Perskan:ApplyNameplateNameOutline()
    ForEachNameplateFrame(HookNameplateName)
end

--------------------------------------------------------------------------------
-- Healthbar height
--------------------------------------------------------------------------------

local function ApplyHealthbarHeight(nameplate)
    local frame = nameplate and nameplate.UnitFrame
    if not frame or frame:IsForbidden() then return end

    local container = frame.HealthBarsContainer
    if not container then return end

    container:SetHeight(Perskan.db.profile.nameplateHealthbarHeight or 10.8)

    -- Re-apply after Blizzard resets it (guarded against our own re-entrant SetHeight).
    if not container._perskanHeightHooked then
        container._perskanHeightHooked = true
        hooksecurefunc(container, "SetHeight", function(self)
            if self._perskanChanging then return end
            self._perskanChanging = true
            self:SetHeight(Perskan.db.profile.nameplateHealthbarHeight or 10.8)
            self._perskanChanging = false
        end)
    end
end

function Perskan:ApplyNameplateHealthbarHeight()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        pcall(ApplyHealthbarHeight, nameplate)
    end
end

--------------------------------------------------------------------------------
-- Castbar height
--------------------------------------------------------------------------------

local function ApplyCastbarHeight(nameplate)
    local frame = nameplate and nameplate.UnitFrame
    if not frame or frame:IsForbidden() then return end

    -- Blizzard's nameplate unit frame keys the castbar as `castBar`; accept the
    -- capitalised spelling too in case a future interface version renames it.
    local castBar = frame.castBar or frame.CastBar
    if not castBar then return end

    castBar:SetHeight(Perskan.db.profile.nameplateCastbarHeight or 8)

    -- Re-apply after Blizzard resets it (guarded against our own re-entrant SetHeight).
    if not castBar._perskanHeightHooked then
        castBar._perskanHeightHooked = true
        hooksecurefunc(castBar, "SetHeight", function(self)
            if self._perskanChanging then return end
            self._perskanChanging = true
            self:SetHeight(Perskan.db.profile.nameplateCastbarHeight or 8)
            self._perskanChanging = false
        end)
    end
end

function Perskan:ApplyNameplateCastbarHeight()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        pcall(ApplyCastbarHeight, nameplate)
    end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

Perskan:RegisterModule("Nameplates", function(self)
    if outlineHooked and healthbarHooked then return end
    outlineHooked = true
    healthbarHooked = true

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:SetScript("OnEvent", function(_, _, unit)
        local nameplate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
        if not nameplate then return end
        ApplyHealthbarHeight(nameplate)
        ApplyCastbarHeight(nameplate)
        local frame = nameplate.UnitFrame
        if frame and not frame:IsForbidden() then
            HookNameplateName(frame)
        end
    end)

    -- Catch nameplates that already exist at login.
    self:ApplyNameplateHealthbarHeight()
    self:ApplyNameplateCastbarHeight()
    self:ApplyNameplateNameOutline()
end)
