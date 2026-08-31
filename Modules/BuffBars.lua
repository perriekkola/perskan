-- BuffBarCooldownViewer positioning + ExtraQuestButton anchoring.
--
-- Settings that live here:
--   * anchorBuffBarsToWidgetFrame - park the viewer above the cast bar
--   * anchorExtraQuestButton      - park ExtraQuestButton above the cast bar
--
-- The two share the cast-bar anchor and a single event frame: the old code installed the
-- cast-bar SetPoint hook and the login init twice, once per anchor feature. Repositioning
-- is protected, so every path is guarded by InCombatLockdown and reasserted on
-- PLAYER_REGEN_ENABLED. These settings can't cleanly revert an Edit-Mode-owned frame at
-- runtime, so the settings window asks for a reload on change.
--
-- Tracked bar stacking taint rule
-- -------------------------------
-- There used to be two more settings here - collapseTrackedBarGaps and trackedBarSortMode -
-- which closed the holes inactive bars leave behind and ordered the visible bars by time
-- remaining. Both are gone, and nothing in this addon may touch the viewer's item frames
-- again, because in 12.1 the cooldown viewer keeps its aura lookup in a table created by
-- CreateSecureAuraInstanceMap (Blizzard_CooldownViewer/CooldownViewerSecure.lua):
--
--     settablesecurity(auraInstanceMapProxy, Enum.TableSecurityOption.DisallowTaintedAccess)
--
-- Aura instance IDs are secret in 12.x, so the viewer declassifies them behind that proxy
-- and the engine refuses to index it from a tainted execution. Blizzard's own aura pipeline
-- shows and hides item frames and reads that map in the same call - see
-- CooldownViewerMixin:OnUnitAura, which runs itemFrame:OnUnitAuraAddedEvent() for every
-- active frame and then indexes the map in CheckAuraAddedAlertTriggers, and the item frame
-- pool's reset callback, which hides a frame and then clears its aura instance info. Any
-- taint this addon leaves on an item frame therefore surfaces as
--
--     CooldownViewer.lua:1865: attempted to index a table that cannot be accessed while
--     tainted (execution tainted by 'Perskan')
--
-- and it is unfixable from an addon: clearing includeAsLayoutChildWhenHidden is the only
-- lever that closes the gaps, hooking each frame's OnShow/OnHide is the only way to know a
-- bar came or went, and re-anchoring the bars is the only way to sort them. All three write
-- to or hook frames the secured aura map is read alongside. Blizzard's fixed slots - gaps
-- and all - are what the Cooldown Manager gives us.

-- 12.1 removed UIParentBottomManagedFrameContainer; anchor to the player cast bar
-- (the frame this option is named for), falling back to UIParent.
local function GetBottomAnchorFrame()
    return PlayerCastingBarFrame or UIParent
end

local function RepositionBuffBarsAboveWidget()
    if not Perskan.db.profile.anchorBuffBarsToWidgetFrame then return end
    if not BuffBarCooldownViewer then return end
    if InCombatLockdown() then return end

    local anchor, yOffset
    if Perskan.db.profile.anchorExtraQuestButton and ExtraQuestButton and ExtraQuestButton:IsShown() then
        anchor, yOffset = ExtraQuestButton, 15
    else
        anchor, yOffset = GetBottomAnchorFrame(), 20
    end
    if not anchor then return end

    -- The cooldown viewer is an aura-driven Edit Mode system; SetPoint can raise a
    -- forbidden-aspect error under the 12.1 security model, so guard it.
    pcall(function()
        BuffBarCooldownViewer:ClearAllPoints()
        BuffBarCooldownViewer:SetPoint("BOTTOM", anchor, "TOP", 0, yOffset)
    end)

end

local function RepositionExtraQuestButton()
    if not Perskan.db.profile.anchorExtraQuestButton then return end
    if not ExtraQuestButton then return end
    if InCombatLockdown() then return end

    local anchor = GetBottomAnchorFrame()
    if not anchor then return end

    ExtraQuestButton:ClearAllPoints()
    ExtraQuestButton:SetPoint("BOTTOM", anchor, "TOP", 0, 20)

    RepositionBuffBarsAboveWidget()
end

-- Reassert every managed position.
local function RepositionAll()
    RepositionExtraQuestButton()
    RepositionBuffBarsAboveWidget()
end

Perskan:RegisterModule("BuffBars", function(self)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

    local initialized = false
    eventFrame:SetScript("OnEvent", function(_, event)
        if not (BuffBarCooldownViewer or ExtraQuestButton) then return end

        if not initialized then
            initialized = true

            -- Single cast-bar hook re-anchors everything when the bar re-lays-out
            -- (e.g. Edit Mode changes), replacing the two overlapping hooks the old
            -- code installed.
            local castBar = GetBottomAnchorFrame()
            if castBar and castBar ~= UIParent then
                hooksecurefunc(castBar, "SetPoint", function()
                    if not InCombatLockdown() then
                        RepositionAll()
                    end
                end)
            end

            -- ExtraQuestButton visibility affects the buff-bar anchor.
            if ExtraQuestButton then
                ExtraQuestButton:HookScript("OnShow", function()
                    if not InCombatLockdown() then RepositionBuffBarsAboveWidget() end
                end)
                ExtraQuestButton:HookScript("OnHide", function()
                    if not InCombatLockdown() then RepositionBuffBarsAboveWidget() end
                end)
            end

            RepositionAll()
        end

        if event == "PLAYER_REGEN_ENABLED" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
            RepositionAll()
        end
    end)
end)
