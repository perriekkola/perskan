-- Glue for the vendored BindPad (Modules/BindPad/, by Tageshi).
--
-- BindPad keeps its own frames, saved variables (BindPadVars) and slash commands
-- (/bindpad, /bp); the whole feature is deliberately exposed here as one switch plus a
-- button that opens its panel, rather than being folded into the settings schema.
--
-- Its bindings are claimed at login, so the switch is reload-gated: turning it off stops
-- it initialising on the next load (see the two guards marked [Perskan] in BindPad.lua).

function Perskan:OpenBindPad()
    if not self.db.profile.bindPadEnabled then return end
    if type(BindPadFrame_Toggle) ~= "function" then
        self:Print("BindPad isn't loaded.")
        return
    end
    BindPadFrame_Toggle()
end

function Perskan:ApplyBindPad()
    -- Switching off mid-session can't take back the bindings BindPad already applied
    -- (the settings window asks for a reload), but the panel shouldn't stay open.
    if not self.db.profile.bindPadEnabled and BindPadFrame and BindPadFrame:IsVisible() then
        HideUIPanel(BindPadFrame)
    end
end
