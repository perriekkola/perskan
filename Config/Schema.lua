local addonName, addon = ...

-- Data-driven description of the settings window. The renderer (Config/Window.lua)
-- walks this and builds MiniFramework widgets from it.
--
-- Control fields:
--   type      "toggle" | "range" | "select" | "divider"
--   key       profile key it reads/writes
--   name      label
--   desc      tooltip text
--   store     toggle storage: "bool" (default) or "int01" (stored as 1/0)
--   min/max/step, values (select: ordered { {value=, text=}, ... })
--   cvar      apply this CVar on change (toggles map true/false -> 1/0)
--   apply     function() run after the write for a live effect
--   reload    true -> flag a pending UI reload (non-blocking banner) instead
--   disabled  function() -> boolean
--   hidden    function() -> boolean
--
-- Anything with `apply` takes effect immediately. Only settings that genuinely can't
-- revert at runtime carry `reload`, so the reload banner is the exception, not the rule.

local function P() return Perskan end
local function profile() return Perskan.db.profile end

local function extraQuestButtonMissing()
    return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ExtraQuestButton"))
end

local function damageMeterCustomizationOff()
    return not profile().enableDamageMeterCustomization
end

addon.configSchema = {
    --------------------------------------------------------------------------------
    {
        key = "camera",
        title = "Camera",
        icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
        controls = {
            { type = "range", key = "cameraYawMoveSpeed", name = "Camera Yaw Move Speed",
              desc = "How quickly the camera rotates.", min = 0, max = 100, step = 1,
              cvar = "cameraYawMoveSpeed" },
            { type = "toggle", key = "cameraPivot", name = "Camera Pivot", store = "bool",
              desc = "Let the camera pivot over your character when close.", cvar = "cameraPivot" },
            { type = "range", key = "cameraDistanceMaxZoomFactor", name = "Max Zoom Distance",
              desc = "How far the camera can zoom out.", min = 1, max = 2.5, step = 0.1,
              cvar = "cameraDistanceMaxZoomFactor" },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "nameplates",
        title = "Nameplates",
        icon = "Interface\\Icons\\Ability_Hunter_MasterMarksman",
        controls = {
            { type = "range", key = "nameplateWidth", name = "Nameplate Width",
              desc = "Clickable and healthbar width of nameplates.", min = 60, max = 400, step = 1,
              apply = function() P():ApplyNameplateSize() end },
            { type = "range", key = "nameplateClickableHeight", name = "Clickable Height",
              desc = "Clickable height of nameplates.", min = 1, max = 300, step = 1,
              apply = function() P():ApplyNameplateSize() end },
            { type = "range", key = "nameplateHealthbarHeight", name = "Healthbar Height",
              desc = "Height of the healthbar on nameplates.", min = 1, max = 30, step = 0.1,
              apply = function() P():ApplyNameplateHealthbarHeight() end },
            { type = "toggle", key = "nameplateNameOutline", name = "Name Outline", store = "bool",
              desc = "Add an outline to nameplate names for readability.",
              apply = function() P():ApplyNameplateNameOutline() end },
            { type = "range", key = "nameplateOtherBottomInset", name = "Bottom Inset",
              desc = "Nameplate bottom inset.", min = -1, max = 1, step = 0.01,
              cvar = "nameplateOtherBottomInset" },
            { type = "range", key = "nameplateOtherTopInset", name = "Top Inset",
              desc = "Nameplate top inset.", min = -1, max = 1, step = 0.01,
              cvar = "nameplateOtherTopInset" },

            { type = "divider", name = "Visibility" },
            { type = "toggle", key = "alwaysShowNameplates", name = "Always Show Nameplates",
              store = "int01", cvar = "alwaysShowNameplates" },
            { type = "toggle", key = "nameplateShowAll", name = "Show All Nameplates",
              store = "int01", cvar = "nameplateShowAll" },
            { type = "toggle", key = "nameplateShowEnemies", name = "Show Enemy Nameplates",
              store = "int01", cvar = "nameplateShowEnemies" },
            { type = "toggle", key = "nameplateShowEnemyMinions", name = "Show Enemy Minions",
              store = "int01", cvar = "nameplateShowEnemyMinions" },
            { type = "toggle", key = "nameplateShowFriendlyMinions", name = "Show Friendly Minions",
              store = "int01", cvar = "nameplateShowFriendlyMinions" },

            { type = "divider", name = "Personal Resource Display" },
            { type = "toggle", key = "nameplateShowSelf", name = "Show Personal Resource Display",
              store = "int01", cvar = "nameplateShowSelf" },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "unitframes",
        title = "Unit Frames",
        icon = "Interface\\Icons\\Achievement_PVP_A_A",
        controls = {
            { type = "divider", name = "Raid & PvP Frames" },
            { type = "toggle", key = "raidFramesDisplayAggroHighlight", name = "Display Aggro Highlight",
              store = "int01", cvar = "raidFramesDisplayAggroHighlight" },
            { type = "toggle", key = "raidFramesDisplayClassColor", name = "Display Class Color",
              store = "int01", cvar = "raidFramesDisplayClassColor" },
            { type = "toggle", key = "raidOptionDisplayMainTankAndAssist", name = "Display Main Tank & Assist",
              store = "int01", cvar = "raidOptionDisplayMainTankAndAssist" },
            { type = "toggle", key = "pvpFramesDisplayClassColor", name = "PvP Frames Class Color",
              store = "int01", cvar = "pvpFramesDisplayClassColor" },

            { type = "divider", name = "Target & Focus Auras" },
            { type = "range", key = "targetFocusAuraSize", name = "Aura Size",
              desc = "Size of buff/debuff icons on the target and focus frames.", min = 10, max = 40, step = 1,
              apply = function() P():ApplyTargetFocusAuraSize() end },
            { type = "toggle", key = "showAuraCooldownNumbers", name = "Show Aura Cooldown Numbers",
              store = "bool", desc = "Force cooldown numbers on unit frame buff/debuff icons.",
              apply = function() P():ApplyAuraCooldownNumbers() end },
            { type = "range", key = "auraCooldownNumbersScale", name = "Cooldown Number Scale",
              desc = "Size of the cooldown numbers.", min = 0.3, max = 1.5, step = 0.1,
              apply = function() P():ApplyAuraCooldownNumbers() end,
              disabled = function() return not profile().showAuraCooldownNumbers end },

            { type = "divider", name = "Raid Frame Auras" },
            { type = "toggle", key = "showRaidFrameAuraCooldowns", name = "Show Raid Frame Cooldowns",
              store = "bool", desc = "Show cooldown numbers on raid frame buff/debuff icons.",
              apply = function() P():ApplyRaidFrameAuraCooldowns() end },
            { type = "range", key = "raidFrameAuraCooldownScale", name = "Raid Cooldown Number Scale",
              desc = "Size of the cooldown numbers on raid frames.", min = 0.3, max = 1.5, step = 0.1,
              apply = function() P():ApplyRaidFrameAuraCooldowns() end,
              disabled = function() return not profile().showRaidFrameAuraCooldowns end },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "actionbars",
        title = "Action Bars",
        icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
        controls = {
            { type = "toggle", key = "hideHotkeys", name = "Hide Hotkeys", store = "bool",
              desc = "Hide hotkey text on action buttons.",
              apply = function() P():ApplyHideHotkeys() end },
            { type = "toggle", key = "hideMacroText", name = "Hide Macro Text", store = "bool",
              desc = "Hide macro names on action buttons.",
              apply = function() P():ApplyHideMacroText() end },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "framescaling",
        title = "Frame Scaling",
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
        controls = {
            { type = "range", key = "encounterBarScale", name = "Encounter Bar Scale",
              desc = "Scale of the encounter/boss ability bar.", min = 0.5, max = 2.0, step = 0.1,
              apply = function() P():ApplyEncounterBarScale() end },
            { type = "range", key = "talkingHeadScale", name = "Talking Head Scale",
              desc = "Scale of the talking head frame.", min = 0.5, max = 2.0, step = 0.1,
              apply = function() P():ApplyTalkingHeadScale() end },
            { type = "range", key = "xpBarScale", name = "XP / Status Bar Scale",
              desc = "Scale of the XP and reputation bars.", min = 0.5, max = 2.0, step = 0.1,
              apply = function() P():ApplyXpBarScale() end },
            { type = "range", key = "extraActionButtonScale", name = "Extra Action Button Scale",
              desc = "Scale of the extra action button.", min = 0.5, max = 2.0, step = 0.1,
              apply = function() P():ApplyExtraActionButtonScale() end },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "trackedbars",
        title = "Tracked Bars",
        icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
        controls = {
            { type = "toggle", key = "anchorBuffBarsToWidgetFrame", name = "Anchor Buff Bars to Cast Bar",
              store = "bool", reload = true,
              desc = "Anchor BuffBarCooldownViewer above the cast bar. Requires a reload to take effect." },
            { type = "toggle", key = "sortBuffBarsUpward", name = "Sort Bars Upward",
              store = "bool", reload = true,
              desc = "Stack tracked bars upward without gaps. Requires a reload to take effect." },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "damagemeter",
        title = "Damage Meter",
        icon = "Interface\\Icons\\Ability_Warrior_Rampage",
        controls = {
            { type = "toggle", key = "enableDamageMeter", name = "Enable Damage Meter", store = "int01",
              desc = "Toggle Blizzard's built-in damage/healing meter.", cvar = "damageMeterEnabled" },

            { type = "divider", name = "Customization" },
            { type = "toggle", key = "enableDamageMeterCustomization", name = "Enable Customization",
              store = "bool", reload = true,
              desc = "Enable custom sizing, scaling and positioning of the built-in meter. Requires a reload." },
            { type = "range", key = "damageMeterWidth", name = "Width",
              desc = "Width of all meter windows.", min = 100, max = 400, step = 1,
              hidden = damageMeterCustomizationOff,
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "range", key = "damageMeterHeight", name = "Height (Window 1)",
              desc = "Height of the primary meter window.", min = 50, max = 500, step = 5,
              hidden = damageMeterCustomizationOff,
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "range", key = "damageMeterHeight2", name = "Height (Window 2)",
              desc = "Height of meter window 2.", min = 50, max = 500, step = 5,
              hidden = function() return damageMeterCustomizationOff() or not _G["DamageMeterSessionWindow2"] end,
              get = function() local h = profile().damageMeterHeights; return (h and h[2]) or profile().damageMeterHeight end,
              set = function(value)
                  profile().damageMeterHeights = profile().damageMeterHeights or {}
                  profile().damageMeterHeights[2] = value
                  if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end
              end },
            { type = "range", key = "damageMeterHeight3", name = "Height (Window 3)",
              desc = "Height of meter window 3.", min = 50, max = 500, step = 5,
              hidden = function() return damageMeterCustomizationOff() or not _G["DamageMeterSessionWindow3"] end,
              get = function() local h = profile().damageMeterHeights; return (h and h[3]) or profile().damageMeterHeight end,
              set = function(value)
                  profile().damageMeterHeights = profile().damageMeterHeights or {}
                  profile().damageMeterHeights[3] = value
                  if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end
              end },
            { type = "range", key = "damageMeterScale", name = "Scale",
              desc = "Scale of all meter windows.", min = 0.5, max = 2.0, step = 0.05,
              hidden = damageMeterCustomizationOff,
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "range", key = "damageMeterSpacing", name = "Window Spacing",
              desc = "Spacing between multiple meter windows.", min = -50, max = 50, step = 1,
              hidden = damageMeterCustomizationOff,
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "toggle", key = "damageMeterAnchorBottomRight", name = "Anchor to Bottom Right",
              store = "bool", desc = "Anchor the primary window to the screen's bottom right.",
              hidden = damageMeterCustomizationOff,
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "range", key = "damageMeterAnchorYOffset", name = "Bottom Right Y Offset",
              desc = "Vertical offset from the bottom of the screen.", min = 0, max = 500, step = 1,
              hidden = function() return damageMeterCustomizationOff() or not profile().damageMeterAnchorBottomRight end,
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "select", key = "damageMeterMultiWindowAnchor", name = "Multiple Windows Position",
              desc = "Where to attach secondary windows relative to the primary.",
              hidden = damageMeterCustomizationOff,
              values = { { value = "left", text = "Attach to Left" }, { value = "top", text = "Attach to Top" } },
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "misc",
        title = "Miscellaneous",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        controls = {
            { type = "range", key = "soundAmbienceVolume", name = "Ambience Volume",
              desc = "Ambient sound volume.", min = 0, max = 1, step = 0.1,
              cvar = "Sound_AmbienceVolume" },
            { type = "toggle", key = "autoLootDefault", name = "Auto Loot", store = "int01",
              desc = "Loot automatically by default.", cvar = "autoLootDefault" },
            { type = "toggle", key = "addChatSizes", name = "Extended Chat Font Sizes", store = "bool",
              reload = true, desc = "Add more chat font size options. Requires a reload to take effect." },

            { type = "divider", name = "Hide UI Elements" },
            { type = "toggle", key = "hideSocialButton", name = "Hide Social Button", store = "bool",
              desc = "Hide the Quick Join social button.",
              apply = function() P():ApplyHideSocialButton() end },
            { type = "toggle", key = "hideBagsBar", name = "Hide Bags Bar", store = "bool",
              desc = "Hide the bags bar.",
              apply = function() P():ApplyHideBagsBar() end },

            -- Only shown when the ExtraQuestButton addon is installed.
            { type = "divider", name = "Extra Quest Button", hidden = extraQuestButtonMissing },
            { type = "toggle", key = "anchorExtraQuestButton", name = "Anchor Above Cast Bar",
              store = "bool", reload = true, hidden = extraQuestButtonMissing,
              desc = "This option only appears because the ExtraQuestButton addon is installed. "
                  .. "Anchors its button above the cast bar (between the cast bar and the tracked "
                  .. "bars). Requires a reload to take effect." },
        },
    },
}
