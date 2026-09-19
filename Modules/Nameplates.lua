-- Nameplate tweaks: name outline, custom healthbar height, custom castbar height,
-- moving the castbar's spell name/icon up into the bar, friendly clickthrough, and - on
-- WoW Forever only - hiding NPC names that are neither the target nor a quest objective
-- and colouring the names that remain by reaction.
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
local function CaptureSparkBaseline(castBar)
    if not castBar.Spark then return end
    castBar._perskanBaseSpark = PlainNumber(castBar.Spark:GetHeight()) or castBar._perskanBaseSpark
    sharedBase.spark = castBar._perskanBaseSpark or sharedBase.spark
end

local function CaptureCastbarBaseline(container, castBar)
    local barHeight = PlainNumber(castBar:GetHeight())
    if not barHeight then return false end

    local containerHeight = container and PlainNumber(container:GetHeight()) or nil
    if container and not containerHeight then return false end

    castBar._perskanBaseBar = barHeight
    castBar._perskanBaseContainer = containerHeight
    CaptureSparkBaseline(castBar)

    sharedBase.bar = barHeight
    sharedBase.container = containerHeight
    return true
end

-- Blizzard hands ApplyFrameOptions and ApplyStyleAndAnchoring the same NamePlateSetupOptions
-- table it laid the plate out from, which beats measuring the frames: it is still Blizzard's
-- own baseline once one of our heights is on the frame, and it says outright whether this
-- nameplate style draws the spell name inside the bar.
local function CaptureSetupOptions(castBar, setupOptions)
    if type(setupOptions) ~= "table" then return end

    local barHeight = PlainNumber(setupOptions.castBarHeight)
    local iconHeight = PlainNumber(setupOptions.castIconHeight)
    local nameInside = setupOptions.spellNameInsideCastBar and true or false

    castBar._perskanNameInside = nameInside
    sharedBase.nameInside = nameInside

    if iconHeight then
        castBar._perskanBaseIcon = iconHeight
        sharedBase.icon = iconHeight
    end

    if barHeight then
        castBar._perskanBaseBar = barHeight
        sharedBase.bar = barHeight

        -- The container is sized bar + icon when the spell name hangs below the bar, and
        -- bar alone when it is inside it (Blizzard_NamePlateUnitFrame.lua).
        local containerHeight = nameInside and barHeight or (iconHeight and barHeight + iconHeight)
        if containerHeight then
            castBar._perskanBaseContainer = containerHeight
            sharedBase.container = containerHeight
        end
    end
end

-- ApplyStyleAndAnchoring hard-codes the pip's size, so the spark needs re-asserting after
-- every relayout or it snaps back to Blizzard's height and looks stranded on a taller bar.
local function SetCastbarSparkHeight(castBar)
    local spark = castBar.Spark
    if not spark then return end

    local baseBar = castBar._perskanBaseBar or sharedBase.bar
    local baseSpark = castBar._perskanBaseSpark or sharedBase.spark
    if not baseBar or baseBar <= 0 or not baseSpark then return end

    local target = Perskan.db.profile.nameplateCastbarHeight or 0
    if target <= 0 then target = baseBar end

    spark:SetHeight(math.max(1, baseSpark + (target - baseBar)))
end

local function SetCastbarHeight(container, castBar)
    -- Fall back to the shared baseline for plates we could never measure ourselves.
    local baseBar = castBar._perskanBaseBar or sharedBase.bar
    local baseContainer = castBar._perskanBaseContainer or sharedBase.container
    if not baseBar or baseBar <= 0 then return end

    -- Zero means "leave Blizzard's height alone", so the setting is inert until used.
    local target = Perskan.db.profile.nameplateCastbarHeight or 0
    if target <= 0 then target = baseBar end

    -- The container carries the icon strip in styles that put the spell name outside
    -- the bar, so shift it by the delta instead of setting it to the bar height.
    if container and baseContainer then
        container:SetHeight(math.max(1, baseContainer + (target - baseBar)))
    end
    castBar:SetHeight(target)
    SetCastbarSparkHeight(castBar)
end

--------------------------------------------------------------------------------
-- Castbar spell name and icon placement
--------------------------------------------------------------------------------

-- Height of the icon/name strip Blizzard reserves under the bar, which is also how far the
-- bar sits above the container's bottom edge. Preferably Blizzard's own castIconHeight; the
-- container is sized to bar + icon, so the two baselines can stand in for it.
local function CastBarNameStripHeight(castBar)
    -- This plate's own numbers first, in both cases: a shared baseline stands in for a
    -- plate we could never read, not a second opinion to prefer over one we could. Taking
    -- them in the wrong order lets a leftover icon height claim there is a strip under a
    -- bar whose own measurements say there isn't one.
    local strip = castBar._perskanBaseIcon
    if not strip and castBar._perskanBaseBar and castBar._perskanBaseContainer then
        strip = castBar._perskanBaseContainer - castBar._perskanBaseBar
    end

    if not strip then
        strip = sharedBase.icon
        if not strip and sharedBase.bar and sharedBase.container then
            strip = sharedBase.container - sharedBase.bar
        end
    end

    if not strip or strip <= 0 then return nil end
    return strip
end

-- Blizzard lays the cast bar out one of two ways (Blizzard_NamePlateCastingBar.lua):
-- either the spell name and icon sit inside the bar, or they hang below it in their own
-- strip and the bar is anchored to the icon's top edge. The styles that already put them
-- inside - Blocky Bars, Blocky Cast and Legacy Red - are exactly what this option is
-- asking for, so they are left untouched.
local function NameHangsBelowCastBar(castBar)
    -- Legacy Red has its own layout entirely, and it already draws the name in the bar.
    if castBar.classicStyleCastBar then return false end

    local inside = castBar._perskanNameInside
    if inside == nil then inside = sharedBase.nameInside end
    if inside then return false end

    -- No strip reserved under the bar means the name is already in it, whatever we
    -- were told - which is also the answer before Blizzard has handed us setupOptions.
    return CastBarNameStripHeight(castBar) ~= nil
end

local function SetCastbarNamePlacement(container, castBar)
    local icon = castBar.Icon
    if not container or not icon then return end
    if not NameHangsBelowCastBar(castBar) then return end

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

        if castBar.ApplyStyleAndAnchoring then
            -- The one function that clears and rebuilds every cast bar anchor, and it
            -- hard-codes the spark's size while it is at it. UpdateAnchors calls it from
            -- both ApplyFrameOptions and UpdateShowOnlyName, so hooking the relayout itself
            -- is what catches every path - hanging off the callers misses the second one
            -- and the plate quietly snaps back to Blizzard's layout.
            hooksecurefunc(castBar, "ApplyStyleAndAnchoring", function(self, setupOptions)
                -- Runs inside Blizzard's own setup path, so keep any surprise here from
                -- turning into an error message per nameplate.
                pcall(CaptureSetupOptions, self, setupOptions)
                pcall(CaptureSparkBaseline, self)
                pcall(SetCastbarSparkHeight, self)
                -- Everything we moved is back where Blizzard wants it, so the flag has to
                -- go with it or the restore path would be skipped when the option is
                -- turned off later.
                self._perskanNameMoved = nil
                pcall(SetCastbarNamePlacement, self:GetParent(), self)
            end)

            -- Belt and braces: the bar is shown at the start of every cast, which is the
            -- one moment the placement has to be right. Re-asserting here costs a couple
            -- of SetPoints per cast and covers anything that re-anchors on the way up.
            hooksecurefunc(castBar, "Show", function(self)
                pcall(SetCastbarNamePlacement, self:GetParent(), self)
            end)
        end

        if frame.ApplyFrameOptions then
            -- Where Blizzard sizes the bar and its container (style change, nameplate size
            -- CVar, plate reuse). Re-baseline off its fresh values, then re-apply.
            hooksecurefunc(frame, "ApplyFrameOptions", function(self, setupOptions)
                local hookedContainer, hookedBar = GetCastBarParts(self)
                if not hookedBar then return end
                pcall(CaptureSetupOptions, hookedBar, setupOptions)
                if hookedBar._perskanBaseBar == nil then
                    pcall(CaptureCastbarBaseline, hookedContainer, hookedBar)
                end
                pcall(SetCastbarHeight, hookedContainer, hookedBar)
                pcall(SetCastbarNamePlacement, hookedContainer, hookedBar)
            end)
        elseif not castBar.ApplyStyleAndAnchoring then
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
-- Friendly clickthrough
--------------------------------------------------------------------------------

-- Retail 12.x moved a nameplate's clickable region onto the nameplate frame itself as
-- hit-test points, and NamePlateUnitFrameMixin:UpdateHitTestArea is the one function
-- that rebuilds them: it either anchors them around the health bar and name, or - for
-- Blizzard's own name-only friendly plates - clears them outright with
-- ClearAllHitTestPoints (Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua). That
-- clear is exactly what clickthrough is: no hit-test points, no mouse region, so
-- clicks, tooltips and targeting land on whatever is behind the plate.
--
-- Two things shape how it is applied. Changing hit-test points from addon code
-- *raises* when it isn't allowed rather than failing quietly, so every call is guarded
-- on NamePlateFrame:CanChangeHitTestPoints. And in combat it is only allowed on the
-- tick a unit is assigned to a plate, or when Blizzard updated the points on the same
-- tick - which is why this hangs off UpdateHitTestArea itself and off
-- NAME_PLATE_UNIT_ADDED. Every relayout that rebuilds the area re-clears it, in combat
-- as well as out of it.

local function CanChangeHitTest(namePlate)
    if not namePlate.CanChangeHitTestPoints then return false end
    local ok, allowed = pcall(namePlate.CanChangeHitTestPoints, namePlate)
    return ok and allowed and true or false
end

-- Blizzard's own hit-test calls go through securecallfunction so our taint stays out of
-- the nameplate's state, the same habit the delve modules use for widget reads.
local function SecureCall(fn, ...)
    if securecallfunction then
        return securecallfunction(fn, ...)
    end
    return fn(...)
end

local function ApplyClickThrough(frame)
    if not frame or frame:IsForbidden() then return end
    -- Interface versions without hit-test points have nothing to clear; the option is
    -- simply inert there.
    if not (frame.GetNamePlateFrame and frame.UpdateHitTestArea and frame.IsFriend) then return end

    -- The personal resource display is a friendly plate as well, and the game has its
    -- own setting for that one (the NameplatePersonalClickThrough CVar), so it is left
    -- alone here.
    if frame.unit and UnitIsUnit(frame.unit, "player") then return end

    local namePlate = frame:GetNamePlateFrame()
    if not (namePlate and namePlate.ClearAllHitTestPoints) then return end
    if not CanChangeHitTest(namePlate) then return end

    if Perskan.db.profile.nameplateFriendlyClickThrough and frame:IsFriend() then
        pcall(SecureCall, namePlate.ClearAllHitTestPoints, namePlate)
        frame._perskanClickThrough = true
    elseif frame._perskanClickThrough then
        -- Hand the area back to Blizzard, rebuilt from the shared setup options every
        -- plate is laid out from - the same call UpdateShowOnlyName makes. Without that
        -- table there is nothing to restore from, so keep the flag and try again on the
        -- next pass rather than leaving the plate clickthrough with no way back.
        if type(NamePlateSetupOptions) ~= "table" then return end
        frame._perskanClickThrough = nil
        pcall(SecureCall, frame.UpdateHitTestArea, frame, NamePlateSetupOptions)
    end
end

local function HookClickThrough(nameplate)
    local frame = nameplate and nameplate.UnitFrame
    if not frame or frame:IsForbidden() then return end
    if not frame.UpdateHitTestArea then return end

    if not frame._perskanHitTestHooked then
        frame._perskanHitTestHooked = true

        -- Blizzard has just set the points, so ours is an allowed change on this tick
        -- even in combat. The profile is read inside, so the hook costs nothing once
        -- the option is switched off. The guard keeps the restore path - which calls
        -- UpdateHitTestArea itself - from re-entering this hook.
        hooksecurefunc(frame, "UpdateHitTestArea", function(self)
            if self._perskanInHitTest then return end
            self._perskanInHitTest = true
            pcall(ApplyClickThrough, self)
            self._perskanInHitTest = false
        end)
    end

    ApplyClickThrough(frame)
end

function Perskan:ApplyNameplateFriendlyClickThrough()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        pcall(HookClickThrough, nameplate)
    end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------
-- Name display: relevance and reaction colouring
--------------------------------------------------------------------------------
-- Forever labels every nameplate, which buries the two units that actually matter: what
-- you are fighting and what a quest wants. With the relevance option on, an NPC keeps its
-- name only while it is the current target or counts toward an active quest objective.
-- Players are never hidden - a name is how you tell one player from another.
--
-- Once most names are gone, reaction is no longer readable from the row of names, so the
-- colour option paints what is left: NPCs by reaction, players by class.

local HOSTILE_NAME_COLOR = { 1.00, 0.28, 0.25 }
local NEUTRAL_NAME_COLOR = { 1.00, 0.85, 0.24 }
local FRIENDLY_NAME_COLOR = { 0.35, 0.95, 0.40 }
local TAPPED_NAME_COLOR = { 0.55, 0.55, 0.55 }

local QUEST_SCANNER_NAME = "PerskanQuestScanTooltip"
local questScanner
local questObjectiveCache = {}

local function QuestScanner()
    if not questScanner then
        questScanner = CreateFrame("GameTooltip", QUEST_SCANNER_NAME, nil, "GameTooltipTemplate")
    end
    return questScanner
end

-- A unit that counts toward a quest carries an objective line on its tooltip - "3/6
-- Wolves slain", or a percentage for the progress-bar kind. There is no public API for
-- the question on this client, so the tooltip is the source; the answer is cached per
-- GUID because this runs for every visible nameplate and only moves when the quest log
-- does.
local function ScanForQuestObjective(unit)
    local tip = QuestScanner()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()

    if not pcall(tip.SetUnit, tip, unit) then
        return false
    end

    for i = 2, tip:NumLines() do
        local line = _G[QUEST_SCANNER_NAME .. "TextLeft" .. i]
        local text = line and line:GetText()
        if text and (text:find("%d+%s*/%s*%d+") or text:find("%d+%s*%%")) then
            return true
        end
    end

    return false
end

local function IsQuestObjectiveUnit(unit)
    -- Use a direct answer where the client has one rather than reading a tooltip.
    if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok then
            return related and true or false
        end
    end

    local guid = UnitGUID(unit)
    if not guid then
        return ScanForQuestObjective(unit)
    end

    local cached = questObjectiveCache[guid]
    if cached == nil then
        cached = ScanForQuestObjective(unit)
        questObjectiveCache[guid] = cached
    end

    return cached
end

-- Field names for the health bar differ across clients, and the name's colour and its
-- refresh both hang off finding it, so fall back to looking for it: the unit frame's
-- first StatusBar child is the bar on every layout this addon has met. Cached per frame.
local function NameplateHealthBar(frame)
    if frame._perskanHealthBar ~= nil then
        return frame._perskanHealthBar or nil
    end

    local bar = frame.healthBar or frame.HealthBarsContainer or frame.HealthBar
    if not (bar and bar.GetStatusBarColor) then
        bar = nil
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                if child.GetObjectType and child:GetObjectType() == "StatusBar" then
                    bar = child
                    break
                end
            end
        end
    end

    frame._perskanHealthBar = bar or false
    return bar
end

-- GetNamePlateForUnit raises, rather than returning nil, on a token it won't accept -
-- "targettarget" among them - and the unit events this module listens to fire for exactly
-- those. Ask through pcall so a token without a nameplate is simply no answer.
local function NamePlateForUnit(unit)
    if not (unit and C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    return ok and plate or nil
end

-- The unit token lives on the unit frame on retail and on the nameplate itself on the
-- Classic line, so take whichever this client offers.
local function NameplateUnit(frame)
    local unit = frame.unit or frame.displayedUnit
    if unit then return unit end
    local plate = frame.GetParent and frame:GetParent()
    return plate and plate.namePlateUnitToken or nil
end

local function ShouldShowName(unit)
    if UnitIsPlayer(unit) then return true end
    if UnitIsUnit(unit, "target") then return true end
    return IsQuestObjectiveUnit(unit)
end

-- Tapped by someone else, so no credit is coming. Prefer the single modern call; the
-- Classic line answers the same question with the older tapped/tapped-by-me pair.
local function IsTapDenied(unit)
    if UnitIsTapDenied then
        local ok, denied = pcall(UnitIsTapDenied, unit)
        if ok then return denied and true or false end
    end

    if not (UnitIsTapped and UnitIsTappedByPlayer) then return false end

    local ok, tapped = pcall(UnitIsTapped, unit)
    if not ok or not tapped then return false end

    local mineOk, mine = pcall(UnitIsTappedByPlayer, unit)
    if mineOk and mine then return false end

    if UnitIsTappedByAllThreatList then
        local sharedOk, shared = pcall(UnitIsTappedByAllThreatList, unit)
        if sharedOk and shared then return false end
    end

    return true
end

local function NameColorFor(unit, frame)
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local palette = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
        local color = class and palette and palette[class]
        if color then
            return color.r, color.g, color.b
        end
        return nil
    end

    -- Read the colour off the health bar rather than working out what it ought to be.
    -- Whatever this client decides - reaction, engaged neutral, tapped, anything added
    -- later - the bar already shows it, and the name matching the bar is the whole point.
    local healthBar = frame and NameplateHealthBar(frame)
    if healthBar then
        local ok, r, g, b = pcall(healthBar.GetStatusBarColor, healthBar)
        if ok and r then return r, g, b end
    end

    -- Only reachable if the bar could not be found at all.
    if UnitSelectionColor then
        local ok, r, g, b = pcall(UnitSelectionColor, unit, true)
        if ok and r then return r, g, b end
    end

    if IsTapDenied(unit) then
        return TAPPED_NAME_COLOR[1], TAPPED_NAME_COLOR[2], TAPPED_NAME_COLOR[3]
    end

    local reaction = UnitReaction("player", unit)
    if not reaction then return nil end

    local color = (reaction <= 3 and HOSTILE_NAME_COLOR)
        or (reaction == 4 and NEUTRAL_NAME_COLOR)
        or FRIENDLY_NAME_COLOR
    return color[1], color[2], color[3]
end

local function ApplyNameDisplay(frame)
    local nameFS = frame and frame.name
    if not nameFS then return end

    local unit = NameplateUnit(frame)
    if not unit or not UnitExists(unit) then return end

    local profile = Perskan.db.profile

    -- Alpha rather than Hide. Blizzard calls Show() on the fontstring whenever it
    -- refreshes a name, so a hidden name came back the instant it did and went again on
    -- the next poll - visible flicker. Nothing in the nameplate code sets the name's own
    -- alpha (the fade you see is the whole plate's, and alphas multiply), so zero sticks
    -- through Show() and there is nothing to flicker between. A plate Blizzard hides for
    -- its own reasons stays hidden either way, since this never calls Show().
    if nameFS._perskanBaseAlpha == nil then
        nameFS._perskanBaseAlpha = nameFS:GetAlpha() or 1
    end

    if profile.nameplateNamesRelevantOnly and not ShouldShowName(unit) then
        if nameFS:GetAlpha() ~= 0 then
            nameFS:SetAlpha(0)
        end
        nameFS._perskanHidName = true
    elseif nameFS._perskanHidName then
        nameFS:SetAlpha(nameFS._perskanBaseAlpha)
        nameFS._perskanHidName = nil
    end

    -- Remember what Blizzard shipped, the same way the outline remembers its font flags,
    -- so switching the option off puts the colour back without a reload.
    if nameFS._perskanBaseColor == nil then
        local r, g, b = nameFS:GetVertexColor()
        nameFS._perskanBaseColor = { r or 1, g or 1, b or 1 }
    end

    local r, g, b
    if profile.nameplateNameHostilityColor then
        r, g, b = NameColorFor(unit, frame)
    elseif nameFS._perskanColored then
        r, g, b = unpack(nameFS._perskanBaseColor)
    end

    if r then
        nameFS:SetVertexColor(r, g, b)
        nameFS._perskanColored = profile.nameplateNameHostilityColor or nil
    end
end

-- Deliberately hookless. Every earlier attempt at keeping the name in step re-asserted
-- from inside Blizzard's own execution - hooks on the fontstring's SetText, Show and
-- SetVertexColor, and on the health bar's SetStatusBarColor - and that is exactly what
-- the taint rules in CLAUDE.md warn against. Edit Mode refreshes every unit frame in one
-- pass, so our taint rode that pass into the party frames and their health values are
-- secret in 12.x: "attempt to compare local 'currValue' (a secret number value, while
-- execution tainted by 'Perskan')", hundreds of times a second.
--
-- A poll on our own frame costs a pass over the visible nameplates a few times a second -
-- each one a handful of Unit* calls and a cached quest answer - and cannot taint anything,
-- because Blizzard is never on the stack. The name lags a repaint by up to the interval,
-- which for a colour and a visibility flag is not something an eye can catch.
local function HookNameplateNameDisplay(frame)
    if not frame or not frame.name then return end
    ApplyNameDisplay(frame)
end

function Perskan:ApplyNameplateNameDisplay()
    ForEachNameplateFrame(HookNameplateNameDisplay)
end


--------------------------------------------------------------------------------

Perskan:RegisterModule("Nameplates", function(self)
    if outlineHooked and healthbarHooked then return end
    outlineHooked = true
    healthbarHooked = true

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    -- Which names are relevant moves with the target and with the quest log, and neither
    -- change touches a nameplate, so both have to re-run the pass themselves.
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    -- Reaction and tap state change without Blizzard touching the name - it recolours the
    -- health bar and stops there - so none of the fontstring hooks fire. Without these a
    -- neutral mob that turns hostile keeps a yellow name over a red bar. Registered
    -- defensively: an event this client doesn't know raises on RegisterEvent.
    for _, event in ipairs({ "UNIT_FACTION", "UNIT_THREAT_LIST_UPDATE", "UNIT_FLAGS" }) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    -- Hit-test points can't be changed by us mid-combat unless Blizzard touched them on
    -- the same tick, so a plate that took the setting late (or lost it on a toggle in
    -- combat) is squared up on the way out of combat.
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" then
            Perskan:ApplyNameplateFriendlyClickThrough()
            return
        end

        if event == "PLAYER_TARGET_CHANGED" then
            Perskan:ApplyNameplateNameDisplay()
            return
        end

        if event == "UNIT_FACTION" or event == "UNIT_THREAT_LIST_UPDATE"
            or event == "UNIT_FLAGS" then
            -- Only the one plate: these fire per unit, and in combat they fire often.
            local plate = NamePlateForUnit(unit)
            local frame = plate and plate.UnitFrame
            if frame and not frame:IsForbidden() then
                HookNameplateNameDisplay(frame)
            end
            return
        end

        if event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
            -- Accepting or finishing a quest changes which units are objectives, and the
            -- cache has no way to know that from a GUID.
            table.wipe(questObjectiveCache)
            Perskan:ApplyNameplateNameDisplay()
            return
        end

        local nameplate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
        if not nameplate then return end
        ApplyHealthbarHeight(nameplate)
        ApplyCastbarLayout(nameplate)
        -- The tick the unit is assigned is one of the two moments the hit-test points
        -- are ours to change in combat, so the clickthrough pass belongs here.
        pcall(HookClickThrough, nameplate)
        local frame = nameplate.UnitFrame
        if frame and not frame:IsForbidden() then
            HookNameplateName(frame)
            HookNameplateNameDisplay(frame)
        end
    end)

    -- The name display polls instead of hooking; see HookNameplateNameDisplay. The pass
    -- is skipped outright while both options are off, so a player who never turns them
    -- on pays nothing for them.
    local NAME_POLL_INTERVAL = 0.05
    local sinceNamePoll = 0
    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        local profile = Perskan.db and Perskan.db.profile
        if not profile then return end
        if not (profile.nameplateNamesRelevantOnly or profile.nameplateNameHostilityColor) then
            return
        end

        sinceNamePoll = sinceNamePoll + elapsed
        if sinceNamePoll < NAME_POLL_INTERVAL then return end
        sinceNamePoll = 0

        Perskan:ApplyNameplateNameDisplay()
    end)

    -- Catch nameplates that already exist at login.
    self:ApplyNameplateHealthbarHeight()
    self:ApplyNameplateCastbarHeight()
    self:ApplyNameplateNameOutline()
    self:ApplyNameplateNameDisplay()
    self:ApplyNameplateFriendlyClickThrough()
end)
