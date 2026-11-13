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

## Nintendo Pro and generic controller studio meshes

The Nintendo Pro-layout and generic-layout previews are original NEXARC geometry in `Sources/ProControllerModel.swift`, under the project MIT license. They include a Bezier shell, grip panels, analog-stick assemblies, shoulder controls, D-pad, face/menu buttons, and printed labels. They are descriptive family layouts, not official Nintendo assets or scans. Live button highlighting and stick motion use macOS GameController input when a device is connected.
