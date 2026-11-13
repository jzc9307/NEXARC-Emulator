# NEXARC 0.3 verification

Verified on the user's Apple M5 Mac, macOS 27.0.1, Apple Silicon build. The app targets macOS 14+, but older OS versions have not been exercised.

## Engine evidence

- All 16 added arm64 core binaries were opened with dlopen and their real libretro system-information functions called. Recorded names include Gambatte, mGBA, FCEUmm, Snes9x, ParaLLEl N64, melonDS DS, Azahar, Dolphin, Genesis Plus GX, Flycast, Beetle Saturn, PCSX ReARMed, Play!, PPSSPP, Beetle PCE Fast and Stella.
- Game Boy: Orbit Catch visibly rendered, processed directional input, updated its score, and produced 8 KB battery-backed SRAM on disk.
- Game Boy: F5 produced an actual state file and PNG thumbnail. Normal native Quit created a compressed `.state.auto` snapshot. Relaunch with Resume reported successful automatic state loading in the real core log.
- Final native app: the Quick save button produced its confirmation after a real slot-0 state write; Load slot 0 and Save & exit worked, with status 0 and an auto state on disk.
- NES: Color Signal visibly rendered through FCEUmm and exited normally with an auto state.
- Local command transport: an isolated test wrote a save state, loaded it and exited with status 0. The bind hook and lsof confirmed the command listener was on 127.0.0.1, not a LAN interface. The buggy upstream GET_STATUS operation is not used by NEXARC.
- 3DS: 0rientd's original release of 2048 v1.1.1 visibly rendered both screens, and keyboard input moved/spawned tiles. Azahar's Vulkan renderer failed with a core worker-thread crash; the default was changed to its working software renderer. This is a homebrew rendering/input test, not proof of commercial-game performance.
- Switch: the existing source-built Ryujinx-derived core is retained. Its First Light ARM64 test and Orbit Pong rendering/keyboard/exit checks passed in the earlier build. No commercial Switch games have been tested.

## Library and data tests

`Tests/SuiteTests.swift` passed for all console routes, ambiguous disc detection, legacy Switch JSON decoding, unique save locations for identical filenames, IPS writes and RLE expansion, BPS actions and CRC32 checks, wrong-source rejection, truncated patch rejection and the standard CRC32 vector.

Retro imports copy local files and referenced cue/gdi tracks into a UUID folder. Large Switch imports retain their original path. No downloads, account login or cloud upload are part of importing games. Save backups exclude ROMs. The original ROM is retained when applying a patch.

## Boundaries

A bundled engine route does not establish title compatibility. DS, GBA, SNES, N64, GameCube/Wii, Sega systems, PlayStation, PSP, PC Engine and Atari have core-load checks; they have not all received title-level gameplay checks. PS2 is explicitly experimental. Physical controllers, rumble, motion and multi-player remain untested. User-supplied BIOS, firmware, encrypted games and commercial ROM hacks were not available for validation.

Save states are specific to the core and version. In-game saves are preferable for long-term progress. Switch uses normal game saves, with no save-state feature in NEXARC.

## UI revision

The library now constrains every artwork pane, uses equal-height cards and consistent grid spacing, increases small typography, enlarges compact button hit targets, adds press feedback/haptics, and presents app-owned dialogs with a dismissible backdrop and Escape handling. Native operating-system file pickers retain standard macOS behavior.

Final UI checks observed equal-height aligned cards, larger readable labels and buttons, a sidebar that fits the window, successful backdrop dismissal and Escape dismissal. Deep code-signature verification still passed after gameplay.

## Controller preview correction

The Nintendo Pro and generic box placeholders have been replaced by original contoured meshes. The Nintendo layout has offset analog sticks, a cross D-pad, correctly positioned A/B/X/Y, L/R and ZL/ZR, +/−, capture/home controls and grip panels. Preview framing follows the actual mesh bounds. Labels in the mapping editor now match the selected family. The procedural model is labeled as a NEXARC studio mesh; it is not an official scanned Nintendo asset. Physical-controller testing remains pending.


## NEXARC 0.3 player revision

- The user’s imported DS program was tested through an isolated `/tmp` library, referencing the local ROM read-only. Existing library JSON and save folders were backed up before checks; tests wrote progress only in the isolated directory.
- The Cocoa event-loop issue was reproduced in upstream source: a `kCFRunLoopBeforeWaiting` observer advances emulation, but no periodic event reliably woke it. The companion adds a common-mode 60 Hz timer without calling emulation twice. Two save-state thumbnails captured several seconds apart, with no mouse or keyboard input between them, had different image hashes and state sizes. DS animation now progresses without pointer movement.
- DS Escape opened the native NEXARC paused menu. Escape resumed. Quick save wrote a state, Load restored it, fullscreen transition preserved the menu, and Save & return ended with exit status 0 and an auto state. The Load button enables when the first save finishes.
- The selected DS side-by-side layout now reports actual core geometry **512×192, aspect 2.667**. The initial stacked layout reported **256×400**, including a 16-pixel gap. A misnamed config key was corrected to upstream’s `global_core_options`; per-game layout settings now override stale core defaults.
- 3DS 2048 rendered both screens, keyboard input moved/merged tiles and increased the score, quick save wrote successfully, load worked, and Save & return exited with status 0.
- Cover matching found the imported DS title automatically. Native visual inspection confirmed the full case artwork, solid readable status badge, clean title, padded return button and elapsed timer. Matching is exact after normalization, not a fuzzy sequel match.
- No-controller Controls view showed the keyboard diagram and binding selectors. These selectors feed actual per-game configuration; physical controller behavior remains untested.
- Added regression checks cover old SavedState decoding with absent player settings, cleaned titles, core option routing, Escape reserved for the session menu and a custom keyboard binding in the generated config.

The new skins/layouts have received focused DS/3DS checks. Wider console title compatibility and physical devices are not implied by these tests. Switch retains its separate core and save workflow; the new Escape companion and retro skins apply to RetroArch-hosted systems.


## Final interaction and speed checks

The approved Warp mark replaces the N badge in the sidebar, intro and app icon. Primary app buttons were returned to compact 32-point desktop sizing. Native inspection confirmed aligned controller-page panels and the updated keyboard diagram. The Nintendo Pro preview was inspected in the app and shows its contoured shell, sticks, D-pad and labeled buttons.

The stock pause buttons were replaced with original drawn controls matching NEXARC, using direct mouse-down actions instead of a tracking loop. Fullscreen event hit-testing uses the event’s screen position; panel controls retain their own native mouse delivery. In a normal app-launched Game Boy session, the fullscreen menu successfully quick-saved, enabled Load, restored the state and saved/returned with exit 0. The separate early command harness had different default save sorting and quit-confirmation settings; those were corrected in the harness and are not used by the app.

Instrumented libretro frame counts measured approximately 119.8 / 179.6 / 239.2 / 298.8 frames per second during held 2× / 3× / 4× / 5× controls in Gambatte (about 60 FPS normally). Releasing restored 1×. The implementation uses libretro’s documented fast-forward override; no ROM memory is patched. The Switch host uses its existing TickScalar turbo clock and updates compositor pacing when the scalar changes. These are target multipliers; demanding titles may run slower.

Cursor protection is confined to the owned retro player process. It blocks its automatic hide calls, prevents hide-until-movement behavior, restores the arrow on opening the menu/fullscreen transitions and disables auto mouse grabbing. Switch receives its own `--hide-cursor Never` option.


## Progress, recovery and display revision — 13 November 2026

- Six visual slots retain thumbnails, timestamps, core-build fingerprints and SHA-256 checksums. Live save/overwrite/load checks used copied DS saves in a temporary library. Overwriting retained the old slot, loading protected current play first, and incomplete/core-mismatched states were rejected by the file tests. Recovery history remained bounded at ten copies. Slot and recovery folders are included in save exports.
- The integrated DS test exercised the same request-file handshake used by F5 and the pause-menu controls while paused, resumed the menu through the library command, refreshed the display, continued unattended for 30 seconds, restarted with automatic state loading disabled, and exited normally with a resume snapshot. It used the user's latest resume file copied read-only into the test library. Source saves and the normal library were not modified by QA.
- A repeat test stalled in the upstream CoreAudio write function. A process sample showed the main emulation thread waiting in `coreaudio_write`/`pthread_cond_wait`. The generated retro configuration now uses nonblocking audio (`audio_sync=false`) with vsync retaining display pacing.
- DS/3DS software output is now drawn directly in the NEXARC presentation view, including normal, hardware and custom skins. This avoids depending on a reparented Metal drawable continuing to present after a state reload. The Classic DS test visibly displayed the resumed game and continued presenting after save/load and display refresh; the recovery snapshot recorded 2,058 presented frames and 2,286 emulated frames. This is a focused regression check, not proof that every possible blackout cause is eliminated. GPU-only output falls back to its native renderer; stale CPU frames are invalidated when a core switches to hardware output.
- Separate uploaded top/touch rectangles were visually checked against real DS video. Pointer coordinates are sampled on the main thread and read by core callbacks through a lock-protected cache. Pixel conversion checks cover XRGB8888, RGB565 and RGB1555; gamepad checks cover individual buttons, bitmasks and unaffected second-player input.
- Per-game display, skin, keyboard, speed, gamepad layout and Switch-controller snapshots survive encoding/decoding. Library selection/details/back and slot navigation were checked through synthetic button sets. No physical controller was connected; device behavior and stick-button menu chords still need hardware testing.
- Native UI inspection covered the six-slot grid, recovery dialog, compact custom pause buttons/slot tabs, per-game controls and independent-screen editor. Window presets provide Small, Standard, Large, Fit to display and Custom; tests check legacy defaults, both dimensions, display margins and persistence.

Run `bash scripts/test.sh` for the repeatable model, save integrity, configuration, patching, pixel and input checks. UI/gameplay checks require a Mac desktop session. Restart an already open NEXARC app after replacing the app bundle so the new launch configuration is used.
