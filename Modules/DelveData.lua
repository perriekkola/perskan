-- Delve difficulty ratings.
--
-- Ported from DelveSpeedTracker v1.2.0 by Bloom, whose ratings were compiled from a
-- community tier list, variant-specific callouts, beta/forum feedback and blue posts.
-- Only the data survives the port: DelveSpeedTracker draws its window with
-- AbstractFramework, this addon draws with Blizzard's own templates (Modules/DelvePanel.lua).
--
-- Every delve runs one of several "story variants", rotating daily, and the variant is
-- what decides how long a run takes. `variantOrder` is the order Blizzard's story
-- achievement lists its criteria in, which is how a localized criteria string is matched
-- back to the English variant key below (Modules/DelvePanel.lua builds that map).
--
-- Ratings are S (fastest) through F (slowest) and can be tuned from experience.

local addonName, addon = ...

--------------------------------------------------------------------------------
-- Difficulty tiers
--------------------------------------------------------------------------------

-- Ratings sort by `priority` and group under `tier`. Upstream's rating data uses six
-- grades (S A B C D F) while its tier list only ever defined five, so F is shown in the
-- same "Very Slow" band as D and simply sorts to the bottom of it rather than inventing
-- a sixth time estimate.
addon.delveRatings = {
    S = { tier = "S", priority = 1 },
    A = { tier = "A", priority = 2 },
    B = { tier = "B", priority = 3 },
    C = { tier = "C", priority = 4 },
    D = { tier = "D", priority = 5 },
    F = { tier = "D", priority = 6 },
    -- Assigned by the panel when a delve's POI is found but its story variant can't be
    -- read, so the delve is still listed rather than silently dropped.
    ["?"] = { tier = "?", priority = 7 },
}

-- Stock font colours, so the panel stays on the game's own palette.
local function TierColor(global, r, g, b)
    return _G[global] or CreateColor(r, g, b)
end

addon.delveTiers = {
    { key = "S", name = "Turbo",     time = "< 10 min",  color = TierColor("GREEN_FONT_COLOR", 0.1, 1.0, 0.1) },
    { key = "A", name = "Fast",      time = "10-12 min", color = TierColor("YELLOW_FONT_COLOR", 1.0, 0.82, 0.0) },
    { key = "B", name = "Mid",       time = "12-15 min", color = TierColor("ORANGE_FONT_COLOR", 1.0, 0.49, 0.04) },
    { key = "C", name = "Slow",      time = "15-20 min", color = TierColor("RED_FONT_COLOR", 1.0, 0.13, 0.13) },
    { key = "D", name = "Very Slow", time = "20+ min",   color = TierColor("DIM_RED_FONT_COLOR", 0.7, 0.13, 0.13) },
    { key = "?", name = "Unknown",   time = "",          color = TierColor("GRAY_FONT_COLOR", 0.5, 0.5, 0.5) },
}

--------------------------------------------------------------------------------
-- Delves
--------------------------------------------------------------------------------

-- Keys are the English delve names, which is also what the map POI displays on an
-- enUS client. storyAchievementID is "Delve Loremaster: Midnight" (61741) line for the
-- delve; its criteria are the variants, in `variantOrder`.
addon.delves = {
    ["Sunkiller Sanctum"] = { mapID = 2405, storyAchievementID = 61732,
        variantOrder = { "Core of the Problem", "The Gravitational Effect", "Not What I Expected" },
        variants = {
            ["Core of the Problem"]         = "B",
            ["The Gravitational Effect"]    = "C",
            ["Not What I Expected"]         = "D",
        } },
    ["The Grudge Pit"] = { mapID = 2413, storyAchievementID = 61724,
        variantOrder = { "Dastardly Rotstalk", "Arena Champion", "Lightbloom Invasion", "Fungal Pharmacon" },
        variants = {
            ["Dastardly Rotstalk"]          = "D",
            ["Arena Champion"]              = "A",
            ["Lightbloom Invasion"]         = "F",
            ["Fungal Pharmacon"]            = "B",
        } },
    ["Parhelion Plaza"] = { mapID = 2424, storyAchievementID = 61725,
        variantOrder = { "Holding the Line", "March of the Arcane Brigade", "Bombing Run", "Caustic Crush" },
        variants = {
            ["Holding the Line"]            = "B",
            ["March of the Arcane Brigade"] = "F",
            ["Bombing Run"]                 = "D",
            ["Caustic Crush"]               = "B",
        } },
    ["Twilight Crypts"] = { mapID = 2437, storyAchievementID = 61730,
        variantOrder = { "Party Crasher", "Trapped!", "Loosed Loa", "Why'd it Have to Be Snakes?" },
        variants = {
            ["Party Crasher"]               = "C",
            ["Trapped!"]                    = "C",
            ["Loosed Loa"]                  = "F",
            ["Why'd it Have to Be Snakes?"] = "B",
        } },
    ["Collegiate Calamity"] = { mapID = 2395, storyAchievementID = 61726,
        variantOrder = { "Invasive Glow", "Academy Under Siege", "Faculty of Fear", "Academic Antitoxin" },
        variants = {
            ["Invasive Glow"]               = "S",
            ["Academy Under Siege"]         = "D",
            ["Faculty of Fear"]             = "D",
            ["Academic Antitoxin"]          = "B",
        } },
    ["The Darkway"] = { mapID = 2395, storyAchievementID = 61728,
        variantOrder = { "Focusers Under Pressure", "Leyline Technician", "Ogre Powered" },
        variants = {
            ["Focusers Under Pressure"]     = "A",
            ["Leyline Technician"]          = "F",
            ["Ogre Powered"]                = "S",
        } },
    ["Shadowguard Point"] = { mapID = 2405, storyAchievementID = 61733,
        variantOrder = { "Stolen Mana", "Calamitous", "Captured Wildlife", "Basilisk Blitz" },
        variants = {
            ["Stolen Mana"]                 = "A",
            ["Calamitous"]                  = "C",
            ["Captured Wildlife"]           = "D",
            ["Basilisk Blitz"]              = "B",
        } },
    ["The Gulf of Memory"] = { mapID = 2413, storyAchievementID = 61731,
        variantOrder = { "Descent of the Haranir", "Alnmoth Munchies", "Sporasaur Special" },
        variants = {
            ["Descent of the Haranir"]      = "B",
            ["Alnmoth Munchies"]            = "B",
            ["Sporasaur Special"]           = "S",
        } },
    ["The Shadow Enclave"] = { mapID = 2395, storyAchievementID = 61727,
        variantOrder = { "Traitor's Due", "Shadowy Supplies", "Mirror Shine", "Basilisk Blitz" },
        variants = {
            ["Traitor's Due"]               = "S",
            ["Shadowy Supplies"]            = "F",
            ["Mirror Shine"]                = "D",
            ["Basilisk Blitz"]              = "B",
        } },
    ["Atal'Aman"] = { mapID = 2437, storyAchievementID = 61729,
        variantOrder = { "Totem Annihilation", "Ritual Interrupted", "Toadly Unbecoming", "Venomous Vapors" },
        variants = {
            ["Totem Annihilation"]          = "C",
            ["Ritual Interrupted"]          = "F",
            ["Toadly Unbecoming"]           = "S",
            ["Venomous Vapors"]             = "B",
        } },
    ["Gnarldor Isle"] = { mapID = 2512, storyAchievementID = 63437,
        variantOrder = { "Olds and Ends", "Minchi's Osseous Adventure", "Speaking Their Language" },
        variants = {
            ["Olds and Ends"]               = "B",
            ["Minchi's Osseous Adventure"]  = "C",
            ["Speaking Their Language"]     = "A",
        } },
    ["The Ring of Glory"] = { mapID = 2512, storyAchievementID = 63436,
        variantOrder = { "Open Night", "Game Day", "Adopt-a-thon" },
        variants = {
            ["Open Night"]                  = "B",
            ["Game Day"]                    = "S",
            ["Adopt-a-thon"]                = "D",
        } },
}

-- The POI's story line and the achievement criteria don't always use the same wording
-- for the same variant. Keys are the text as the POI widget shows it (colour codes
-- stripped, "Story variant:" prefix removed), values are the English variant key.
addon.delveVariantAliases = {
    ["Captured Widlife"]        = "Captured Wildlife",  -- typo in the game data
    ["Зеркальный блеск"]        = "Mirror Shine",       -- ruRU: criteria say "Блеск зеркала"
    ["반짝이는 거울"]              = "Mirror Shine",       -- koKR: criteria say "거울의 빛"
    ["사로잡힌 야생동물"]           = "Captured Wildlife",  -- koKR: criteria say "붙잡힌 야생동물"
    ["Ungeladene Gäste"]        = "Party Crasher",      -- deDE
}
