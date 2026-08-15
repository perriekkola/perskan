-- Show delve entrances from the zone maps on the continent map, so the whole
-- continent's delves are visible at a glance instead of one zone at a time.
--
-- Ported from DelverView v12 by Kemayo. Pins are placed with the embedded
-- HereBeDragons-Pins-2.0 (BSD), which handles the world map canvas for us.
--
-- Blizzard's own "Delves" map filter still wins: with showDelveEntrancesOnMap off,
-- nothing is drawn. The "bountiful only" filter is both a setting here and a checkbox
-- in the map's tracking menu, sharing one profile key.

local addonName = ...
local HBDP = LibStub and LibStub("HereBeDragons-Pins-2.0", true)

local DELVE_CVAR = "showDelveEntrancesOnMap"

-- Only continent maps get the roll-up, sourced from their zone children.
local VALID_MAP_TYPES = { [Enum.UIMapType.Continent] = true }
local VALID_CHILD_MAP_TYPES = { [Enum.UIMapType.Zone] = true }

-- Zones whose delves live on a grandchild map that still has a rect on the continent.
local EXTRA_CHILDREN = {
    [2274] = { -- Khaz Algar
        2339, -- Dornogal (a child of Isle of Dorn)
        2346, -- Undermine (a child of The Ringing Deeps)
    },
}

-- Bountiful delves rotate; the per-continent lookup is cheap to rebuild now and then.
local parentDelveCache = {}
C_Timer.NewTicker(600, function() wipe(parentDelveCache) end)

--------------------------------------------------------------------------------
-- Pins
--------------------------------------------------------------------------------

local PinMixin = {}

function PinMixin:OnLoad()
    self:SetSize(28, 28)
    if not InCombatLockdown() then
        self:SetPassThroughButtons("LeftButton", "RightButton", "MiddleButton", "Button4", "Button5")
    end

    self.texture = self:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints()

    self:SetScript("OnEnter", self.OnMouseEnter)
    self:SetScript("OnLeave", self.OnMouseLeave)
end

function PinMixin:OnAcquire(info)
    self.poiInfo = info
    self.areaPoiID = info.areaPoiID
    self.name = info.name
    self.description = info.description
    self.tooltipWidgetSet = info.tooltipWidgetSet
    self.texture:SetAtlas(info.atlasName)
end

-- Pull the story variant and the bountiful blurb out of the POI's widget set, the
-- same data the stock tooltip shows.
local function ExtractWidgetInfo(widgetSetID)
    local widgets = widgetSetID and C_UIWidgetManager.GetAllWidgetsBySetID(widgetSetID)
    if not widgets then return end

    local variant, description
    for _, widget in ipairs(widgets) do
        if widget.widgetType == Enum.UIWidgetVisualizationType.TextWithState then
            local info = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widget.widgetID)
            -- orderIndex 0 is the variant line, 1 is the coffer-key/timer description.
            if info and info.orderIndex == 0 then
                variant = info.text
            elseif info and info.orderIndex == 1 then
                description = info.text
            end
        end
    end
    return variant, description
end

function PinMixin:OnMouseEnter()
    local tooltip = GetAppropriateTooltip()
    tooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(tooltip, self.name, HIGHLIGHT_FONT_COLOR)

    if self.description and self.description ~= "" then
        GameTooltip_AddNormalLine(tooltip, self.description)
    end

    -- GameTooltip_AddWidgetSet trips over secret values on these pins, so the two
    -- lines worth having are read out by hand instead.
    local variant, description = ExtractWidgetInfo(self.tooltipWidgetSet)
    if variant then
        tooltip:AddLine(variant)
    end
    if description then
        GameTooltip_AddColoredLine(tooltip, description, NORMAL_FONT_COLOR, true)
    end

    tooltip:Show()
end

function PinMixin:OnMouseLeave()
    GetAppropriateTooltip():Hide()
end

local pool = CreateFramePool(
    "Frame", nil, nil,
    function(_, frame) frame.texture:SetVertexColor(1, 1, 1, 1) end,
    nil,
    function(frame)
        Mixin(frame, PinMixin)
        frame:OnLoad()
    end
)

--------------------------------------------------------------------------------
-- Map data
--------------------------------------------------------------------------------

local function GetMapChildren(mapID)
    local children = C_Map.GetMapChildrenInfo(mapID) or {}
    for _, childID in ipairs(EXTRA_CHILDREN[mapID] or {}) do
        local info = C_Map.GetMapInfo(childID)
        if info then
            table.insert(children, info)
        end
    end
    return children
end

-- Delves on a zone map, minus any the continent map already shows itself (the same
-- delve appears on both when it's a continent-level POI).
local function GetDelvesForChildMap(mapInfo, parentMapID)
    if not parentDelveCache[parentMapID] then
        local seen = {}
        for _, delveID in ipairs(C_AreaPoiInfo.GetDelvesForMap(parentMapID)) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(parentMapID, delveID)
            if info then
                seen[info.name] = delveID
            end
        end
        parentDelveCache[parentMapID] = seen
    end
    local parentDelves = parentDelveCache[parentMapID]

    local bountifulOnly = Perskan.db.profile.delvesBountifulOnly
    local delves = {}
    for _, delveID in ipairs(C_AreaPoiInfo.GetDelvesForMap(mapInfo.mapID)) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(mapInfo.mapID, delveID)
        if info and (info.atlasName == "delves-bountiful" or not bountifulOnly)
            and not parentDelves[info.name] then
            delves[delveID] = info
        end
    end
    return delves
end

local function RefreshMapPins(mapID)
    if not (HBDP and C_AreaPoiInfo and C_AreaPoiInfo.GetDelvesForMap) then return end
    if not mapID then return end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not (mapInfo and VALID_MAP_TYPES[mapInfo.mapType]) then return end

    pool:ReleaseAll()
    HBDP:RemoveAllWorldMapIcons(addonName)

    if not Perskan.db.profile.showDelvesOnContinentMap then return end
    if not C_CVar.GetCVarBool(DELVE_CVAR) then return end

    for _, childInfo in ipairs(GetMapChildren(mapID)) do
        if VALID_CHILD_MAP_TYPES[childInfo.mapType] then
            -- Where the zone sits on the continent, so zone-local coordinates can be
            -- projected onto the continent map.
            local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(childInfo.mapID, mapID)
            if minX then
                for _, info in pairs(GetDelvesForChildMap(childInfo, mapID)) do
                    local x, y = info.position:GetXY()
                    local tx, ty = Lerp(minX, maxX, x), Lerp(minY, maxY, y)

                    local pin = pool:Acquire()
                    pin:OnAcquire(info)
                    pin.originalMapID = childInfo.mapID

                    HBDP:AddWorldMapIconMap(addonName, pin, mapID, tx, ty)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Apply / setup
--------------------------------------------------------------------------------

function Perskan:ApplyDelveMapPins()
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        RefreshMapPins(WorldMapFrame:GetMapID())
    end
end

Perskan:RegisterModule("DelveMap", function(self)
    if not HBDP then return end

    EventRegistry:RegisterCallback("MapCanvas.MapSet", function(_, mapID)
        RefreshMapPins(mapID)
    end)

    -- Follow Blizzard's own delve filter.
    EventRegistry:RegisterFrameEventAndCallback("CVAR_UPDATE", function(_, cvar)
        if cvar == DELVE_CVAR and WorldMapFrame and WorldMapFrame:IsVisible() then
            RefreshMapPins(WorldMapFrame:GetMapID())
        end
    end)

    -- "Bountiful Delves Only" in the map's tracking dropdown, sharing the profile key
    -- with the settings window.
    if not (Menu and Menu.ModifyMenu) then return end
    Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(owner, rootDescription)
        local mapInfo = C_Map.GetMapInfo(owner:GetParent():GetMapID())
        if not (mapInfo and VALID_MAP_TYPES[mapInfo.mapType]) then return end
        if not Perskan.db.profile.showDelvesOnContinentMap then return end

        local title = RACE_CLASS_ONLY:format(C_QuestLog.GetTitleForQuestID(81514) or "Bountiful Delves")
        rootDescription:CreateDivider()
        rootDescription:CreateCheckbox(title,
            function() return Perskan.db.profile.delvesBountifulOnly end,
            function()
                Perskan.db.profile.delvesBountifulOnly = not Perskan.db.profile.delvesBountifulOnly
                Perskan:ApplyDelveMapPins()
                if Perskan.RefreshConfig then Perskan:RefreshConfig() end
            end)
    end)
end)
