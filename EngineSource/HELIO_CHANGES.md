# Helio integration patch

Base: https://github.com/wangxiaoming1988/Ryujinx-fork

Source tag: `macos-metal-clamp-1.3.335`.

The complete core source is preserved here with its existing notices. Helio changes these areas:

- `src/Ryujinx/Program.cs`: a build-time controller-profile validation command using the core's actual JSON serializer.
- `src/Ryujinx/Headless/Options.cs`: an explicit nullable `--docked-mode true/false` option, so saved configuration does not silently override Helio's docked/handheld preference.
- `src/Ryujinx/Headless/HeadlessRyujinx.cs`: load persisted settings before inheriting them; expose actual homebrew loader exceptions; describe missing keys as informational for unencrypted NRO/NSO inputs; provide an isolated process exit path for the two bundled, save-free tests.
- `src/Ryujinx/Headless/Windows/WindowBase.cs`: allow a Helio play-window title through an environment variable, and notice when the guest process exits.

The `HELIO_DIAGNOSTIC=1` environment flag is used only for the bundled First Light and Orbit Pong programs, which do not save user data. Their shutdown exits the dedicated core process after the guest/window loop ends. This avoids an upstream service-thread teardown hang observed when extremely short homebrew exits while services are initializing. General imported games retain the ordinary core disposal path.

No console keys, firmware, commercial games, or Nintendo SDK code are included.


NEXARC 0.3: Headless WindowBase adds Tab-held 2×–5× guest-clock turbo, Shift+Tab 5×, release/focus-loss reset, a local target request file and speed status. GPU presentation is uncapped once at startup; guest compositor pacing controls normal and turbo rates. The swapchain is not recreated on key transitions. SurfaceFlinger recalculates pacing when TickScalar changes. The launcher requests --hide-cursor Never.
