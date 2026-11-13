# Start here: follow one launch

Read the native code first. You do not need to understand the entire upstream emulator to change NEXARC's interface or game.

## 1. A click becomes a process

`Sources/LibraryView.swift` draws the library and calls `AppModel.launch(item)` when you press Play.

`Sources/AppModel.swift` owns your library and preferences. It checks whether a file still exists, checks for console keys when launching encrypted formats, and calls the bridge. It records actual session results when the process finishes.

`Sources/Models.swift` contains the data structures and `LaunchPlan.arguments`. Read this function to see exactly how UI preferences become command-line options.

`Sources/EngineBridge.swift` starts the bundled core with Foundation's `Process`. It passes an argument array directly, without a shell, so spaces and shell-like characters in game filenames remain plain filenames. Standard output and error go to a pipe, the Sessions view, and a local log file. Stop only signals the process that NEXARC owns.

**Try:** change a native label in `LibraryView.swift`, rebuild, and find the result. Then change the default resolution in `Preferences` and inspect the actual launch arguments.

## 2. A controller becomes Switch input

`Sources/ControllerManager.swift` handles connection events and live values from Apple's GameController framework. It separately asks the core for its SDL device IDs. These are different APIs: seeing a controller in one does not prove it is usable in the other.

`Sources/ControllerProfile.swift` translates physical positions into the core's label-based configuration. Xbox and Switch face-button labels are arranged differently. For a positional mapping, Switch A maps to the physical east button: Xbox B, PlayStation Circle, or Nintendo A.

The manager writes actual core profile JSON under `Core/profiles/controller/NEXARC-PlayerN.json`, and the bridge supplies the selected device/profile arguments. Native label changes alone would not remap gameplay.

`Sources/ControllersView.swift` draws model previews, live indicators, mapping controls, and the Save button. SceneKit models load entirely from local assets.

**Try:** export a profile and inspect `right_joycon.button_a`. Compare an Xbox family profile with a Nintendo family profile. The tests check this distinction against the core serializer.

## 3. Orbit Pong is running inside the emulated machine

`Homebrew/OrbitPong/source/main.c` is the complete game. It is not a native Mac mini-game and does not draw into SwiftUI.

- `padUpdate` reads emulated Switch controller input.
- The physics section moves the paddles and ball and updates scores.
- `framebufferBegin` provides guest-accessible pixel memory.
- `rect`, `circle`, and `text` write pixel values into that framebuffer.
- `framebufferEnd` submits it through the Switch graphics interface that the core implements.

The code includes a small bitmap alphabet so it does not need the Switch's proprietary system-font archives. The Makefile comes from switchbrew's framebuffer example template, and the official devkitPro toolchain links the open-source libnx homebrew runtime.

**Try:** change the ball speed or paddle height. Recompile with `scripts/build-pong.sh`, rebuild NEXARC, and test the changed NRO. Increase the AI speed to make the game harder.

## 4. First Light is deliberately smaller

`Homebrew/first-light.s` is hand-written AArch64 assembly. It doubles 21, counts a loop to ten, writes and reads guest stack memory, and emits a success message through Switch SVC `0x27`. SVC `0x07` requests guest process exit.

`scripts/build-homebrew.py` assembles that code and writes a small NRO header and asset table around it. AArch64 instructions are 32 bits wide even when operating on 64-bit registers.

The core loads the executable into guest virtual memory. On this Mac, its Apple Hypervisor backend can execute guest ARM64 code while the core implements the expected operating-system services.

**Try:** change the expected arithmetic result from 42 to 43. The guest must print `NEXARC_DIAGNOSTIC_FAIL`, and the native app must not show a passing CPU test. Restore the value afterward.

## 5. Then explore the engine

`EngineSource` is the upstream Ryujinx/Ryubing-derived C# engine with a small integration patch. It is MIT licensed; dependencies keep their own licenses.

Useful entry points:

| File or directory inside EngineSource | What to inspect |
|---|---|
| `src/Ryujinx/Program.cs` | Core entry point and headless dispatch |
| `src/Ryujinx/Headless/HeadlessRyujinx.cs` | Configuration, loading, and execution orchestration |
| `src/Ryujinx/Headless/Options.cs` | Actual supported launch flags |
| `src/Ryujinx.HLE/Loaders/Processes/ProcessLoader.cs` | NRO and other program loading |
| `src/Ryujinx.HLE/HOS/Kernel/SupervisorCall/Syscall.cs` | Guest system calls |
| `src/Ryujinx.Cpu/AppleHv` | Apple Hypervisor CPU implementation |
| `src/Ryujinx.Graphics.Gpu` | Guest GPU command handling |
| `src/Ryujinx.Graphics.Vulkan` | Host Vulkan rendering, backed by MoltenVK on Mac |
| `src/Ryujinx.Input.SDL3` | Physical controller enumeration and mapping |

See `EngineSource/NEXARC_CHANGES.md` for the integration changes. This project has not implemented decryption algorithms itself; encrypted-content handling is part of the reused core and its libraries.

## Where user data goes

NEXARC uses `~/Library/Application Support/NEXARC` for its library JSON, covers, controller profiles, core data, and session logs. A development launch can override that with `--data-dir /absolute/path`.

Console key contents are never printed by NEXARC. Imported keys are stored locally with owner-only file permissions. Do not include your private console data or personal library in a public source repository.

## NEXARC 0.3: follow a game across consoles

Start here for the expanded app:

1. `Sources/GameSystem.swift` defines stable console IDs, accepted formats, colors, engine routing and honest capability flags. This is where you add another system.
2. `Sources/ConsolesView.swift` is the gallery. `Sources/ConsoleHardware.swift` builds the new interactive models from SceneKit primitives, with cached static thumbnails. The existing Switch GLB model is preserved.
3. `Sources/Models.swift` adds optional system metadata so 0.1's JSON still decodes. `AppModel.add` chooses a console, copies a retro ROM and its disc tracks locally, then persists the entry.
4. `Sources/RetroRuntime.swift` makes a separate configuration for each game's UUID. Saves, states, cheats, screenshots and core options have explicit locations. The engine process receives an argument array; filenames never pass through a shell.
5. `Sources/EngineBridge.swift` owns just the process it launches, its output and its exit record. Switch still uses the existing bridge. Retro controls use a per-session command port. `Sources/LocalCommands.c` confines that port's bind to loopback. Native app termination is a graceful-exit fallback.
6. `Sources/GameTools.swift` contains the save library, per-game inspector, save backups, code imports and patch actions. `Sources/ROMPatch.swift` is a byte-level IPS/BPS implementation, with bounds checks and BPS CRC32 verification.
7. `scripts/build-retro-homebrew.py` builds the original Game Boy and NES programs. Read the emitter helpers, hardware registers, tile patterns, input polling and battery-backed RAM writes. These are actual ROMs executed by the cores.
8. `Tests/SuiteTests.swift` checks legacy decoding, routing, save-folder isolation, patch operations, corrupted input and a published CRC32 test vector.

The UI is ours. CPU/GPU emulation in the added systems comes from upstream libretro cores. Read Resources/Notices for their identities. A successfully loaded core, a homebrew test, and commercial-game compatibility are different levels of evidence.

### UI sizing and hit testing

`GameCard.artwork` is proposed the grid cell's exact width through a GeometryReader and clipped to 176 points high. The footer is a separate 124-point region. Decorative circles use Canvas, so they cannot impose an intrinsic minimum width on the grid. That is why mixed cover art no longer causes overlaps or irregular gaps.

`Tactile` and `SoftPress` give controls stable hit regions, visible depression, a spring release and native trackpad haptics. The inspector and app error messages are overlays in RootView: their backdrop dismisses them, and Escape closes the top app-owned popup. System file dialogs are still native.


NEXARC 0.3: use System → Your screen. Your setup. for per-console layouts, sizing and skins. Escape opens the paused session menu; it no longer quits directly. Controllers shows a keyboard when no controller is attached. Existing data stays in the NEXARC support folder.


## Save, recovery and per-game features

Start with `ProgressStore.swift` for atomic state copies, core fingerprints, checksums, overwrite backups and bounded recovery history. `ProgressActions.swift` connects these files to asynchronous live-core operations; a slot is confirmed only after the core writes a new stable state. `ProgressViews.swift` contains visual slots and the session recovery dialog. `GameSettingsView.swift` persists optional overrides on each LibraryItem, leaving other games on console defaults.

`SkinPlacementEditor.swift` edits normalized screen rectangles with drag/resize handles. DS/3DS can store two independent areas. `PlayerCompanion.m` draws the split CPU video frames and samples touch coordinates on the main thread; `FastForward.c` translates them into the core's pointer input. `LibraryControllerNavigation.swift` handles controller navigation in the library; the companion handles the in-game menu.

Run `bash scripts/test.sh` for the model, save integrity, routing, patch, pixel conversion and gamepad-remapping checks. These tests use temporary data and do not require a commercial ROM. Title compatibility and physical gamepad behavior require separate runtime checks.
