-- Action button clean-up: hide hotkey text and/or macro-name text.
--
-- The two features shared near-identical 60-line loops in the old Core.lua; they're
-- unified here over one button list. Each hidden region gets a one-time Show hook
-- gated by the profile flag, so toggling either setting applies live (no reload):
-- turning it off lets the region show again, turning it on sweeps it hidden.

-- Every action button whose text we manage.
local function ForEachActionButton(fn)
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button then fn(button) end
        button = _G["MultiBarBottomLeftButton" .. i]
        if button then fn(button) end
        button = _G["MultiBarBottomRightButton" .. i]
        if button then fn(button) end
        button = _G["MultiBarRightButton" .. i]
        if button then fn(button) end
        button = _G["MultiBarLeftButton" .. i]
        if button then fn(button) end
    end
end

-- Applies the current state of `flagKey` to one region on one button, installing a
-- persistent Show hook the first time so Blizzard can't reveal it while the flag is set.
local function ApplyRegion(button, regionKey, flagKey)
    local region = button[regionKey]
    if not region then return end

    if not region["_perskanHook_" .. flagKey] then
        region["_perskanHook_" .. flagKey] = true
        hooksecurefunc(region, "Show", function(self)
            if Perskan.db.profile[flagKey] then
                self:Hide()
            end
        end)
    end

    if Perskan.db.profile[flagKey] then
        region:Hide()
        region:SetAlpha(0)
    else
        region:SetAlpha(1)
        region:Show()
    end
end

function Perskan:ApplyHideHotkeys()
    ForEachActionButton(function(button)
        ApplyRegion(button, "HotKey", "hideHotkeys")
        ApplyRegion(button, "BPHotKey", "hideHotkeys")
    end)
end

function Perskan:ApplyHideMacroText()
    ForEachActionButton(function(button)
        ApplyRegion(button, "Name", "hideMacroText")
    end)
end

Perskan:RegisterModule("ActionBars", function(self)
    self:ApplyHideHotkeys()
    self:ApplyHideMacroText()
end)
