-- Lifecycle glue. All feature logic now lives in Modules/*.lua, each of which
-- registers a setup function via Perskan:RegisterModule (see Options.lua). OnEnable
-- runs the registry, isolating each module in a pcall so one broken feature can't
-- abort the rest.

function Perskan:OnEnable()
    for _, module in ipairs(self.modules) do
        if not module.key or self.db.profile[module.key] then
            local ok, err = pcall(module.setup, self)
            if not ok then
                geterrorhandler()(("Perskan module '%s' failed: %s"):format(module.name, tostring(err)))
            end
        end
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Perskan:PLAYER_ENTERING_WORLD()
    -- Re-assert CVars every zone in case Blizzard reset them.
    if self.ApplyCVars then
        self:ApplyCVars()
    end
end

-- Re-apply everything that can take effect live. Called after a profile switch/reset
-- so the new profile's values show up immediately instead of only after a reload.
-- (Reload-gated features - chat sizes, buff-bar cast-bar anchoring, damage-meter
-- customization - still need a reload; their controls flag the banner individually.)
local LIVE_APPLIERS = {
    "ApplyCVars",
    "ApplyNameplateSize",
    "ApplyNameplateHealthbarHeight",
    "ApplyNameplateCastbarHeight",
    "ApplyNameplateNameOutline",
    "ApplyEncounterBarScale",
    "ApplyXpBarScale",
    "ApplyExtraActionButtonScale",
    "ApplyTalkingHeadScale",
    "ApplyHideHotkeys",
    "ApplyHideMacroText",
    "ApplyGreyOnCooldown",
    "ApplyRangeColoring",
    "ApplyDelveMapPins",
    "ApplyChatCopyButton",
    "ApplyChatFade",
    "ApplyHideSocialButton",
    "ApplyHideBagsBar",
    "ApplyTargetFocusAuraSize",
    "ApplyTrackedBarLayout",
}

function Perskan:ApplyProfileSettings()
    for _, name in ipairs(LIVE_APPLIERS) do
        if self[name] then
            pcall(self[name], self)
        end
    end
    if self.ApplyDamageMeterSettings then
        pcall(self.ApplyDamageMeterSettings)
    end
end
