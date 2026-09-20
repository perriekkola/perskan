-- Framerate display placement.
--
-- On WoW Forever the framerate readout sits wherever the client puts it, which is not
-- where it is wanted; this pins it to the top centre of the screen. Retail is untouched -
-- the option doesn't exist there - but nothing here is client-specific beyond that.

local TOP_OFFSET = -10

local anchoring = false
local pendingOutOfCombat = false

local function FramerateFrame()
    return _G.FramerateFrame
end

-- Moving a frame in combat is only a problem where the frame is protected, so ask rather
-- than blanket-refusing: the readout is commonly toggled mid-fight, and a blanket combat
-- guard would leave it in the wrong place until the fight ended.
local function CanMove(frame)
    if not InCombatLockdown() then return true end
    return not (frame.IsProtected and frame:IsProtected())
end

function Perskan:ApplyFramerateAnchor()
    -- The relayout below re-points the frame, and that comes back through the hook.
    if anchoring then return end

    local frame = FramerateFrame()
    if not frame then return end

    -- Remember where Blizzard had it, so turning the option off puts it back rather than
    -- guessing at a default.
    if frame._perskanBasePoint == nil then
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        frame._perskanBasePoint = point
            and { point, relativeTo, relativePoint, x, y }
            or false
    end

    local wanted = self.db.profile.anchorFramerateTop

    if not CanMove(frame) then
        pendingOutOfCombat = true
        return
    end

    anchoring = true
    if wanted then
        frame:ClearAllPoints()
        frame:SetPoint("TOP", UIParent, "TOP", 0, TOP_OFFSET)
    elseif frame._perskanMoved and frame._perskanBasePoint then
        local base = frame._perskanBasePoint
        frame:ClearAllPoints()
        frame:SetPoint(base[1], base[2] or UIParent, base[3], base[4] or 0, base[5] or 0)
    end
    frame._perskanMoved = wanted or nil
    anchoring = false

    if not frame._perskanAnchorHooked then
        frame._perskanAnchorHooked = true
        hooksecurefunc(frame, "SetPoint", function()
            Perskan:ApplyFramerateAnchor()
        end)
    end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

Perskan:RegisterModule("FramerateDisplay", function(self)
    self:ApplyFramerateAnchor()

    local events = CreateFrame("Frame")
    -- The readout is created on demand, so the frame may not exist at login; and a move
    -- deferred for combat is owed a retry.
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not pendingOutOfCombat then return end
        pendingOutOfCombat = false
        Perskan:ApplyFramerateAnchor()
    end)
end)
