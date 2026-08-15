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

-- Retail 12.x nests the cast bar as UnitFrame.CastBarsContainer.castBar, and the
-- container is what the rest of the plate is laid out against (the health bar is
-- anchored to its top). Depending on nameplate style the bar is stretched to fill
-- that container - anchored top *and* bottom - which makes castBar:SetHeight a no-op
-- on its own, so the container has to move with it. Older interface versions kept a
-- flat UnitFrame.castBar with no container; both shapes are handled here.
local function GetCastBarParts(frame)
    local container = frame.CastBarsContainer
    if container then
        return container, container.castBar
    end
    return nil, frame.castBar or frame.CastBar
end

-- Remember what Blizzard sized things to, so our offset is always applied to its
-- values rather than compounding on top of a height we set ourselves.
local function CaptureCastbarBaseline(container, castBar)
    local barHeight = castBar:GetHeight()
    if not barHeight or barHeight <= 0 then return false end

    castBar._perskanBaseBar = barHeight
    castBar._perskanBaseContainer = container and container:GetHeight() or nil
    castBar._perskanBaseSpark = castBar.Spark and castBar.Spark:GetHeight() or nil
    return true
end

local function SetCastbarHeight(container, castBar)
    local baseBar = castBar._perskanBaseBar
    if not baseBar or baseBar <= 0 then return end

    -- Zero means "leave Blizzard's height alone", so the setting is inert until used.
    local target = Perskan.db.profile.nameplateCastbarHeight or 0
    if target <= 0 then target = baseBar end

    local delta = target - baseBar

    -- The container carries the icon strip in styles that put the spell name outside
    -- the bar, so shift it by the delta instead of setting it to the bar height.
    if container and castBar._perskanBaseContainer then
        container:SetHeight(math.max(1, castBar._perskanBaseContainer + delta))
    end
    castBar:SetHeight(target)
    if castBar.Spark and castBar._perskanBaseSpark then
        castBar.Spark:SetHeight(math.max(1, castBar._perskanBaseSpark + delta))
    end
end

local function ApplyCastbarHeight(nameplate)
    local frame = nameplate and nameplate.UnitFrame
    if not frame or frame:IsForbidden() then return end

    local container, castBar = GetCastBarParts(frame)
    if not castBar then return end

    if not castBar._perskanHeightHooked then
        castBar._perskanHeightHooked = true

        if frame.ApplyFrameOptions then
            -- Blizzard rebuilds the whole cast bar layout here (style change, nameplate
            -- size CVar, plate reuse). Re-baseline off its fresh values, then re-apply.
            hooksecurefunc(frame, "ApplyFrameOptions", function(self)
                local hookedContainer, hookedBar = GetCastBarParts(self)
                if not hookedBar then return end
                CaptureCastbarBaseline(hookedContainer, hookedBar)
                SetCastbarHeight(hookedContainer, hookedBar)
            end)
        else
            -- Pre-12.x: no ApplyFrameOptions to hang off, so re-assert on SetHeight
            -- (guarded against our own re-entrant call).
            hooksecurefunc(castBar, "SetHeight", function(self)
                if self._perskanChanging then return end
                self._perskanChanging = true
                SetCastbarHeight(nil, self)
                self._perskanChanging = false
            end)
        end
    end

    if castBar._perskanBaseBar == nil and not CaptureCastbarBaseline(container, castBar) then
        return
    end
    SetCastbarHeight(container, castBar)
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
