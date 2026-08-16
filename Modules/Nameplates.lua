-- Nameplate tweaks: name outline, custom healthbar height, custom castbar height and
-- moving the castbar's spell name/icon up into the bar.
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

-- Retail 12.x can hand back a "secret" value from a getter while an addon is on the
-- call stack: it can be passed around, but comparing it throws. Nameplate heights come
-- back secret during unit setup, so every measurement is screened before it is used.
-- issecretvalue only exists on 12.x; the pcall covers older clients and any getter
-- that hands back something unexpected.
local function PlainNumber(value)
    if issecretvalue and issecretvalue(value) then return nil end
    local ok, usable = pcall(function() return type(value) == "number" and value > 0 end)
    if not ok or not usable then return nil end
    return value
end

-- Every nameplate is laid out from the same shared NamePlateSetupOptions, so a
-- baseline read off one plate describes all of them. Keeping a copy here is what
-- lets a plate whose own measurements come back secret still take the setting -
-- otherwise those plates silently keep Blizzard's height while the rest change.
local sharedBase = {}

-- Remember what Blizzard sized things to, so our offset is always applied to its
-- values rather than compounding on top of a height we set ourselves. A measurement
-- we can't read keeps the previous baseline rather than replacing it with a partial
-- one - the plate then keeps the height it already had.
local function CaptureCastbarBaseline(container, castBar)
    local barHeight = PlainNumber(castBar:GetHeight())
    if not barHeight then return false end

    local containerHeight = container and PlainNumber(container:GetHeight()) or nil
    if container and not containerHeight then return false end

    castBar._perskanBaseBar = barHeight
    castBar._perskanBaseContainer = containerHeight
    if castBar.Spark then
        castBar._perskanBaseSpark = PlainNumber(castBar.Spark:GetHeight()) or castBar._perskanBaseSpark
    end

    sharedBase.bar = barHeight
    sharedBase.container = containerHeight
    sharedBase.spark = castBar._perskanBaseSpark
    return true
end

local function SetCastbarHeight(container, castBar)
    -- Fall back to the shared baseline for plates we could never measure ourselves.
    local baseBar = castBar._perskanBaseBar or sharedBase.bar
    local baseContainer = castBar._perskanBaseContainer or sharedBase.container
    local baseSpark = castBar._perskanBaseSpark or sharedBase.spark
    if not baseBar or baseBar <= 0 then return end

    -- Zero means "leave Blizzard's height alone", so the setting is inert until used.
    local target = Perskan.db.profile.nameplateCastbarHeight or 0
    if target <= 0 then target = baseBar end

    local delta = target - baseBar

    -- The container carries the icon strip in styles that put the spell name outside
    -- the bar, so shift it by the delta instead of setting it to the bar height.
    if container and baseContainer then
        container:SetHeight(math.max(1, baseContainer + delta))
    end
    castBar:SetHeight(target)
    if castBar.Spark and baseSpark then
        castBar.Spark:SetHeight(math.max(1, baseSpark + delta))
    end
end

--------------------------------------------------------------------------------
-- Castbar spell name and icon placement
--------------------------------------------------------------------------------

-- Blizzard lays the cast bar out one of two ways (Blizzard_NamePlateCastingBar.lua):
-- either the spell name and icon sit inside the bar, or they hang below it in their own
-- strip and the bar is anchored to the icon's top edge. The styles that already put them
-- inside - Blocky Bars, Blocky Cast and Legacy Red - are exactly what this option is
-- asking for, so they are left untouched.
local function SpellNameAlreadyInsideCastBar()
    local styles = Enum and Enum.NamePlateStyle
    if not styles then return true end

    local style = C_CVar and C_CVar.GetCVar and tonumber(C_CVar.GetCVar("nameplateStyle"))
    if not style then return true end

    return style == styles.Block or style == styles.CastFocus or style == styles.Classic
end

-- Height of the icon/name strip Blizzard reserves under the bar, which is also how far
-- the bar sits above the container's bottom edge. The container is sized to bar + icon,
-- so the difference of the two baselines is the strip - and a strip of nothing means the
-- name is already inside the bar, whatever the style CVar says.
local function CastBarNameStripHeight(castBar)
    local baseBar = castBar._perskanBaseBar or sharedBase.bar
    local baseContainer = castBar._perskanBaseContainer or sharedBase.container
    if not baseBar or not baseContainer then return nil end

    local strip = baseContainer - baseBar
    if strip <= 0 then return nil end
    return strip
end

local function SetCastbarNamePlacement(container, castBar)
    local icon = castBar.Icon
    if not container or not icon then return end

    -- Legacy Red has its own layout entirely, and it already draws the name in the bar.
    if castBar.classicStyleCastBar or SpellNameAlreadyInsideCastBar() then return end

    local strip = CastBarNameStripHeight(castBar)
    if not strip then return end

    if Perskan.db.profile.nameplateCastbarNameInside then
        -- Blizzard hangs the bar off the icon's top edge, so the bar has to be re-anchored
        -- to the container first - otherwise moving the icon would drag the bar with it.
        -- Pinning the bar's bottom `strip` above the container bottom leaves it exactly
        -- where it was.
        castBar:ClearAllPoints()
        PixelUtil.SetPoint(castBar, "BOTTOMLEFT", container, "BOTTOMLEFT", 0, strip)
        PixelUtil.SetPoint(castBar, "BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, strip)

        -- Anchoring the icon to the bar's left edge is what Blizzard's own inside-the-bar
        -- styles do. The spell name and the interrupt shield hang off the icon and so come
        -- along, and a LEFT-to-LEFT anchor keeps the whole row centred on the bar whatever
        -- height the castbar height setting lands on.
        icon:ClearAllPoints()
        PixelUtil.SetPoint(icon, "LEFT", castBar, "LEFT",
            Perskan.db.profile.nameplateCastbarNameInset or 0, 0)

        castBar._perskanNameMoved = true
    elseif castBar._perskanNameMoved then
        castBar._perskanNameMoved = nil

        -- Put back what ApplyStyleAndAnchoring lays down for the styles we touch.
        icon:ClearAllPoints()
        PixelUtil.SetPoint(icon, "BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)

        castBar:ClearAllPoints()
        PixelUtil.SetPoint(castBar, "BOTTOM", icon, "TOP", 0, 0)
        PixelUtil.SetPoint(castBar, "LEFT", container, "BOTTOMLEFT", 0, 0)
        PixelUtil.SetPoint(castBar, "RIGHT", container, "BOTTOMRIGHT", 0, 0)
    end
end

--------------------------------------------------------------------------------
-- Castbar layout pass
--------------------------------------------------------------------------------

local function ApplyCastbarLayout(nameplate)
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
                -- Runs inside Blizzard's own setup path, so keep any surprise here
                -- from turning into an error message per nameplate.
                pcall(CaptureCastbarBaseline, hookedContainer, hookedBar)
                pcall(SetCastbarHeight, hookedContainer, hookedBar)
                -- Blizzard has just re-anchored everything, so anything we moved is back
                -- where it started; the flag has to go with it or the restore path below
                -- would be skipped next time the option is turned off.
                hookedBar._perskanNameMoved = nil
                pcall(SetCastbarNamePlacement, hookedContainer, hookedBar)
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

    -- A failed capture is not fatal: the shared baseline still gets this plate to the
    -- right height, and a later pass re-measures it.
    if castBar._perskanBaseBar == nil then
        CaptureCastbarBaseline(container, castBar)
    end
    SetCastbarHeight(container, castBar)
    SetCastbarNamePlacement(container, castBar)
end

local function ForEachCastBar()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        pcall(ApplyCastbarLayout, nameplate)
    end
end

function Perskan:ApplyNameplateCastbarHeight()
    ForEachCastBar()
end

function Perskan:ApplyNameplateCastbarNamePlacement()
    ForEachCastBar()
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
        ApplyCastbarLayout(nameplate)
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
