-- Settings glue for the vendored Simple Item Level (Modules/SimpleItemLevel/, by
-- Kemayo, BSD): item levels and upgrade/gem/enchant/soulbound flags drawn on bag,
-- character, inspect and loot items.
--
-- Its options stay in its own account-wide saved variable rather than moving into
-- Perskan's profile, so an existing Simple Item Level install keeps its settings and
-- every option that has never been touched still resolves to upstream's default through
-- that table's metatable. The settings window reads and writes it through the two
-- accessors below.

local function Namespace()
    return PerskanSimpleItemLevel
end

function Perskan:ApplyItemLevel()
    local ns = Namespace()
    if ns and ns.RefreshOverlayFrames then
        ns.RefreshOverlayFrames()
    end

    -- The character sheet's average item level is drawn from a hook on
    -- PaperDollItemSlotButton_Update, which the overlay refresh doesn't touch - so
    -- without this a changed setting sat there doing nothing until the next equipment
    -- change or a reload. Poking one slot re-runs that path.
    if CharacterFrame and CharacterFrame:IsShown()
        and type(PaperDollItemSlotButton_Update) == "function" then
        local slot = _G["CharacterHeadSlot"]
        if slot then
            pcall(PaperDollItemSlotButton_Update, slot)
        end
    end
end

function Perskan:GetItemLevelOption(key)
    local ns = Namespace()
    if ns and ns.db then
        return ns.db[key]
    end
    -- Before ADDON_LOADED has run, upstream's defaults are still the honest answer.
    return ns and ns.defaults and ns.defaults[key]
end

function Perskan:SetItemLevelOption(key, value)
    local ns = Namespace()
    if not (ns and ns.db) then return end
    ns.db[key] = value
    self:ApplyItemLevel()
end
