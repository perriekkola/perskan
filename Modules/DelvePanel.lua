-- Today's delves, grouped fastest to slowest.
--
-- Every delve runs one of a handful of story variants, rotating daily, and the variant
-- is what decides how long a clear takes. The panel reads which variant each delve is
-- running right now off its map POI and pairs that with the ratings in
-- Modules/DelveData.lua, so the list answers "which delve do I run today".
--
-- Ported from DelveSpeedTracker v1.2.0 by Bloom. Upstream draws its window with
-- AbstractFramework; this one is a stock ButtonFrameTemplate with stock fonts, colours
-- and highlight art, the way everything else this addon draws is.
--
-- Bind a key to it under Key Bindings -> Perskan's Pack (see Bindings.xml), or use the
-- button in the settings window, or /pp delves.

local addonName, addon = ...

BINDING_HEADER_PERSKAN = "Perskan's Pack"
BINDING_NAME_PERSKAN_TOGGLE_DELVE_PANEL = "Toggle Delve Panel"

local WIDTH = 300
local INSET_TOP = 40   -- clears the title bar; no portrait to clear (see BuildPanel)
local INSET_EDGE = 8   -- inset to panel edge
local INSET_PAD = 8    -- content to inset edge
local ROW_HEIGHT = 20
local SECTION_HEIGHT = 20
local SECTION_GAP = 6
local EMPTY_HEIGHT = 40

local panel
local rowPool, sectionPool = {}, {}
local activeDelves = {}
local lastScan = 0
local SCAN_THROTTLE = 5

-- Set while the panel is hidden by something other than the player, so closing it stays
-- a decision that sticks across a reload while switching the feature off doesn't.
local suppressHideTracking = false

-- The layout walks the ordered tier list; the row tooltips want one tier by name.
local tiersByKey = {}
for _, tier in ipairs(addon.delveTiers) do
    tiersByKey[tier.key] = tier
end

-- Blizzard blocks nothing here, but running these through securecallfunction keeps our
-- taint off the map frame and off the widget layout the POI tooltips share.
local SecureCall = securecallfunction or function(func, ...) return func(...) end

local function profile() return Perskan.db.profile end

--------------------------------------------------------------------------------
-- Text helpers
--------------------------------------------------------------------------------

local function StripCodes(text)
    if not text or text == "" then return "" end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", "")
                :gsub("|r", "")
                :gsub("|cn[%w_]+:", "")
                :gsub("|A:[^|]+|a", "")
                :gsub("|T[^|]+|t", ""))
end

-- Turn a POI widget line into a bare variant name. The story line reads
-- "Story Variant: Ogre Powered" in whatever locale the client runs in, so the prefix is
-- taken off by cutting at the first colon - but only on lines that are plausibly a
-- variant name, since the same widget set also carries the bountiful timer and coffer
-- blurbs, which are full of colons.
local function NormalizeVariantText(text)
    local s = strtrim(StripCodes(text or ""))
    if s == "" then return "" end
    if s:find("|4Min") or s:find("|4Sec") or s:find("\n") or #s > 160 then
        return s
    end
    local afterColon = s:match("^.-:%s*(.+)$")
    if afterColon and afterColon:find("[%a\128-\255]") then
        s = afterColon
    end
    return strtrim(s)
end

-- "Atal'Aman - Ritual Interrupted" -> "Atal'Aman"
local function StripStorySuffix(name)
    if not name or name == "" then return name end
    return strtrim((name:gsub("%s%-%s.+$", "")))
end

--------------------------------------------------------------------------------
-- Localized name lookups
--------------------------------------------------------------------------------

-- Achievement criteria are localized, our variant keys are English. The criteria of a
-- delve's story achievement come back in the same order as its variantOrder, which is
-- what pairs the two up. Achievement data isn't always loaded at login, so the maps are
-- built on demand and thrown away on a world change.
local variantByCriteria, delveByLocalizedName, knownVariants

local function BuildLookups()
    if variantByCriteria then return end
    local criteriaMap, nameMap, variantSet = {}, {}, {}
    local sawCriteria = false

    for delveName, delve in pairs(addon.delves) do
        for variantKey in pairs(delve.variants) do
            variantSet[variantKey] = true
        end

        local numCriteria = GetAchievementNumCriteria and GetAchievementNumCriteria(delve.storyAchievementID) or 0
        for i = 1, numCriteria do
            local criteria = GetAchievementCriteriaInfo(delve.storyAchievementID, i)
            if criteria and criteria ~= "" and delve.variantOrder[i] then
                criteriaMap[strtrim(StripCodes(criteria))] = delve.variantOrder[i]
                sawCriteria = true
            end
        end

        -- The story achievement is titled after the delve, which is how the localized
        -- delve name is recovered without shipping a name table per locale.
        local localizedName = GetAchievementInfo and select(2, GetAchievementInfo(delve.storyAchievementID))
        if localizedName and localizedName ~= "" then
            nameMap[StripStorySuffix(strtrim(StripCodes(localizedName)))] = delveName
        end
    end

    -- Achievement data can still be loading right after login, and a criteria map built
    -- from nothing would be cached as if it were complete. On an enUS client the widget
    -- text already matches the variant keys, so the scan works either way; every other
    -- locale needs the real thing, so leave the maps unbuilt and try again next scan.
    knownVariants = variantSet
    if not sawCriteria then
        delveByLocalizedName = nameMap
        variantByCriteria = nil
        return
    end
    variantByCriteria, delveByLocalizedName = criteriaMap, nameMap
end

local function ResolveVariantKey(text)
    local normalized = NormalizeVariantText(text)
    if normalized == "" then return nil end
    local key = (variantByCriteria and variantByCriteria[normalized])
        or addon.delveVariantAliases[normalized]
        or normalized
    return knownVariants[key] and key or nil
end

local function ResolveDelveName(poiName, mapID)
    local stripped = StripStorySuffix(strtrim(StripCodes(poiName or "")))
    if stripped == "" then return nil end

    for delveName, delve in pairs(addon.delves) do
        if delve.mapID == mapID and StripStorySuffix(delveName) == stripped then
            return delveName
        end
    end

    local byAchievement = delveByLocalizedName and delveByLocalizedName[stripped]
    if byAchievement and addon.delves[byAchievement].mapID == mapID then
        return byAchievement
    end
    return nil
end

--------------------------------------------------------------------------------
-- Scanning
--------------------------------------------------------------------------------

local function ReadWidgetText(widgetID)
    local info = SecureCall(C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo, widgetID)
    if info and info.text and info.text ~= "" then return info.text end
    info = SecureCall(C_UIWidgetManager.GetTextWidgetVisualizationInfo, widgetID)
    if info and info.text and info.text ~= "" then return info.text end
    info = SecureCall(C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo, widgetID)
    if info and info.text and info.text ~= "" then return info.text end
    return nil
end

local function GetVariantFromPOI(poiInfo)
    if not poiInfo.tooltipWidgetSet then return nil end
    local widgets = SecureCall(C_UIWidgetManager.GetAllWidgetsBySetID, poiInfo.tooltipWidgetSet)
    if not widgets then return nil end
    for _, widget in ipairs(widgets) do
        if widget.widgetID then
            local key = ResolveVariantKey(ReadWidgetText(widget.widgetID))
            if key then return key end
        end
    end
    return nil
end

-- Which delve a POI is, preferring its name (exact, and already localized) and falling
-- back to the one delve on this map that runs the variant we just read.
local function IdentifyDelve(poiInfo, mapID, variantKey)
    local delveName = ResolveDelveName(poiInfo.name, mapID)
    if delveName then return delveName end
    if not variantKey then return nil end
    for name, delve in pairs(addon.delves) do
        if delve.mapID == mapID and delve.variants[variantKey] then
            return name
        end
    end
    return nil
end

local function Scan()
    BuildLookups()

    local found, scannedMaps = {}, {}
    for _, delve in pairs(addon.delves) do
        if not scannedMaps[delve.mapID] then
            scannedMaps[delve.mapID] = true
            for _, areaPoiID in ipairs(C_AreaPoiInfo.GetDelvesForMap(delve.mapID) or {}) do
                local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(delve.mapID, areaPoiID)
                if poiInfo then
                    local variantKey = GetVariantFromPOI(poiInfo)
                    local delveName = IdentifyDelve(poiInfo, delve.mapID, variantKey)
                    if delveName and not found[delveName] then
                        local rating = variantKey and addon.delves[delveName].variants[variantKey]
                        if not (rating and addon.delveRatings[rating]) then rating = "?" end
                        local x, y
                        if poiInfo.position then x, y = poiInfo.position:GetXY() end
                        found[delveName] = {
                            delveName = delveName,
                            displayName = StripStorySuffix(strtrim(StripCodes(poiInfo.name or ""))),
                            variantKey = variantKey,
                            rating = rating,
                            priority = addon.delveRatings[rating].priority,
                            tier = addon.delveRatings[rating].tier,
                            mapID = delve.mapID,
                            atlas = poiInfo.atlasName,
                            bountiful = poiInfo.atlasName == "delves-bountiful",
                            x = x,
                            y = y,
                        }
                    end
                end
            end
        end
    end

    local list = {}
    for _, entry in pairs(found) do
        if entry.displayName == "" then entry.displayName = entry.delveName end
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.displayName < b.displayName
    end)
    return list
end

-- Reading POI widgets while the world map is up taints the numbers Blizzard's own POI
-- tooltips lay out with, which surfaces as "secret number value tainted by" errors on
-- hover. The scan only ever runs with the map closed; the panel shows the last one until
-- then, which is fine because the variants only rotate daily.
local function CanScan()
    return not InCombatLockdown() and not (WorldMapFrame and WorldMapFrame:IsShown())
end

local function Refresh(force)
    if not CanScan() then return false end
    local now = GetTime()
    if not force and now - lastScan < SCAN_THROTTLE then return false end
    lastScan = now
    activeDelves = Scan()
    return true
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

local function OpenMapToDelve(row)
    if InCombatLockdown() then return end
    local entry = row.entry
    if not entry then return end

    if not WorldMapFrame:IsShown() then
        SecureCall(ToggleWorldMap)
    end
    SecureCall(WorldMapFrame.SetMapID, WorldMapFrame, entry.mapID)

    if profile().delvePanelWaypoints and entry.x and entry.y
        and TomTom and type(TomTom.AddWaypoint) == "function" then
        TomTom:AddWaypoint(entry.mapID, entry.x, entry.y, {
            title = entry.displayName,
            from = addonName,
            persistent = false,
            silent = true,
        })
    end
end

local function RowOnEnter(row)
    local entry = row.entry
    if not entry then return end

    local tooltip = GetAppropriateTooltip()
    tooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(tooltip, entry.displayName, HIGHLIGHT_FONT_COLOR)

    if entry.variantKey then
        GameTooltip_AddNormalLine(tooltip, entry.variantKey)
    else
        GameTooltip_AddNormalLine(tooltip, "Story variant unknown")
    end
    if entry.bountiful then
        GameTooltip_AddColoredLine(tooltip, "Bountiful", NORMAL_FONT_COLOR)
    end

    local tier = tiersByKey[entry.tier]
    if tier then
        local label = tier.time ~= "" and (tier.name .. " - " .. tier.time) or tier.name
        GameTooltip_AddColoredLine(tooltip, label, tier.color)
    end

    GameTooltip_AddBlankLineToTooltip(tooltip)
    GameTooltip_AddInstructionLine(tooltip, "Click to show it on the world map.")
    tooltip:Show()
end

local function RowOnLeave()
    GetAppropriateTooltip():Hide()
end

local function AcquireRow(index)
    local row = rowPool[index]
    if row then return row end

    row = CreateFrame("Button", nil, panel.Inset)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.5)

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(16, 16)
    row.Icon:SetPoint("LEFT", row, "LEFT", 4, 0)

    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Label:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
    row.Label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.Label:SetJustifyH("LEFT")
    row.Label:SetWordWrap(false)

    row:SetScript("OnClick", OpenMapToDelve)
    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", RowOnLeave)

    rowPool[index] = row
    return row
end

local function AcquireSection(index)
    local section = sectionPool[index]
    if section then return section end

    section = CreateFrame("Frame", nil, panel.Inset)
    section:SetHeight(SECTION_HEIGHT)

    section.Label = section:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    section.Label:SetPoint("LEFT", section, "LEFT", 4, 0)

    section.Time = section:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    section.Time:SetPoint("RIGHT", section, "RIGHT", -4, 0)

    sectionPool[index] = section
    return section
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

local function LayoutPanel()
    if not panel then return end

    for _, row in ipairs(rowPool) do row:Hide() end
    for _, section in ipairs(sectionPool) do section:Hide() end

    local width = WIDTH - 2 * INSET_EDGE - 2 * INSET_PAD
    local y, rowIndex, sectionIndex = -INSET_PAD, 0, 0

    for _, tier in ipairs(addon.delveTiers) do
        local first = true
        for _, entry in ipairs(activeDelves) do
            if entry.tier == tier.key then
                if first then
                    first = false
                    if sectionIndex > 0 then y = y - SECTION_GAP end
                    sectionIndex = sectionIndex + 1
                    local section = AcquireSection(sectionIndex)
                    section:SetWidth(width)
                    section:SetPoint("TOPLEFT", panel.Inset, "TOPLEFT", INSET_PAD, y)
                    section.Label:SetText(tier.name:upper())
                    section.Label:SetTextColor(tier.color:GetRGB())
                    section.Time:SetText(tier.time)
                    section:Show()
                    y = y - SECTION_HEIGHT
                end

                rowIndex = rowIndex + 1
                local row = AcquireRow(rowIndex)
                row:SetWidth(width)
                row:SetPoint("TOPLEFT", panel.Inset, "TOPLEFT", INSET_PAD, y)
                if entry.atlas and C_Texture.GetAtlasInfo(entry.atlas) then
                    row.Icon:SetAtlas(entry.atlas)
                    row.Icon:Show()
                else
                    row.Icon:Hide()
                end
                row.Label:SetText(entry.displayName)
                row.Label:SetTextColor((entry.bountiful and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
                row.entry = entry
                row:Show()
                y = y - ROW_HEIGHT
            end
        end
    end

    local contentHeight
    if rowIndex == 0 then
        panel.EmptyText:SetText(CanScan() and "No delves found."
            or "Close the world map to read today's delves.")
        panel.EmptyText:Show()
        contentHeight = EMPTY_HEIGHT
    else
        panel.EmptyText:Hide()
        contentHeight = -y
    end

    panel:SetHeight(INSET_TOP + contentHeight + INSET_PAD + INSET_EDGE)
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

local function SavePosition()
    local point, _, relativePoint, x, y = panel:GetPoint(1)
    if not point then return end
    local db = profile()
    db.delvePanelPoint = point
    db.delvePanelRelativePoint = relativePoint or point
    db.delvePanelX = math.floor(x + 0.5)
    db.delvePanelY = math.floor(y + 0.5)
end

local function RestorePosition()
    local db = profile()
    panel:ClearAllPoints()
    panel:SetPoint(db.delvePanelPoint or "CENTER", UIParent,
        db.delvePanelRelativePoint or db.delvePanelPoint or "CENTER",
        db.delvePanelX or 0, db.delvePanelY or 0)
end

local function BuildPanel()
    if panel then return panel end

    panel = CreateFrame("Frame", addonName .. "DelvePanel", UIParent, "ButtonFrameTemplate")
    panel:SetSize(WIDTH, 200)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    panel:SetFrameStrata("MEDIUM")
    panel:Hide()

    tinsert(UISpecialFrames, panel:GetName())

    if panel.SetTitle then
        panel:SetTitle("Delves")
    end
    -- No portrait. ButtonFrameTemplate's portrait is a plain square texture sitting
    -- behind a ring, so it wants opaque art the way an icon file is: the delve map
    -- atlas is transparent around the archway, which left the panel's own inset and
    -- the world behind it showing through the circle. The chat copy window drops the
    -- portrait the same way.
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(panel)
    end

    panel.Inset:ClearAllPoints()
    panel.Inset:SetPoint("TOPLEFT", panel, "TOPLEFT", INSET_EDGE, -INSET_TOP)
    panel.Inset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -INSET_EDGE, INSET_EDGE)

    panel.EmptyText = panel.Inset:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    panel.EmptyText:SetPoint("TOPLEFT", panel.Inset, "TOPLEFT", INSET_PAD, -INSET_PAD)
    panel.EmptyText:SetPoint("TOPRIGHT", panel.Inset, "TOPRIGHT", -INSET_PAD, -INSET_PAD)
    panel.EmptyText:SetJustifyH("LEFT")
    panel.EmptyText:Hide()

    panel:SetScript("OnShow", function()
        Refresh()
        LayoutPanel()
    end)

    -- Closing it - with the template's X button or with Escape - is a decision, so the
    -- panel stays closed on the next login. Hides the addon itself does aren't.
    panel:HookScript("OnHide", function()
        if not suppressHideTracking then
            profile().delvePanelShown = false
        end
    end)

    RestorePosition()
    return panel
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Perskan:ToggleDelvePanel()
    if not self.db.profile.delvePanelEnabled then
        self:Print("The delve panel is switched off in " .. addonName .. "'s settings.")
        return
    end

    BuildPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        self.db.profile.delvePanelShown = true
        self:ApplyDelvePanel()
    end
end

-- Live-apply for the settings window and for a profile switch.
function Perskan:ApplyDelvePanel()
    local shown = self.db.profile.delvePanelEnabled and self.db.profile.delvePanelShown
    if not shown then
        if panel and panel:IsShown() then
            suppressHideTracking = true
            panel:Hide()
            suppressHideTracking = false
        end
        return
    end

    BuildPanel()
    RestorePosition()
    panel:SetScale(self.db.profile.delvePanelScale or 1)
    panel:Show()
    LayoutPanel()
end

function Perskan:RefreshDelvePanel(force)
    if not panel or not panel:IsShown() then return end
    if Refresh(force) then
        LayoutPanel()
    end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

Perskan:RegisterModule("DelvePanel", function(self)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("AREA_POIS_UPDATED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Achievement criteria and POI data are both still settling at this point.
            variantByCriteria = nil
            lastScan = 0
            C_Timer.After(2, function() Perskan:RefreshDelvePanel(true) end)
        else
            Perskan:RefreshDelvePanel()
        end
    end)

    -- The scan is blocked while the map is up (see CanScan), so take the first chance
    -- after it closes.
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnHide", function()
            Perskan:RefreshDelvePanel(true)
        end)
    end

    if self.db.profile.delvePanelEnabled and self.db.profile.delvePanelShown then
        self:ApplyDelvePanel()
    end
end)
