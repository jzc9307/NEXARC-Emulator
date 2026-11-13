# NEXARC player guide

Native SwiftUI for Apple Silicon Macs, macOS 14 or later. [Download the DMG from the main README](../README.md#download--install), open it and drag NEXARC into Applications. The app is signed locally, not notarized with an Apple Developer account.

## Play

Choose a console in **Consoles**, then a game. **Import** and drag-and-drop accept your local game files. Common extensions identify the system; ambiguous disc formats ask which console to use. Extract downloaded archives first. Retro games are copied into managed local folders. Switch files remain at their imported location.

Included test programs:

- **Orbit Catch / Game Boy** — an original catch-the-star game. Left/right moves; best score uses battery-backed save RAM.
- **Color Signal / NES** — an original graphics and input test. Arrow keys move the sprite.
- **2048 / 3DS** — 0rientd's MIT-licensed homebrew port, included with source and license.
- **Orbit Pong / Switch** — original playable homebrew. Up/down, Z to serve, X to reset, + to exit.
- **First Light / Switch** — a CPU diagnostic, with results in Sessions; it has no graphics.

## Display, controls and artwork

**Settings → Console display & skins** saves a separate profile for each console. Supported handhelds offer hardware-faithful community artwork (DS, 3DS, GB, GBC, GBA, PSP and Game Gear), plus Screen only and NEXARC's optional stylized shells. Home consoles default to Screen only. Uploaded PNG/JPEG/WebP/TIFF artwork is stored locally per console. Select Uploaded skin, then drag the highlighted game viewport or its corner handle to fit your image. For DS/3DS, enable **Place screens separately** and position Top and Touch independently; the lower screen's mouse input follows its placement. This mode uses stacked software output. Import image artwork rather than proprietary skin ZIP formats. See the bundled artwork credits and license under Resources/Skins/Hardware.

The Window size menu offers **Small (800 × 600)**, **Standard (1100 × 760)**, **Large (1440 × 900)**, **Fit to display** and **Custom size**. Custom dimensions appear only when selected. Fit to display adapts to the available screen on each launch. These choices are also available in a game’s display override.

**Game details → Per-game settings** optionally overrides display/skin, keyboard, controller buttons and fast-forward speed. Turning a section off restores console defaults. Retro gamepad mapping targets the standard gamepad buttons for player one; analog sticks keep their normal mapping. Switch can snapshot the selected controller profiles separately. Changes apply on the next launch. During retro gameplay, Esc opens the custom session menu, where Console skin cycles the available choices.

Enable **Settings → Discord Rich Presence** and paste the Application ID from an app you create in the [Discord Developer Portal](https://discord.com/developers/applications). Keep the Discord desktop app running. NEXARC then shows the current game and console while the session is open; closing the session clears the activity. Presence uses Discord's local IPC connection.

**Controllers** defaults to an illustrated keyboard when no physical controller is connected. Highlighted keys reflect your saved bindings. Remap retro-console actions using the pickers; changes apply next launch. Connect a supported controller to see its model and live inputs, or choose Preview controller models. Switch’s keyboard profile remains in Core tools → Input.

Imported games first check for a same-name local PNG/JPG cover. Missing covers are matched by system and exact normalized title against [Libretro thumbnails](https://github.com/libretro-thumbnails/libretro-thumbnails), with region preference. Covers are cached offline. No game data or ROM hash is uploaded; requests contain the public system and filename/title. Switch/homebrew or unmatched titles retain designed fallback art; choose your own cover in Game tools. All box art stays fully visible rather than being cropped to the card.

During play, the library shows a highlighted active card, elapsed session time and a persistent Now Playing panel. Other games dim and cannot start until the session ends. Return to game focuses the owned game window. Session menu opens the same Escape controls.

Hold **Tab** for the selected fast-forward target (**2× / 3× / 4× / 5×**); release for normal speed. **Shift + Tab** uses 5× immediately. Choose the target in Settings → Playback preferences or the Now Playing panel. The retro player shows an overlay while accelerated; Switch uses guest-clock turbo and reports speed in its title and Now Playing panel. Targets depend on game and hardware performance. Menus, key release and loss of focus restore normal speed. The native cursor stays visible in fullscreen; automatic mouse grabbing is disabled.

## Systems and engines

The library has 21 collections: Switch, 3DS, DS, Game Boy, Game Boy Color, Game Boy Advance, NES, SNES, N64, GameCube, Wii, Mega Drive, Master System, Game Gear, Dreamcast, Saturn, PlayStation, PlayStation 2, PSP, PC Engine and Atari 2600.

Switch retains the source-built Ryujinx-derived core from 0.1. Other systems use the official RetroArch 1.22.2 runtime and 16 Apple Silicon libretro cores. This follows the modular approach used by OpenEmu and RetroArch. Each system is a configured engine route, not a claim that every game runs. PS2's Play! core is experimental. 3DS uses software graphics by default because Vulkan failed in testing on this Mac; performance in demanding games will vary. The included Switch homebrew test worked, including input and speed controls, but the Switch Vulkan renderer crashed intermittently during sustained presentation on macOS 27 in testing. Treat Switch play as experimental and save often until this renderer issue is fixed.

Gameplay opens in a separate engine window. NEXARC provides the gallery, native library, imports, original interactive console models, per-game folders, save management, patching and engine control. It does not contain commercial game downloads or Nintendo console keys.

## Progress and tools

For retro consoles, in-game save RAM is flushed periodically and on normal exit. An automatic resume state is created on normal exit when the core supports it. Use **Resume** for that snapshot. **Game details → Save slots** provides six visual slots with thumbnail and timestamp. **F5** saves the slot selected in the session menu (Slot 1 initially); **F8** loads it. Before a load, NEXARC captures current play into recovery history. Overwritten slots and previous resume files are also preserved, up to ten recovery copies per game. **Recovery backups → Restore** restores a selected snapshot while the game is stopped. Snapshots carry core-build fingerprints and checksums; incompatible or damaged files are rejected. In-game saves remain preferable for long-term progress.

**Escape** opens NEXARC's custom paused session menu. Escape again or a click outside resumes. Save & return waits for the selected slot to finish before quitting; Return to library uses the core's normal auto-save on exit. DS/3DS software frames are presented through NEXARC directly to avoid a stale Metal drawable after loading. Retro audio writes are nonblocking so an interrupted audio route does not indefinitely stop emulation.

**Recovery** in Now Playing provides display refresh, restart from in-game save (skipping the resume snapshot), frame/heartbeat diagnostics and a text report export with home paths redacted. Refresh keeps the running game; restart can lose unsaved play. These controls do not assume that every dark game scene is a failure. Switch exposes restart and diagnostics but does not support retro display-refresh or snapshot slots.

A connected extended gamepad navigates the library: D-pad/left stick selects, A/Cross plays, X/Square opens details, B/Circle goes back and shoulders change sections. In game details, left/right selects a slot, A/Cross loads it and X/Square plays. In the paused game menu, D-pad selects actions, A activates, B resumes and left/right changes slots. Press both stick buttons to open the menu. Physical-controller behavior still requires hardware validation.

Open a game's **…** menu for cover artwork, its save folder, ZIP backup export, IPS/BPS patching, and compatible RetroArch cheat files. BPS verifies source, target and patch checksums. A patch creates a separate library entry and preserves the original. Already patched ROMs can be imported normally. Cheat codes depend on the game, revision, region and core; they are not supported by every engine. 3DS, Dolphin, PS2 and Switch do not use this build's `.cht` workflow.

Switch uses its games' normal saves and existing core tools, with no quick states. Switch save-folder export contains all Switch user saves because title-ID extraction is not implemented.

**Saves** is the progress library. Data stays in `~/Library/Application Support/NEXARC`. On first launch, NEXARC moves an existing `~/Library/Application Support/Helio` data folder into the new location, preserving games, favorites, covers, controller profiles and saves.

Controller detection is on demand: open Controllers and press **Detect devices** to enumerate SDL devices. Merely opening the page or connecting a controller no longer starts the Switch helper. Live native model previews remain. The native profile editor configures Switch. Retro consoles use macOS GameController/MFi mapping; F1 → Controls provides per-core remapping. Physical-controller validation is still pending.

## Build and study

Read [START-HERE.md](START-HERE.md) and [VERIFICATION.md](VERIFICATION.md). The source is deliberately separated into metadata, UI, import rules, byte-level patches and process control.

1. Restore the retro runtime with `bash scripts/fetch-retro.sh`.
2. Build the Switch engine with `bash scripts/build-core.sh` (requires .NET 10).
3. Build/package the native app with `bash scripts/build.sh` (requires Xcode command line tools).
4. `python3 scripts/build-retro-homebrew.py` rebuilds the Game Boy and NES ROMs without a console SDK.

The source-built Switch engine and frontend are included. Added retro engines are upstream binaries; local core ZIP snapshots may be cached in the ignored Vendor/CoreArchives folder; the public source repository does not include that cache. Download hashes, authors and licenses are recorded under Resources/Notices. Their source references are documented in THIRD-PARTY.md. See individual licenses for redistribution terms; they are not all MIT.

## Reading the new code

Start with `Sources/Models.swift` and `PlayerPreferences.swift` for stored data. `AppModel.swift` owns the library; `EngineBridge.swift` owns the exact process it launches; `RetroRuntime.swift` translates display and keyboard choices into real core settings. `PlayerCompanion.m` is a small in-process AppKit companion: its common-mode timer wakes the upstream Cocoa frame observer, its local event monitor reserves Escape, and its window wrapper fits the original render view inside a skin. It never runs guest instructions itself. `CoverService.swift` handles exact-title artwork lookup and offline caching. `Theme.swift` contains the approved Warp emblem and compact button styles.

The app identity and data directory use NEXARC. The first launch migrates the older Helio data directory as a whole; it does not delete existing games or saves. Fast-forward uses **hold Tab** for the selected 2×–5× speed, or **hold Shift + Tab** for 5×. The active multiplier appears in the player window and session controls.

## Console skins and uploads

Settings → Console display & skins lists all 21 consoles. Each console has its own saved skin choice and upload collection. Hardware artwork is included for DS, 3DS, Game Boy, Game Boy Color, GBA, PSP and Game Gear. Select Console hardware for these community reproductions of the actual console shells. Unconfigured supported handhelds default to hardware artwork; home consoles default to Screen only. Existing choices are preserved. Classic and Neon remain optional studio frames.

Use Upload skin image to import PNG, JPEG, WebP, or TIFF artwork (up to 32 MB and 8192 × 8192 pixels). NEXARC keeps a PNG copy in its managed Skins folder. Choose an uploaded image, then drag or resize the highlighted preview area. Fine adjustment exposes Left, Top, Width and Height. DS/3DS support either one combined viewport or independent Top and Touch rectangles via Place screens separately. Switch uses transparent PNG overlays stretched to the game window and keeps the original full-window game viewport.

ZIP, .deltaskin, .gbaskin, SVG, and other emulator-specific skin packages are not parsed. Export their artwork as a supported image before importing; controls and layout metadata from those packages are not imported. Changes in Settings apply next launch. Esc → Console skin cycles built-in and selected uploaded artwork during retro play and saves the selection. Removing a skin deletes only NEXARC’s managed copy.

Hardware artwork is by [Duimon](https://github.com/Duimon/Retroarch-Overlays), distributed unchanged under CC BY-NC-ND 4.0. Original files, source URLs, hashes, credits and license are included in Resources/Skins/Hardware. This is community hardware artwork, not official console-manufacturer artwork. DS and 3DS hardware presets use Stacked layout.
