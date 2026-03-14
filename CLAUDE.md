# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Perskan's Pack is a World of Warcraft retail addon that modifies the default UI through Lua scripts. It adjusts frame scales, hides UI elements, sets CVars, manages damage meter window sizing/anchoring, and customizes aura display on unit/raid frames.

## Architecture

The addon uses the Ace3 library framework:

- **Options.lua**: Initializes the addon via AceAddon-3.0, defines default profile settings (`defaults.profile`), creates the AceConfig options table, and registers the `/perskan` slash command. Loads first.
- **Core.lua**: Contains all UI modification logic. `OnEnable` calls setup functions for each feature area. CVars are applied on `PLAYER_ENTERING_WORLD`. Each feature (damage meter, buff bars, aura cooldowns, etc.) creates its own event-listening frame.
- **Perskan.xml**: Defines load order (Options.lua before Core.lua)
- **Perskan.toc**: Addon manifest (multi-interface: 110207, 120000)

Settings are stored in `PerskanDB` SavedVariable using AceDB-3.0 profiles.

## Key Patterns

- **Hooking**: Frame modifications use `hooksecurefunc` to persist through Blizzard updates. For the damage meter, original methods (`SetWidth`/`SetHeight`/`SetScale`) are saved and replaced to override Blizzard's sizing.
- **Taint avoidance**: Frame repositioning code checks `InCombatLockdown()` before calling protected functions like `ClearAllPoints`/`SetPoint`. Don't use `AddManagedFrame` on UIParentBottomManagedFrameContainer (causes combat taint errors).
- **Settings that need reload**: Toggle options that hook into frames at startup (hideHotkeys, hideMacroText, sortBuffBarsUpward, etc.) show a `StaticPopup("RELOAD_UI")` confirmation. Slider options that need reload use `ShowReloadUIDebounced()` (0.5s debounce).
- **Adding a new setting**: Add the default to `defaults.profile` in Options.lua, add an AceConfig entry in `options.args` (use existing `order` numbering gaps), then implement the logic in Core.lua as a setup function called from `OnEnable`.

## Releasing

Push a tag matching `v*` (e.g., `v1.1`) to trigger the GitHub Actions workflow that packages and releases a zip file.
