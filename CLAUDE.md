# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Perskan's Pack is a World of Warcraft retail addon that modifies the default UI through Lua scripts. It adjusts frame scales, hides UI elements, sets CVars, manages damage meter window sizing/anchoring, and customizes aura display on unit/raid frames.

## Architecture

The addon uses the Ace3 framework for its saved-variable/profile layer (AceDB-3.0) and
a small module registry for feature code. The settings UI is a standalone window built
from **Blizzard's own templates** - `ButtonFrameTemplate`, `UICheckButtonTemplate`,
`UISliderTemplateWithLabels`, `WowStyle1DropdownTemplate`, `UIPanelButtonTemplate`,
`MinimalScrollBar` - not AceConfig and not a custom widget toolkit. Anything drawn by
this addon should use stock game art; skinning over Blizzard's own art is what the UI
was deliberately moved away from.

- **Options.lua**: Bootstrap. Creates the addon via AceAddon-3.0, holds `defaults.profile`,
  defines the module registry (`Perskan:RegisterModule(name, setupFn, optionalKey)`),
  wires profile-change callbacks, builds the config window, and registers `/perskan` (and
  `/pp`). Loads first.
- **Modules/*.lua**: One file per feature area. Each registers a setup function into the
  registry and exposes live-apply methods on `Perskan` (e.g. `Perskan:ApplyXpBarScale()`).
  Modules read `Perskan.db.profile` live (never cache it — AceDB repoints the table on a
  profile switch). Files: `CVars`, `FrameScaling`, `ActionBars`, `GreyOnCooldown`,
  `RangeColoring`, `HideElements`, `Auras`, `Nameplates`, `DamageMeter` (gated on
  `enableDamageMeterCustomization`), `BuffBars`, `DelveMap`, `ChatCopyPaste`,
  `KeyBindings`, `BindPadTweaks`, `ItemLevel`.
- **Vendored addons**: `Modules/BindPad/` (BindPad, Tageshi) and
  `Modules/SimpleItemLevel/` (Simple Item Level, Kemayo) are third-party addons carried
  whole, each with its own saved variable listed in the toc. Every deviation from
  upstream is marked `[Perskan]` in-file: a feature gate in BindPad, BindPad's widget art
  moved onto Blizzard's current templates and atlases (`BindPad.xml`), and
  namespace/saved-variable pinning in Simple Item Level (files loaded from another
  addon's toc otherwise receive *its* name and private table from `...`). Thin glue
  modules - `KeyBindings.lua`, `ItemLevel.lua` - expose them to the settings window.
- **Action button visuals** are split by property so features stack rather than fight:
  `GreyOnCooldown` owns desaturation (cooldowns), `RangeColoring` owns vertex colour
  (range/resources).
- **Retail 12.x note**: unit-frame and raid-frame auras are engine-owned
  (`AuraContainer`/`AuraButton`, private auras). Individual aura icons and their
  cooldowns are not reachable from an addon; the only public knobs are the container's
  `SetSmallAuraSize`/`SetLargeAuraSize`, which is what `Modules/Auras.lua` drives.
- **Config/Schema.lua**: Data-driven description of the settings window — categories and
  controls (`toggle`/`range`/`select`/`color`/`button`/`divider`) with `cvar`, `apply`,
  `reload`, `hidden`, `disabled` flags, plus optional `get`/`set` for settings that don't
  live in the profile. Adding a setting is mostly a schema edit.
- **Config/Window.lua**: Renders the schema into a `ButtonFrameTemplate` window with a
  category list on the left, a scrolling content pane (`MinimalScrollBar` paired through
  `ScrollUtil.InitScrollFrameWithScrollBar`), a Reload UI button that appears only when
  something asks for one, and a Profiles page. Exposes `Perskan:OpenConfig()` /
  `RequestReload()` / `RefreshConfig()`.
- **Core.lua**: Lifecycle glue. `OnEnable` iterates the registry (each module in a `pcall`
  so one failure can't abort the rest); `PLAYER_ENTERING_WORLD` re-asserts CVars;
  `ApplyProfileSettings` re-applies live settings after a profile switch.
- **Libs/HereBeDragons/**: Embedded map/pin library (BSD), used by `Modules/DelveMap.lua`
  to place pins on the world map canvas.
- **Perskan.xml**: Load order — Options → Modules → Config → Core.
- **Perskan.toc**: Manifest (multi-interface: 110207, 120000).

Settings are stored in `PerskanDB` SavedVariable using AceDB-3.0 profiles.

## Key Patterns

- **Module registry**: Feature files call `Perskan:RegisterModule(name, setupFn, optionalKey)`.
  `optionalKey` gates a module to run only when that profile flag is set at login; live-
  toggleable modules leave it nil and gate their own hooks internally.
- **Live apply vs. reload**: Prefer applying changes live. A module exposes an `Apply*`
  method that re-reads the profile and updates current frames; the schema control calls it
  via `apply = function() ... end`. Only settings that genuinely can't revert at runtime
  (chat font sizes, buff-bar anchoring, damage-meter customization master switch) set
  `reload = true`, which reveals the non-blocking reload banner instead of a popup. There is
  **no** blocking `StaticPopup("RELOAD_UI")` anymore.
- **Hooking**: Frame modifications use `hooksecurefunc` to persist through Blizzard updates.
  Persistent hides re-assert via a gated `Show` hook. The damage meter saves and replaces
  `SetWidth`/`SetHeight`/`SetScale`.
- **Taint avoidance**: Frame repositioning checks `InCombatLockdown()` before protected
  calls (`ClearAllPoints`/`SetPoint`) and re-asserts on `PLAYER_REGEN_ENABLED`. Don't use
  `AddManagedFrame` on UIParentBottomManagedFrameContainer (causes combat taint errors).
- **Adding a new setting**: (1) add the default to `defaults.profile` in Options.lua; (2) add
  a control to the relevant category in `Config/Schema.lua` (pick `type`; add `cvar` for a
  CVar, `apply` for a live effect, or `reload = true` if it needs a reload); (3) if it applies
  live, implement/extend an `Apply*` method in the matching `Modules/*.lua` file.

## Releasing

Push a tag matching `v*` (e.g., `v1.1`) to trigger the GitHub Actions workflow that packages and releases a zip file.

**Always ask which version the work is going out as before opening a pull request**, and set
`## Version` in `Perskan.toc` to that number as part of the same PR. The settings window shows
this value (`C_AddOns.GetAddOnMetadata`), so it is what the user sees in game, and it should
match the tag the change ships under. Don't infer the next version from the current toc value —
it has drifted from the tags before (the `v1.1.32` tag ships a toc reading `1.2.0`); check
`git tag --sort=-v:refname` for the real release line and confirm the number with the user.
