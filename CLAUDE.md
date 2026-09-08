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
  `RangeColoring`, `HideElements`, `Auras`, `PlayerBuffs` (gated on
  `filterPlayerBuffs`), `Nameplates`, `DamageMeter` (gated on
  `enableDamageMeterCustomization`), `BuffBars`, `DelveMap`, `DelveData`/`DelvePanel`,
  `ChatCopyPaste`, `KeyBindings`, `BindPadTweaks`, `ItemLevel`. `DelveData.lua` is the one
  file that registers nothing: it is the delve difficulty table `DelvePanel.lua` reads,
  ported from DelveSpeedTracker (Bloom) and meant to be tuned from experience.
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
- **Bindings.xml**: loaded implicitly by the client (it is not in the toc). Bindings sit
  under the `PERSKAN` header, whose `BINDING_HEADER_*`/`BINDING_NAME_*` strings are set
  from the module that owns the binding. BindPad's own binding keeps its upstream header.
- **Delve widget taint rule**: `Modules/DelvePanel.lua` and `Modules/DelveMap.lua` both
  read story variants off delve map POIs through `C_UIWidgetManager`. Doing that from
  addon code taints shared widget data, which surfaces as "secret number value tainted
  by ..." on POI tooltip hover. Every widget call in both files goes through
  `securecallfunction`, the panel's scan additionally only runs with the map closed (it
  shows the last result until then), and the map's pin tooltips briefly cache each widget
  set they read. Variants rotate daily, so stale data costs nothing.
- **Objective tracker taint rule**: nothing this addon does may leave taint in an
  execution that marks a Blizzard frame dirty. `DirtiableMixin:MarkDirty`
  (`Blizzard_SharedXML/MixinUtil.lua`) defers the update with `RunNextFrame`, which
  carries the scheduling execution's taint into the update, and
  `ScenarioObjectiveTrackerMixin:LayoutContents` opens every tracker layout with
  `ShouldShowMawBuffs()` - a `C_UnitAuras.GetAuraDataByIndex` call that throws "Auras
  cannot be accessed when secret while tainted by 'Perskan'" the moment the layout runs
  tainted, in or out of a scenario. Two habits keep us out of it: read Blizzard's shared
  state through `securecallfunction`, and don't install hooks that run inside Blizzard's
  own execution (`HookScript` on a Blizzard frame, unlike `hooksecurefunc`, taints
  whoever fired the script) for a feature that is switched off.
- **Cooldown viewer taint rule**: nothing may write to, hook, or re-anchor
  `BuffBarCooldownViewer`'s item frames. In 12.1 the viewer keeps its aura lookup in the
  `CreateSecureAuraInstanceMap` proxy (`Blizzard_CooldownViewer/CooldownViewerSecure.lua`),
  flagged `Enum.TableSecurityOption.DisallowTaintedAccess`, and Blizzard's aura pipeline
  shows/hides item frames and indexes that map in the same execution
  (`CooldownViewerMixin:OnUnitAura` → `CheckAuraAddedAlertTriggers`, and the item frame
  pool's reset callback). Any taint left on an item frame therefore comes back as
  "attempted to index a table that cannot be accessed while tainted (execution tainted by
  'Perskan')". This is what removed the tracked-bar stacking options in 1.1.40; see the
  long comment at the top of `Modules/BuffBars.lua` before trying it again.
- **Retail 12.x note**: unit-frame and raid-frame auras are engine-owned
  (`AuraContainer`/`AuraButton`, private auras). Individual aura icons and their
  cooldowns are not reachable from an addon; the only public knobs are the container's
  `SetSmallAuraSize`/`SetLargeAuraSize`, which is what `Modules/Auras.lua` drives.
- **12.1 aura filtering rule**: filtering auras is possible again, but only by letting the
  engine do it. `CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")`
  tracks, filters, sorts and creates its own `AuraButton`s; an addon supplies presentation
  (`SetIcon`, `SetDurationText`, `SetApplicationCount`, `SetCancelAuraButtons`) and a filter
  (`AddAuraGroup(key, filterString, { candidateFilters = { excludeSpellIDs = ... } })`,
  changed later with `SetAuraGroupCandidateFilters`). Reading aura data is still off the
  table: the index/slot/instance-ID APIs raise a Lua error from addon code while auras are
  secret (combat, encounters, M+, rated PvP), `UNIT_AURA` carries a secret payload, and
  `AuraButton`s carry Forbidden Aspects — no script handlers, no focus queries, secret
  `IsShown`. `Modules/PlayerBuffs.lua` is built on this: it hides Blizzard's `BuffFrame`
  (still an unfilterable `AuraUtil.ForEachAura` frame in 12.1) and draws the row itself, and
  its shift+right-click-to-hide only arms while auras are readable, because mapping a
  clicked slot back to a spell ID means reading the aura list ourselves. It stands aside
  while Edit Mode is open and mirrors its layout off `BuffFrame.AuraContainer`
  (`iconStride`/`iconPadding`/`iconScale`/`isHorizontal`/`addIconsToRight`/`addIconsToTop`)
  so the Edit Mode aura settings still drive the replacement row.
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
- **Perskan.toc**: Manifest. `## Interface` is multi-interface and lists live retail
  first (`120100`, Midnight 12.1.0), because addon managers show the first entry as the
  addon's game version; `110207` trails it for The War Within. Bump the leading number
  when retail patches, or the manager reports the addon as built for an older game.

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
- **Adding a keybinding**: add a `<Binding>` to `Bindings.xml` calling a method on the
  `Perskan` global, and set `BINDING_NAME_<NAME>` at file scope in the module that
  implements it. The method has to build its own frames lazily - a binding can fire before
  anything has opened the feature.
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
