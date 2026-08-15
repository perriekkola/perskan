-- Custom sizing, scaling and positioning of the built-in DamageMeter windows.
--
-- Gated on enableDamageMeterCustomization: the SetWidth/SetHeight/SetScale overrides
-- replace Blizzard methods and can't be cleanly undone at runtime, so toggling the
-- master switch asks for a reload. All sub-options apply live via
-- Perskan.ApplyDamageMeterSettings (the field name several config handlers rely on).

-- Where a secondary window attaches relative to the one before it. The sign is
-- applied to the configured spacing so a positive spacing always pushes the windows
-- apart, whichever direction they grow in.
local MULTI_WINDOW_ANCHORS = {
    left   = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMLEFT",  x = -1, y = 0 },
    right  = { point = "BOTTOMLEFT",  relativePoint = "BOTTOMRIGHT", x = 1,  y = 0 },
    top    = { point = "BOTTOMRIGHT", relativePoint = "TOPRIGHT",    x = 0,  y = 1 },
    bottom = { point = "TOPRIGHT",    relativePoint = "BOTTOMRIGHT", x = 0,  y = -1 },
}

Perskan:RegisterModule("DamageMeter", function(self)
    local hookedWindows = {}
    local originalSetWidth = {}
    local originalSetHeight = {}
    local originalSetScale = {}
    local hookedDamageMeterParent = false
    local originalDamageMeterSetWidth = nil
    local originalDamageMeterSetHeight = nil

    local function GetAllDamageMeterSessionWindows()
        local windows = {}
        local i = 1
        while true do
            local window = _G["DamageMeterSessionWindow" .. i]
            if window then
                windows[#windows + 1] = window
                i = i + 1
            else
                break
            end
        end
        return windows
    end

    local function ApplyScaleToWindow(window)
        local scale = Perskan.db.profile.damageMeterScale
        local setScaleFunc = originalSetScale[window] or window.SetScale
        if scale then
            setScaleFunc(window, scale)
        end
    end

    local function GetHeightForWindow(windowIndex)
        local heights = Perskan.db.profile.damageMeterHeights
        if heights and heights[windowIndex] then
            return heights[windowIndex]
        end
        return Perskan.db.profile.damageMeterHeight
    end

    local function ApplyDamageMeterSettings()
        local width = Perskan.db.profile.damageMeterWidth
        local height = GetHeightForWindow(1)
        local scale = Perskan.db.profile.damageMeterScale or 1

        -- Primary window is driven through the DamageMeter parent frame; it carries
        -- ~43px more width padding and ~10px more height padding than session windows.
        if DamageMeter then
            if not hookedDamageMeterParent then
                hookedDamageMeterParent = true
                originalDamageMeterSetWidth = DamageMeter.SetWidth
                DamageMeter.SetWidth = function(frame, w)
                    local ourWidth = Perskan.db.profile.damageMeterWidth
                    originalDamageMeterSetWidth(frame, ourWidth and (ourWidth - 43) or w)
                end
                originalDamageMeterSetHeight = DamageMeter.SetHeight
                DamageMeter.SetHeight = function(frame, h)
                    local ourHeight = GetHeightForWindow(1)
                    originalDamageMeterSetHeight(frame, ourHeight and (ourHeight - 10) or h)
                end
            end
            if width then
                originalDamageMeterSetWidth(DamageMeter, width * scale)
            end
            if height then
                originalDamageMeterSetHeight(DamageMeter, height * scale)
            end
        end

        local allWindows = GetAllDamageMeterSessionWindows()
        for windowIndex, window in ipairs(allWindows) do
            if width then
                if not originalSetWidth[window] then
                    originalSetWidth[window] = window.SetWidth
                    window.SetWidth = function(frame, w)
                        local ourWidth = Perskan.db.profile.damageMeterWidth
                        originalSetWidth[frame](frame, ourWidth or w)
                    end
                end
                originalSetWidth[window](window, width)
            end

            local windowHeight = GetHeightForWindow(windowIndex)
            if windowHeight then
                if not originalSetHeight[window] then
                    originalSetHeight[window] = window.SetHeight
                    window._perskanWindowIndex = windowIndex
                    window.SetHeight = function(frame, h)
                        local ourHeight = GetHeightForWindow(frame._perskanWindowIndex or 1)
                        originalSetHeight[frame](frame, ourHeight or h)
                    end
                end
                originalSetHeight[window](window, windowHeight)
            end

            if not hookedWindows[window] then
                hookedWindows[window] = true
                originalSetScale[window] = window.SetScale
                window.SetScale = function(frame, s)
                    local ourScale = Perskan.db.profile.damageMeterScale
                    originalSetScale[frame](frame, ourScale or s)
                end
                window:HookScript("OnShow", function(frame)
                    ApplyScaleToWindow(frame)
                end)
            end

            ApplyScaleToWindow(window)
        end

        -- Positioning uses protected ClearAllPoints/SetPoint; skip it in combat to
        -- avoid taint, and rely on the next out-of-combat apply.
        if InCombatLockdown() then return end

        if Perskan.db.profile.damageMeterAnchorEnabled and DamageMeter then
            -- Anchor point to point, so the offsets read the same way from whichever
            -- corner/edge the player picked.
            local anchorPoint = Perskan.db.profile.damageMeterAnchorPoint or "BOTTOMRIGHT"
            local xOffset = Perskan.db.profile.damageMeterAnchorXOffset or 0
            local yOffset = Perskan.db.profile.damageMeterAnchorYOffset or 0
            DamageMeter:ClearAllPoints()
            DamageMeter:SetPoint(anchorPoint, UIParent, anchorPoint, xOffset, yOffset)
        end

        local multiAnchor = MULTI_WINDOW_ANCHORS[Perskan.db.profile.damageMeterMultiWindowAnchor]
            or MULTI_WINDOW_ANCHORS.left
        local spacing = Perskan.db.profile.damageMeterSpacing or 0
        for i = 2, #allWindows do
            local window = allWindows[i]
            local prevWindow = allWindows[i - 1]
            window:ClearAllPoints()
            window:SetPoint(multiAnchor.point, prevWindow, multiAnchor.relativePoint,
                multiAnchor.x * spacing, multiAnchor.y * spacing)
        end
    end

    Perskan.ApplyDamageMeterSettings = ApplyDamageMeterSettings

    local setupFrame = CreateFrame("Frame")
    setupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    setupFrame:RegisterEvent("ADDON_LOADED")
    -- Positioning is skipped in combat; re-assert once it ends.
    setupFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    local initialized = false
    setupFrame:SetScript("OnEvent", function(_, event)
        if DamageMeterSessionWindow1 and not initialized then
            initialized = true
            ApplyDamageMeterSettings()
        elseif event == "PLAYER_REGEN_ENABLED" and initialized then
            ApplyDamageMeterSettings()
        end
    end)
end, "enableDamageMeterCustomization")
