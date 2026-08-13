# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Perskan's Pack is a World of Warcraft retail addon that modifies the default UI through Lua scripts. It adjusts frame scales, hides UI elements, sets CVars, manages damage meter window sizing/anchoring, and customizes aura display on unit/raid frames.

## Architecture

The addon uses the Ace3 framework for its saved-variable/profile layer (AceDB-3.0) and
a small module registry for feature code. The settings UI is a custom standalone window
built on the embedded **MiniFramework** widget toolkit (`Libs/MiniFramework/`), not AceConfig.

- **Options.lua**: Bootstrap. Creates the addon via AceAddon-3.0, holds `defaults.profile`,
  defines the module registry (`Perskan:RegisterModule(name, setupFn, optionalKey)`),
  wires profile-change callbacks, builds the config window, and registers `/perskan` (and
  `/pp`). Loads first.
- **Modules/*.lua**: One file per feature area. Each registers a setup function into the
  registry and exposes live-apply methods on `Perskan` (e.g. `Perskan:ApplyXpBarScale()`).
  Modules read `Perskan.db.profile` live (never cache it — AceDB repoints the table on a
  profile switch). Files: `CVars`, `FrameScaling`, `ActionBars`, `HideElements`, `Auras`,
  `Nameplates`, `DamageMeter` (gated on `enableDamageMeterCustomization`), `BuffBars`.
- **Config/Schema.lua**: Data-driven description of the settings window — categories and
  controls (`toggle`/`range`/`select`/`divider`) with `cvar`, `apply`, `reload`, `hidden`,
  `disabled` flags. Adding a setting is mostly a schema edit.
- **Config/Window.lua**: Renders the schema into a MiniFramework standalone window with a
  left sidebar, styled widgets, a non-blocking reload banner, and a Profiles panel. Exposes
  `Perskan:OpenConfig()` / `RequestReload()` / `RefreshConfig()`.
- **Core.lua**: Lifecycle glue. `OnEnable` iterates the registry (each module in a `pcall`
  so one failure can't abort the rest); `PLAYER_ENTERING_WORLD` re-asserts CVars;
  `ApplyProfileSettings` re-applies live settings after a profile switch.
- **Libs/MiniFramework/**: Embedded UI toolkit (widgets, standalone window, tabs). Storage-
  agnostic (get/set callbacks) and rebranded via `M:SetPalette` in Window.lua.
- **Perskan.xml**: Load order — Options → Modules → Config → Core.
- **Perskan.toc**: Manifest (multi-interface: 110207, 120000); loads `MiniFramework.xml`
  before `Perskan.xml`.

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
