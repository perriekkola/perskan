-- Zone level range and fishing skill under the zone name on the world map (WoW Forever).
--
-- Hovering a zone on a continent map makes Blizzard's area label print the zone's name
-- at the top of the map. This adds a line or two under it: the zone's recommended level
-- range, coloured against the player's level, and the fishing skill needed to fish there
-- without anything getting away, coloured against the player's own fishing skill.
--
-- Drawn on our own frame and fontstring and driven by our own poll while the map is
-- open, deliberately. Blizzard's label frame is only read - its text and visibility, to
-- know a zone name is up and where to sit - never written to or hooked, so nothing of
-- ours lands in the map canvas's own execution.
--
-- The data below is the Classic zone table and is meant to be tuned from experience,
-- like Modules/DelveData.lua: the Forever client may shift a range here and there.
-- Zones are keyed by Classic uiMapID with the English name as a fallback, in case the
-- client numbers its maps differently.

--------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------

-- Fishing skill needed to fish a zone without any getaways is its zone fishing level
-- plus this. Below the zone level itself nothing bites at all.
local FISHING_NO_GETAWAY_BONUS = 95

-- { name, minLevel, maxLevel, fishingZoneLevel }. Cities carry no level range; zones
-- without fishable water carry no fishing level.
local ZONES = {
    -- Eastern Kingdoms
    [1429] = { "Elwynn Forest", 1, 10, -70 },
    [1426] = { "Dun Morogh", 1, 10, -70 },
    [1420] = { "Tirisfal Glades", 1, 10, -70 },
    [1436] = { "Westfall", 10, 20, -20 },
    [1432] = { "Loch Modan", 10, 20, -20 },
    [1421] = { "Silverpine Forest", 10, 20, -20 },
    [1433] = { "Redridge Mountains", 15, 25, -20 },
    [1431] = { "Duskwood", 18, 30, 55 },
    [1424] = { "Hillsbrad Foothills", 20, 30, 55 },
    [1437] = { "Wetlands", 20, 30, 55 },
    [1416] = { "Alterac Mountains", 30, 40, 130 },
    [1417] = { "Arathi Highlands", 30, 40, 130 },
    [1434] = { "Stranglethorn Vale", 30, 45, 130 },
    [1418] = { "Badlands", 35, 45 },
    [1435] = { "Swamp of Sorrows", 35, 45, 130 },
    [1425] = { "The Hinterlands", 40, 50, 205 },
    [1427] = { "Searing Gorge", 43, 50 },
    [1419] = { "Blasted Lands", 45, 55 },
    [1428] = { "Burning Steppes", 50, 58, 330 },
    [1422] = { "Western Plaguelands", 51, 58, 205 },
    [1423] = { "Eastern Plaguelands", 53, 60, 330 },
    [1430] = { "Deadwind Pass", 55, 60, 330 },
    [1453] = { "Stormwind City", nil, nil, -20 },
    [1455] = { "Ironforge", nil, nil, -20 },
    [1458] = { "Undercity", nil, nil, -20 },

    -- Kalimdor
    [1438] = { "Teldrassil", 1, 10, -70 },
    [1411] = { "Durotar", 1, 10, -70 },
    [1412] = { "Mulgore", 1, 10, -70 },
    [1439] = { "Darkshore", 10, 20, -20 },
    [1413] = { "The Barrens", 10, 25, -20 },
    [1442] = { "Stonetalon Mountains", 15, 27, 55 },
    [1440] = { "Ashenvale", 18, 30, 55 },
    [1441] = { "Thousand Needles", 25, 35, 130 },
    [1443] = { "Desolace", 30, 40, 130 },
    [1445] = { "Dustwallow Marsh", 35, 45, 130 },
    [1444] = { "Feralas", 40, 50, 205 },
    [1446] = { "Tanaris", 40, 50, 205 },
    [1447] = { "Azshara", 45, 55, 205 },
    [1449] = { "Un'Goro Crater", 48, 55, 205 },
    [1448] = { "Felwood", 48, 55, 205 },
    [1450] = { "Moonglade", 55, 60, 205 },
    [1452] = { "Winterspring", 53, 60, 330 },
    [1451] = { "Silithus", 55, 60, 330 },
    [1457] = { "Darnassus", nil, nil, -20 },
    [1454] = { "Orgrimmar", nil, nil, -20 },
    [1456] = { "Thunder Bluff", nil, nil, -20 },
}

-- Zones Forever added. Their uiMapIDs aren't known, so these are matched by name only
-- (and so only on English clients until someone fills the IDs in). Ranges are what the
-- guides agreed on at launch, and fishing is left out where they didn't agree.
--   Riverglades: 35-45. The client lets anything bite there for now (forever-bugs
--     issue 189); 130 is the zone level that issue expects - 225 for no getaways, the
--     same as Stranglethorn.
--   Mount Hyjal: 55-60 in the Group Finder. No reliable fishing level yet.
--   Shen'dralas: guides say 38-43 or 40-45; 40-45 used. No fishing level yet.
--   Zephras Isle: the Skyborne starting island, 1-12, starter-zone fishing.
local NAMED_ZONES = {
    { "The Riverglades", 35, 45, 130 },
    { "Mount Hyjal", 55, 60 },
    { "Shen'dralas", 40, 45 },
    { "Zephras Isle", 1, 12, -70 },
}

local ZONES_BY_NAME = {}
for _, zone in pairs(ZONES) do
    ZONES_BY_NAME[zone[1]] = zone
end
for _, zone in ipairs(NAMED_ZONES) do
    ZONES_BY_NAME[zone[1]] = zone
end

-- "The Riverglades" and "Riverglades" are both in use; match either form of a name.
local function ZoneByName(name)
    local zone = ZONES_BY_NAME[name]
    if zone then return zone end
    local bare = name:match("^The (.+)$")
    if bare then return ZONES_BY_NAME[bare] end
    return ZONES_BY_NAME["The " .. name]
end

local FISHING_SPELL_ID = 7620

--------------------------------------------------------------------------------
-- Lookups
--------------------------------------------------------------------------------

local function profile() return Perskan.db.profile end

local function Enabled()
    local p = profile()
    return p.mapZoneLevels or p.mapZoneFishing
end

local function FishingSkillName()
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(FISHING_SPELL_ID)
    end
    return GetSpellInfo and (GetSpellInfo(FISHING_SPELL_ID))
end

-- The player's fishing skill, or nil when it can't be read: not learned, or sitting under
-- a collapsed header in the skills list. Read once per map open; it moves slowly.
local function PlayerFishingSkill()
    if not (GetNumSkillLines and GetSkillLineInfo) then return end
    local fishing = FishingSkillName()
    if not fishing then return end
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank = GetSkillLineInfo(i)
        if not isHeader and name == fishing then
            return rank
        end
    end
end

local function LevelColor(minLevel, maxLevel)
    if not GetQuestDifficultyColor then return HIGHLIGHT_FONT_COLOR end
    local level = UnitLevel("player")
    local reference = level
    if level < minLevel then
        reference = minLevel
    elseif level > maxLevel then
        reference = maxLevel
    end
    local c = GetQuestDifficultyColor(reference)
    return CreateColor(c.r, c.g, c.b)
end

local function FishingColor(required, zoneLevel, skill)
    if not skill then return HIGHLIGHT_FONT_COLOR end
    if skill >= required then return GREEN_FONT_COLOR end
    if skill >= zoneLevel then return YELLOW_FONT_COLOR end
    return RED_FONT_COLOR
end

--------------------------------------------------------------------------------
-- Display
--------------------------------------------------------------------------------

local display, text, blizzardLabel
local fishingSkill
local lastKey

-- AreaLabelDataProvider keeps its label frame as `.Label`, with `Name` and
-- `Description` fontstrings. Found by shape rather than by mixin, and only read.
local function FindBlizzardLabel()
    if blizzardLabel then return blizzardLabel end
    local providers = WorldMapFrame and WorldMapFrame.dataProviders
    if not providers then return end
    for provider in pairs(providers) do
        local label = type(provider) == "table" and provider.Label
        if type(label) == "table" and label.Name and label.Name.GetText then
            blizzardLabel = label
            return label
        end
    end
end

local function StripCodes(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function BuildText(zone, mapID, labelText)
    local p = profile()
    local lines = {}

    -- Some clients already append "(min-max)" to the name; don't say it twice.
    if p.mapZoneLevels and not labelText:find("%(%d+%s*%-%s*%d+%)") then
        local minLevel, maxLevel = zone and zone[2], zone and zone[3]
        if not minLevel and C_Map.GetMapLevels then
            local lo, hi = C_Map.GetMapLevels(mapID)
            if lo and hi and lo > 0 and hi > 0 then minLevel, maxLevel = lo, hi end
        end
        if minLevel and maxLevel then
            lines[#lines + 1] = LevelColor(minLevel, maxLevel):WrapTextInColorCode(
                ("Level %d-%d"):format(minLevel, maxLevel))
        end
    end

    local zoneLevel = zone and zone[4]
    if p.mapZoneFishing and zoneLevel then
        local required = math.max(1, zoneLevel + FISHING_NO_GETAWAY_BONUS)
        lines[#lines + 1] = FishingColor(required, zoneLevel, fishingSkill):WrapTextInColorCode(
            ("Fishing %d"):format(required))
    end

    return table.concat(lines, "\n")
end

local cleared = true

local function Clear()
    if cleared then return end
    cleared = true
    if text then text:SetText("") end
    lastKey = nil
end

local function Update()
    local label = FindBlizzardLabel()
    if not label or not label:IsVisible() then return Clear() end

    local labelText = label.Name:GetText()
    if not labelText or labelText == "" then return Clear() end

    local map = WorldMapFrame
    local focused
    if map.IsCanvasMouseFocus then
        focused = map:IsCanvasMouseFocus()
    else
        focused = map:IsMouseOver()
    end
    if not focused then return Clear() end
    local x, y = map:GetNormalizedCursorPosition()
    if not x then return Clear() end
    local mapID = map:GetMapID()
    local info = mapID and C_Map.GetMapInfoAtPosition(mapID, x, y)
    if not info or info.mapID == mapID or not info.name then return Clear() end

    -- The label also names POIs, dungeons and the like; only add to it while it is
    -- showing the zone under the cursor.
    local plain = StripCodes(labelText)
    if not plain:find(info.name, 1, true) then return Clear() end

    local key = info.mapID .. "\0" .. labelText
    if key == lastKey then return end
    lastKey = key
    cleared = false

    local zone = ZONES[info.mapID] or ZoneByName(info.name)
    text:SetText(BuildText(zone, info.mapID, labelText))

    -- Sit under the description when Blizzard shows one, otherwise under the name.
    local below = label.Name
    local desc = label.Description
    if desc and desc.IsShown and desc:IsShown() and (desc:GetText() or "") ~= "" then
        below = desc
    end
    text:ClearAllPoints()
    text:SetPoint("TOP", below, "BOTTOM", 0, -4)
    display:SetFrameStrata(label:GetFrameStrata())
    display:SetFrameLevel(label:GetFrameLevel() + 1)
end

local function Build()
    if display or not WorldMapFrame then return end

    display = CreateFrame("Frame", nil, WorldMapFrame)
    display:SetAllPoints()
    -- Never steal the map's clicks or hover.
    display:EnableMouse(false)

    text = display:CreateFontString(nil, "OVERLAY")
    local font = _G.SystemFont_Shadow_Large_Outline or _G.GameFontHighlightLarge
    text:SetFontObject(font)
    text:SetJustifyH("CENTER")
    text:SetSpacing(2)

    display:SetScript("OnShow", function()
        fishingSkill = PlayerFishingSkill()
        cleared = false
        Clear()
    end)
    display:SetScript("OnUpdate", Update)
end

function Perskan:ApplyMapZoneInfo()
    if not self:IsForeverClient() then return end
    Build()
    if not display then return end
    cleared = false
    Clear()
    display:SetShown(Enabled() and true or false)
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

Perskan:RegisterModule("MapZoneInfo", function(self)
    if not self:IsForeverClient() then return end

    if WorldMapFrame then
        self:ApplyMapZoneInfo()
        return
    end

    -- The world map may be load-on-demand; build once it arrives.
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(frame, _, name)
        if name == "Blizzard_WorldMap" then
            frame:UnregisterAllEvents()
            Perskan:ApplyMapZoneInfo()
        end
    end)
end)
