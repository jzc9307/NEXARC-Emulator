#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd -P)/layout.sh"
python3 "$NEXARC_SOURCE/scripts/release.py" check
mkdir -p "$NEXARC_OUTPUT"
NEXARC_STAGE="$(mktemp -d /private/tmp/nexarc-build.XXXXXX)"
trap 'rm -rf "$NEXARC_STAGE"' EXIT
NEXARC_APP="$NEXARC_STAGE/NEXARC.app"
NEXARC_WORK="$NEXARC_PROJECT/work"
mkdir -p "$NEXARC_APP/Contents/MacOS" "$NEXARC_APP/Contents/Resources" "$NEXARC_APP/Contents/Helpers" "$NEXARC_WORK/swift-cache"
python3 "$NEXARC_SOURCE/scripts/build-homebrew.py"
python3 "$NEXARC_SOURCE/scripts/build-retro-homebrew.py"
xcrun swiftc -swift-version 5 -O -module-cache-path "$NEXARC_WORK/swift-cache" \
  -target arm64-apple-macos14 -parse-as-library "$NEXARC_SOURCE"/Sources/*.swift \
  -framework SwiftUI -framework AppKit -framework SceneKit -framework Metal -framework GameController \
  -o "$NEXARC_APP/Contents/MacOS/NEXARC"
clang -dynamiclib -O2 -arch arm64 -mmacosx-version-min=14.0 "$NEXARC_SOURCE/Sources/LocalCommands.c" -o "$NEXARC_APP/Contents/Resources/LocalCommands.dylib"
codesign --force --sign - "$NEXARC_APP/Contents/Resources/LocalCommands.dylib"
clang -dynamiclib -fobjc-arc -O2 -arch arm64 -mmacosx-version-min=14.0 -framework AppKit -framework GameController "$NEXARC_SOURCE/Sources/PlayerCompanion.m" "$NEXARC_SOURCE/Sources/FastForward.c" -o "$NEXARC_APP/Contents/Resources/PlayerCompanion.dylib"
codesign --force --sign - "$NEXARC_APP/Contents/Resources/PlayerCompanion.dylib"
cp "$NEXARC_SOURCE/Resources/Info.plist" "$NEXARC_APP/Contents/Info.plist"
ditto "$NEXARC_SOURCE/Resources/Skins" "$NEXARC_APP/Contents/Resources/Skins"
ditto "$NEXARC_SOURCE/Resources/ConsoleModels" "$NEXARC_APP/Contents/Resources/ConsoleModels"
ditto "$NEXARC_SOURCE/Resources/ControllerModels" "$NEXARC_APP/Contents/Resources/ControllerModels"
ditto "$NEXARC_SOURCE/Resources/Homebrew" "$NEXARC_APP/Contents/Resources/Homebrew"
ditto "$NEXARC_SOURCE/Resources/Notices" "$NEXARC_APP/Contents/Resources/Notices"
cp "$NEXARC_SOURCE/THIRD-PARTY.md" "$NEXARC_APP/Contents/Resources/THIRD-PARTY.md"
cp "$NEXARC_SOURCE/LICENSE" "$NEXARC_APP/Contents/Resources/NEXARC-LICENSE.txt"
ditto "$NEXARC_SOURCE/docs" "$NEXARC_APP/Contents/Resources/Guides"
if [ -f "$NEXARC_SOURCE/Resources/NEXARC.icns" ]; then cp "$NEXARC_SOURCE/Resources/NEXARC.icns" "$NEXARC_APP/Contents/Resources/"; fi
if [ -f "$NEXARC_WORK/engine-build/Ryujinx" ]; then
  mkdir -p "$NEXARC_APP/Contents/Helpers/Ryujinx.app/Contents/MacOS" "$NEXARC_APP/Contents/Helpers/Ryujinx.app/Contents/Resources"
  cp "$NEXARC_SOURCE/Resources/CoreInfo.plist" "$NEXARC_APP/Contents/Helpers/Ryujinx.app/Contents/Info.plist"
  cp "$NEXARC_SOURCE/EngineSource/distribution/macos/Ryujinx.icns" "$NEXARC_APP/Contents/Helpers/Ryujinx.app/Contents/Resources/"
  cp "$NEXARC_SOURCE/EngineSource/distribution/macos/Assets.car" "$NEXARC_APP/Contents/Helpers/Ryujinx.app/Contents/Resources/"
  cp "$NEXARC_WORK/engine-build/Ryujinx" "$NEXARC_APP/Contents/Helpers/Ryujinx.app/Contents/MacOS/Ryujinx"
  # The self-contained publish places native libraries beside the executable.
  find "$NEXARC_WORK/engine-build" -maxdepth 1 -name '*.dylib' -exec cp {} "$NEXARC_APP/Contents/Helpers/Ryujinx.app/Contents/MacOS/" \;
  cp "$NEXARC_WORK/engine-build/LICENSE.txt" "$NEXARC_APP/Contents/Helpers/Ryujinx.app/Contents/Resources/CORE-LICENSE.txt"
  cp "$NEXARC_WORK/engine-build/THIRDPARTY.md" "$NEXARC_APP/Contents/Helpers/Ryujinx.app/Contents/Resources/CORE-THIRDPARTY.md"
  find "$NEXARC_APP/Contents/Helpers/Ryujinx.app" -name '*.dylib' -type f -exec codesign --force --sign - {} \;
  codesign --force --sign - --entitlements "$NEXARC_SOURCE/Resources/Core.entitlements" "$NEXARC_APP/Contents/Helpers/Ryujinx.app"
else
  echo "Emulation core missing. Run scripts/build-core.sh first." >&2
  exit 1
fi
# The official RetroArch runtime hosts the independent libretro cores.
if [ ! -f "$NEXARC_WORK/multiconsole/RetroArch.app/Contents/MacOS/RetroArch" ]; then
  echo "RetroArch runtime missing. Run scripts/fetch-retro.sh first." >&2; exit 1
fi
ditto --noextattr --norsrc "$NEXARC_WORK/multiconsole/RetroArch.app" "$NEXARC_APP/Contents/Helpers/RetroArch.app"
ditto --noextattr --norsrc "$NEXARC_WORK/multiconsole/cores" "$NEXARC_APP/Contents/Resources/Cores"
ditto --noextattr --norsrc "$NEXARC_SOURCE/Resources/CoreInfo" "$NEXARC_APP/Contents/Resources/CoreInfo"
ditto --noextattr --norsrc "$NEXARC_SOURCE/Resources/SystemAssets" "$NEXARC_APP/Contents/Resources/SystemAssets"
cp "$NEXARC_SOURCE/Resources/core-metadata.json" "$NEXARC_APP/Contents/Resources/"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier app.nexarc.retro' "$NEXARC_APP/Contents/Helpers/RetroArch.app/Contents/Info.plist"
find "$NEXARC_APP/Contents/Resources/Cores" -name '*.dylib' -exec codesign --force --sign - {} \;
find "$NEXARC_APP/Contents/Helpers/RetroArch.app/Contents/Frameworks" -type f \( -name '*.dylib' -o -name 'MoltenVK' \) -exec codesign --force --sign - {} \;
find "$NEXARC_APP/Contents/Helpers/RetroArch.app/Contents/Frameworks" -maxdepth 1 -name '*.framework' -exec codesign --force --sign - {} \;
codesign --force --sign - --entitlements "$NEXARC_SOURCE/Resources/Core.entitlements" "$NEXARC_APP/Contents/Helpers/RetroArch.app"
codesign --force --sign - "$NEXARC_APP"
codesign --verify --deep --strict "$NEXARC_APP"
touch "$NEXARC_APP"
ditto --noextattr --norsrc -c -k --keepParent "$NEXARC_APP" "$NEXARC_OUTPUT/NEXARC-macOS.zip"
mkdir -p "$NEXARC_PROJECT"
# Keep one directly launchable app at the project root. Rebuilds replace it in place.
# A live game can still be loading shaders and core resources from this bundle.
python3 - <<'PYGUARD'
import pathlib,json,os,time
root=pathlib.Path.home()/"Library/Application Support/NEXARC/Games"
for path in root.glob("*/session-status.json"):
 if time.time()-path.stat().st_mtime>15:continue
 try:
  pid=int(json.loads(path.read_text()).get("pid",0))
  if pid<=1:continue
  os.kill(pid,0)
 except (ProcessLookupError,ValueError,json.JSONDecodeError):continue
 except PermissionError:pass
 raise SystemExit("Close the running game before updating NEXARC.app. The app has been kept intact.")
PYGUARD
rm -rf "$NEXARC_PROJECT/NEXARC.app"
ditto --noextattr --norsrc "$NEXARC_APP" "$NEXARC_PROJECT/NEXARC.app"
codesign --verify --deep --strict "$NEXARC_PROJECT/NEXARC.app"
echo "Built $NEXARC_OUTPUT/NEXARC-macOS.zip"
echo "App: $NEXARC_PROJECT/NEXARC.app"
