-- Hide assorted default UI elements, plus the extended chat font-size list.
--
-- The social button and bags bar toggle live (hidden with a gated Show hook so
-- Blizzard can't re-reveal them, shown again when the setting is turned off). Chat
-- sizes overwrite a global table and can't be cleanly reverted, so that one asks
-- for a reload via the settings window's reload banner.

-- Hide/show a named global frame according to a profile flag, keeping it hidden with
-- a one-time Show hook while the flag is set.
local function ApplyManagedFrame(globalName, flagKey)
    local frame = _G[globalName]
    if not frame then return end

    if not frame._perskanHideHooked then
        frame._perskanHideHooked = true
        hooksecurefunc(frame, "Show", function(self)
            if Perskan.db.profile[flagKey] then
                self:Hide()
            end
        end)
    end

    if Perskan.db.profile[flagKey] then
        frame:Hide()
    else
        frame:Show()
    end
end

function Perskan:ApplyHideSocialButton()
    ApplyManagedFrame("QuickJoinToastButton", "hideSocialButton")
end

function Perskan:ApplyHideBagsBar()
    ApplyManagedFrame("BagsBar", "hideBagsBar")
end

function Perskan:ApplyChatSizes()
    if not Perskan.db.profile.addChatSizes then return end
    CHAT_FONT_HEIGHTS = {
        7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
    }
end

Perskan:RegisterModule("HideElements", function(self)
    self:ApplyHideSocialButton()
    self:ApplyHideBagsBar()
    self:ApplyChatSizes()
end)
