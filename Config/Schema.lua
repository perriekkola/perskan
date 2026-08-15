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

-- Simple Item Level keeps its own account-wide saved variables (see Modules/ItemLevel.lua),
-- so its controls read and write there instead of the profile. Options that have never been
-- changed resolve to upstream's defaults, which is what keeps this identical to running the
-- standalone addon.
local function ilvl(control)
    control.get = function() return P():GetItemLevelOption(control.key) end
    control.set = function(value) P():SetItemLevelOption(control.key, value) end
    return control
end

local ILVL_POSITIONS = {
    { value = "TOPLEFT", text = "Top Left" },
    { value = "TOP", text = "Top" },
    { value = "TOPRIGHT", text = "Top Right" },
    { value = "LEFT", text = "Left" },
    { value = "CENTER", text = "Center" },
    { value = "RIGHT", text = "Right" },
    { value = "BOTTOMLEFT", text = "Bottom Left" },
    { value = "BOTTOM", text = "Bottom" },
    { value = "BOTTOMRIGHT", text = "Bottom Right" },
}

-- Anchor point/offsets only mean anything once the window is pinned to the screen.
local function damageMeterAnchorOff()
    return damageMeterCustomizationOff() or not profile().damageMeterAnchorEnabled
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
              desc = "Size of buff/debuff icons on the target and focus frames. Applies to "
                  .. "every aura, including your own (Blizzard draws those larger by default).",
              min = 10, max = 40, step = 1,
              apply = function() P():ApplyTargetFocusAuraSize() end },
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

            { type = "divider", name = "Grey On Cooldown" },
            { type = "toggle", key = "greyOnCooldown", name = "Grey Icons On Cooldown", store = "bool",
              desc = "Desaturate an action button's icon while its ability is on cooldown. "
                  .. "The global cooldown is ignored. Replaces the GreyOnCooldown addon.",
              apply = function() P():ApplyGreyOnCooldown() end },
            { type = "toggle", key = "greyOnCooldownUnusable", name = "Grey Unusable Actions", store = "bool",
              desc = "Also desaturate actions you can't use right now (out of range, no target, "
                  .. "wrong form).",
              disabled = function() return not profile().greyOnCooldown end,
              apply = function() P():ApplyGreyOnCooldown() end },
            { type = "toggle", key = "greyOnCooldownNoResources", name = "Grey Actions Without Resources",
              store = "bool", desc = "Also desaturate actions you lack the mana/rage/energy for.",
              disabled = function() return not profile().greyOnCooldown end,
              apply = function() P():ApplyGreyOnCooldown() end },
            { type = "toggle", key = "greyOnCooldownPetBar", name = "Include Pet Bar", store = "bool",
              desc = "Apply the same greying to pet action buttons.",
              disabled = function() return not profile().greyOnCooldown end,
              apply = function() P():ApplyGreyOnCooldown() end },

            { type = "divider", name = "Range & Resources" },
            { type = "toggle", key = "rangeColoring", name = "Colour By Range And Resources",
              store = "bool",
              desc = "Tint action icons red when the target is out of range and blue when "
                  .. "you're short on power. Replaces the tullaRange addon.",
              apply = function() P():ApplyRangeColoring() end },
            { type = "toggle", key = "rangeColoringHotkeys", name = "Colour Hotkey Text",
              store = "bool", desc = "Tint the hotkey text red as well when out of range.",
              disabled = function() return not profile().rangeColoring end,
              apply = function() P():ApplyRangeColoring() end },
            { type = "toggle", key = "rangeColoringPetBar", name = "Include Pet Bar",
              store = "bool", desc = "Apply the same colouring to pet action buttons.",
              disabled = function() return not profile().rangeColoring end,
              apply = function() P():ApplyRangeColoring() end },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "vendor",
        title = "Vendor",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        controls = {
            { type = "toggle", key = "extendedVendor", name = "Bigger Merchant Window",
              store = "bool",
              desc = "Show more of a vendor's stock at once instead of Blizzard's ten items "
                  .. "per page.",
              apply = function() P():ApplyVendorLayout() end },
            { type = "range", key = "vendorColumns", name = "Columns",
              desc = "Columns of items. Blizzard's default is 2.", min = 2, max = 6, step = 1,
              disabled = function() return not profile().extendedVendor end,
              apply = function() P():ApplyVendorLayout() end },
            { type = "range", key = "vendorRows", name = "Rows",
              desc = "Rows of items. Blizzard's default is 5.", min = 5, max = 10, step = 1,
              disabled = function() return not profile().extendedVendor end,
              apply = function() P():ApplyVendorLayout() end },
            { type = "toggle", key = "vendorSearch", name = "Search Box", store = "bool",
              desc = "Add a search box to the merchant window. Items that don't match dim "
                  .. "rather than disappear, so buying stays exactly as Blizzard handles it.",
              disabled = function() return not profile().extendedVendor end,
              apply = function() P():ApplyVendorLayout() end },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "itemlevel",
        title = "Item Levels",
        icon = "Interface\\Icons\\INV_Chest_Plate04",
        controls = {
            { type = "divider", name = "Where To Show" },
            ilvl{ type = "toggle", key = "bags", name = "Bags", store = "bool" },
            ilvl{ type = "toggle", key = "character", name = "Character Frame", store = "bool" },
            ilvl{ type = "toggle", key = "character_inset", name = "Inside The Character Frame",
                  store = "bool", desc = "Place the level inside the frame instead of over the item.",
                  disabled = function() return not P():GetItemLevelOption("character") end },
            ilvl{ type = "toggle", key = "flyout", name = "Equipment Flyouts", store = "bool" },
            ilvl{ type = "toggle", key = "inspect", name = "Inspect Frame", store = "bool" },
            ilvl{ type = "toggle", key = "inspect_inset", name = "Inside The Inspect Frame",
                  store = "bool", desc = "Place the level inside the frame instead of over the item.",
                  disabled = function() return not P():GetItemLevelOption("inspect") end },
            ilvl{ type = "toggle", key = "loot", name = "Loot Windows", store = "bool" },
            ilvl{ type = "toggle", key = "tooltip", name = "Item Tooltips", store = "bool",
                  desc = "Add the item level to tooltips." },
            ilvl{ type = "toggle", key = "characteravg", name = "Character Average Item Level",
                  store = "bool" },
            ilvl{ type = "toggle", key = "inspectavg", name = "Inspect Average Item Level",
                  store = "bool" },

            { type = "divider", name = "Which Items" },
            ilvl{ type = "toggle", key = "equipment", name = "Equippable Items", store = "bool" },
            ilvl{ type = "toggle", key = "battlepets", name = "Battle Pets", store = "bool" },
            ilvl{ type = "toggle", key = "reagents", name = "Crafting Reagents", store = "bool" },
            ilvl{ type = "toggle", key = "misc", name = "Anything Else", store = "bool" },
            ilvl{ type = "select", key = "quality", name = "Minimum Item Quality",
                  desc = "Items below this quality are left alone.",
                  values = {
                      { value = 0, text = "Poor" },
                      { value = 1, text = "Common" },
                      { value = 2, text = "Uncommon" },
                      { value = 3, text = "Rare" },
                      { value = 4, text = "Epic" },
                      { value = 5, text = "Legendary" },
                      { value = 6, text = "Artifact" },
                      { value = 7, text = "Heirloom" },
                  } },

            { type = "divider", name = "What To Show" },
            ilvl{ type = "toggle", key = "itemlevel", name = "Item Level", store = "bool" },
            ilvl{ type = "toggle", key = "upgrades", name = "Flag Upgrades", store = "bool" },
            ilvl{ type = "toggle", key = "missinggems", name = "Flag Missing Gems", store = "bool" },
            ilvl{ type = "toggle", key = "missingenchants", name = "Flag Missing Enchants",
                  store = "bool" },
            ilvl{ type = "toggle", key = "missingcharacter", name = "Only On The Character Frame",
                  store = "bool", desc = "Restrict the missing gem/enchant flags to the character frame." },
            ilvl{ type = "toggle", key = "bound", name = "Flag Soulbound Items", store = "bool",
                  desc = "Only on items you control: bags and the character frame." },
            ilvl{ type = "toggle", key = "color", name = "Colour By Item Quality", store = "bool" },

            { type = "divider", name = "Appearance" },
            ilvl{ type = "select", key = "font", name = "Font",
                  values = {
                      { value = "NumberNormal", text = "Number" },
                      { value = "NumberNormalSmall", text = "Number (Small)" },
                      { value = "HighlightSmall", text = "Highlight (Small)" },
                      { value = "Normal", text = "Normal" },
                      { value = "Large", text = "Large" },
                      { value = "Huge", text = "Huge" },
                  } },
            ilvl{ type = "select", key = "position", name = "Item Level Position",
                  values = ILVL_POSITIONS },
            ilvl{ type = "select", key = "positionup", name = "Upgrade Flag Position",
                  values = ILVL_POSITIONS },
            ilvl{ type = "range", key = "scaleup", name = "Upgrade Flag Size",
                  min = 0.5, max = 3, step = 0.1 },
            ilvl{ type = "select", key = "positionmissing", name = "Missing Flag Position",
                  values = ILVL_POSITIONS },
            ilvl{ type = "select", key = "positionbound", name = "Soulbound Flag Position",
                  values = ILVL_POSITIONS },
            ilvl{ type = "range", key = "scalebound", name = "Soulbound Flag Size",
                  min = 0.5, max = 3, step = 0.1 },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "keybindings",
        title = "Key Bindings",
        icon = "Interface\\Icons\\INV_Misc_Key_03",
        controls = {
            { type = "toggle", key = "bindPadEnabled", name = "Enable BindPad", store = "bool",
              reload = true,
              desc = "BindPad's keybinding pad: drag a spell, item or macro into a slot and "
                  .. "click it to bind a key. Bindings are applied at login, so switching this "
                  .. "on or off needs a reload.",
              apply = function() P():ApplyBindPad() end },
            { type = "button", name = "Open BindPad", width = 220,
              onClick = function() P():OpenBindPad() end,
              disabled = function() return not profile().bindPadEnabled end },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "chat",
        title = "Chat",
        icon = "Interface\\Icons\\INV_Letter_15",
        controls = {
            { type = "toggle", key = "chatCopyButton", name = "Chat Copy Button", store = "bool",
              desc = "Show a copy button in the bottom right of a chat window while the mouse "
                  .. "is over it. Replaces the ChatCopyPaste addon.",
              apply = function() P():ApplyChatCopyButton() end },
            { type = "range", key = "chatCopyMaxLines", name = "Max Lines Copied",
              desc = "How many lines of history the copy window shows.", min = 50, max = 1000, step = 10,
              disabled = function() return not profile().chatCopyButton end },
            { type = "toggle", key = "chatDisableFade", name = "Disable Chat Fade", store = "bool",
              desc = "Stop chat text fading out when you haven't hovered the window for a while.",
              apply = function() P():ApplyChatFade() end },

            { type = "divider", name = "Links" },
            { type = "toggle", key = "chatUrlLinks", name = "Clickable URLs", store = "bool",
              desc = "Turn website addresses in chat into clickable links that open the copy "
                  .. "window with the URL selected." },
            { type = "color", key = "chatUrlColor", name = "URL Colour",
              desc = "Colour used to highlight URLs in chat.",
              disabled = function() return not profile().chatUrlLinks end },

            { type = "divider", name = "Font Sizes" },
            { type = "toggle", key = "addChatSizes", name = "Extended Chat Font Sizes", store = "bool",
              reload = true, desc = "Add more chat font size options. Requires a reload to take effect." },
        },
    },
    --------------------------------------------------------------------------------
    {
        key = "map",
        title = "Map",
        icon = "Interface\\Icons\\INV_Misc_Map02",
        controls = {
            { type = "toggle", key = "showDelvesOnContinentMap", name = "Show Delves On Continent Map",
              store = "bool",
              desc = "Roll every zone's delve entrances up onto the continent map. Blizzard's "
                  .. "own Delves map filter still applies.",
              apply = function() P():ApplyDelveMapPins() end },
            { type = "toggle", key = "delvesBountifulOnly", name = "Bountiful Delves Only",
              store = "bool",
              desc = "Only show bountiful delves. Same setting as the checkbox in the map's "
                  .. "tracking menu.",
              disabled = function() return not profile().showDelvesOnContinentMap end,
              apply = function() P():ApplyDelveMapPins() end },
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
              store = "bool",
              desc = "Stack active tracked bars upward from the bottom of the viewer, without gaps.",
              apply = function() P():ApplySortBuffBars() end },
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
            { type = "divider", name = "Position", hidden = damageMeterCustomizationOff },
            { type = "toggle", key = "damageMeterAnchorEnabled", name = "Anchor to Screen",
              store = "bool", desc = "Pin the primary window to a screen position instead of "
                  .. "leaving it where Blizzard put it.",
              hidden = damageMeterCustomizationOff,
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "select", key = "damageMeterAnchorPoint", name = "Anchor Point",
              desc = "Which part of the screen the window is pinned to.",
              hidden = damageMeterAnchorOff,
              values = {
                  { value = "TOPLEFT", text = "Top Left" },
                  { value = "TOP", text = "Top" },
                  { value = "TOPRIGHT", text = "Top Right" },
                  { value = "LEFT", text = "Left" },
                  { value = "CENTER", text = "Center" },
                  { value = "RIGHT", text = "Right" },
                  { value = "BOTTOMLEFT", text = "Bottom Left" },
                  { value = "BOTTOM", text = "Bottom" },
                  { value = "BOTTOMRIGHT", text = "Bottom Right" },
              },
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "range", key = "damageMeterAnchorXOffset", name = "X Offset",
              desc = "Horizontal offset from the anchor point. Negative moves left.",
              min = -1000, max = 1000, step = 1,
              hidden = damageMeterAnchorOff,
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "range", key = "damageMeterAnchorYOffset", name = "Y Offset",
              desc = "Vertical offset from the anchor point. Negative moves down.",
              min = -1000, max = 1000, step = 1,
              hidden = damageMeterAnchorOff,
              apply = function() if P().ApplyDamageMeterSettings then P().ApplyDamageMeterSettings() end end },
            { type = "select", key = "damageMeterMultiWindowAnchor", name = "Multiple Windows Position",
              desc = "Which side of the primary window secondary windows stack on.",
              hidden = damageMeterCustomizationOff,
              values = {
                  { value = "left", text = "Attach to Left" },
                  { value = "right", text = "Attach to Right" },
                  { value = "top", text = "Attach to Top" },
                  { value = "bottom", text = "Attach to Bottom" },
              },
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
