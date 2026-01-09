# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Perskan's Pack is a World of Warcraft retail addon that modifies the default UI through Lua scripts. It adjusts frame scales, hides UI elements, and sets various CVars for camera, nameplates, and raid frames.

## Architecture

The addon uses the Ace3 library framework:

- **Options.lua**: Initializes the addon via AceAddon-3.0, defines default profile settings, creates the AceConfig options table, and registers slash commands. Loads first.
- **Core.lua**: Contains UI modification logic executed on `OnEnable`. Hooks into frames like EncounterBar, TalkingHeadFrame, StatusTrackingBarManager, and ExtraAbilityContainer to apply scale/visibility changes.
- **Perskan.xml**: Defines load order (Options.lua before Core.lua)
- **Perskan.toc**: Addon manifest targeting interface 110002

Settings are stored in `PerskanDB` SavedVariable using AceDB-3.0 profiles.

## Key Patterns

- Frame modifications use `hooksecurefunc` to persist through Blizzard updates
- CVars are initialized on `PLAYER_ENTERING_WORLD` event
- Some settings require `/reload` - these show a `StaticPopup` confirmation
- Addon is accessed via `/perskan` slash command which opens the Blizzard settings panel

## Releasing

Push a tag matching `v*` (e.g., `v1.1`) to trigger the GitHub Actions workflow that packages and releases a zip file.
