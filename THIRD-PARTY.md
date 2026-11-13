# Credits and licenses

NEXARC's native interface, process bridge, controller integration, First Light, and Orbit Pong are project code. The emulation engine is reused upstream work.

## Emulation

- Ryujinx Team and Contributors; Ryubing Team and Contributors; the macOS fork maintainer wangxiaoming1988.
- Source: https://github.com/wangxiaoming1988/Ryujinx-fork/tree/macos-metal-clamp-1.3.335
- MIT license: `EngineSource/LICENSE.txt`.
- Dependencies retain their licenses, including the notices in `EngineSource/distribution/legal/THIRDPARTY.md`. The packaged helper includes these notices.
- The core binary is built from source in this project. The community release was downloaded for initial comparison and checksum verification; its binary is not used in the final package.

## Homebrew tools

- libnx and devkitPro provide the open-source Switch development runtime/toolchain.
- Orbit Pong Makefile template: https://github.com/switchbrew/switch-examples/blob/master/graphics/simplegfx/Makefile
- Framebuffer API reference: https://github.com/switchbrew/switch-examples/blob/master/graphics/simplegfx/source/main.c
- Official toolchain image: `devkitpro/devkita64`, pinned to the digest in `scripts/build-pong.sh`.

## 3D artwork

All three meshes are independently authored reconstructions, not official manufacturer assets. Product names, designs, and trademarks belong to their respective owners.

- **Nintendo Switch** — HarrisonHag1; CC BY 4.0. https://sketchfab.com/3d-models/nintendo-switch-c73fadccfdc547f9958fd8a1cdbe4811 . Reused from the user's Dockside project, including its validated removal of static identity skin declarations. Geometry and textures are preserved; studio lighting/camera are configured by the app.
- **Xbox Wireless Controller** — Chistodrako._.; CC BY 4.0. https://sketchfab.com/3d-models/xbox-inalambric-controller-black-29cc9624894a4f2cae7d2a675044db45 . Distributed by SceneView at https://sceneview.github.io/models/platforms/xbox_wireless_controller.glb . SceneView's catalog provides the source attribution. NEXARC interprets the specular/glossiness material extension and adds its own lighting/camera; geometry is unchanged.
- **PS5 Controller / DualSense** — Taohid Animation; CC BY 4.0. https://sketchfab.com/3d-models/ps5-controller-b7bb9c5102a04cb0b1966c6d02bad7d6 . Mesh distributed by https://github.com/Kollynce/dualsense-controller/blob/main/controller/dualsense.glb with attribution at `controller/ATTRIBUTION.md`. That project split parts into named controls and baked transforms; NEXARC preserves those meshes/textures and configures native SceneKit materials, lighting, and camera.

License copy: `Resources/ConsoleModels/licenses/CC-BY-4.0.txt`.

The GLB reader and console studio were adapted from the user's earlier Dockside source. Controller monitoring uses Apple's GameController framework; the core's gameplay input uses SDL3. NEXARC does not include or contact a third-party artwork API at runtime.

## NEXARC 0.2: multi-console components

RetroArch 1.22.2 (69a4f0ea), GPLv3, from the official universal macOS Metal distribution:
https://buildbot.libretro.com/stable/1.22.2/apple/osx/universal/RetroArch_Metal.dmg
Source: https://github.com/libretro/RetroArch/tree/v1.22.2
The runtime is re-signed locally and its bundle identifier changes to app.nexarc.retro; executable code is unchanged. NEXARC's separate LocalCommands.dylib constrains its selected command port to loopback. Core information files originate from the distribution's assets archive. RetroArch's own third-party dependencies and asset licenses remain applicable.

The 16 Apple Silicon cores are official Libretro buildbot snapshots retrieved on 2026-11-11 (local time). Exact download hashes, names, authors and licenses are included in Resources/Notices. Source projects:

| Core | Source | License family |
|---|---|---|
| Gambatte | https://github.com/libretro/gambatte-libretro | GPLv2 |
| mGBA | https://github.com/libretro/mgba | MPLv2 |
| FCEUmm | https://github.com/libretro/libretro-fceumm | GPLv2 |
| Snes9x | https://github.com/libretro/snes9x | Snes9x license |
| ParaLLEl N64 | https://github.com/libretro/parallel-n64 | GPLv2 |
| melonDS DS | https://github.com/JesseTG/melonds-ds | GPLv3 |
| Azahar | https://github.com/azahar-emu/azahar | GPLv2+ |
| Dolphin | https://github.com/libretro/dolphin | GPLv2+ |
| Genesis Plus GX | https://github.com/libretro/Genesis-Plus-GX | Noncommercial |
| Flycast | https://github.com/libretro/flycast | GPLv2 |
| Beetle Saturn | https://github.com/libretro/beetle-saturn-libretro | GPLv2 |
| PCSX ReARMed | https://github.com/libretro/pcsx_rearmed | GPLv2 |
| Play! | https://github.com/jpd002/Play- | MIT |
| PPSSPP | https://github.com/hrydgard/ppsspp | GPLv2+ |
| Beetle PCE Fast | https://github.com/libretro/beetle-pce-fast-libretro | GPLv2 |
| Stella | https://github.com/libretro/stella | GPLv2 |

Use the included machine-readable CORE-LICENSES.json for upstream authorship and license labels. These are separate works; NEXARC's MIT license does not relicense them. PPSSPP and Dolphin support assets come from https://buildbot.libretro.com/assets/system/PPSSPP.zip and Dolphin.zip; included font and other license notices are retained.

2048 for 3DS v1.1.1 is by 0rientd, ported from the upstream Linux game, MIT-licensed. Source and original license are included in ThirdPartySources/2048-3DS. The release binary is unmodified:
https://github.com/0rientd/2048-port-3ds/releases/tag/v1.1.1

Orbit Catch and Color Signal and their tiny assemblers are original NEXARC code under the project MIT license. All newly generated console studio models are original code-built stylizations. Switch and controller model credits above are unchanged.

The former schematic Nintendo/generic controller block was replaced with original NEXARC studio meshes in ProControllerModel.swift. These meshes use the project MIT license and contain no downloaded model assets. Imported Xbox and DualSense attribution is unchanged.


## Optional cover artwork

NEXARC may request public cover thumbnails from https://github.com/libretro-thumbnails/libretro-thumbnails. Artwork remains the copyright of its respective owners. No commercial covers or ROMs are bundled. Downloaded art is a local cache; a user-selected image takes precedence.

## Handheld hardware skins

Artwork by Duimon from https://github.com/Duimon/Retroarch-Overlays, licensed Creative Commons Attribution-NonCommercial-NoDerivatives 4.0. PNG artwork is bundled unchanged in Resources/Skins/Hardware. Source URLs and file hashes are included in SOURCES.json, together with the original license and credits. NEXARC adds screen-placement metadata separately. These hardware reproductions are community artwork and are not official Nintendo, Sony or SEGA assets.
