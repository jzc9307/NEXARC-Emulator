#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd -P)/layout.sh"
NEXARC_RETRO="$NEXARC_PROJECT/work/multiconsole"
mkdir -p "$NEXARC_RETRO/downloads" "$NEXARC_RETRO/cores"
NEXARC_IMAGE="$NEXARC_RETRO/downloads/RetroArch_Metal-1.22.2.dmg"
if [ ! -f "$NEXARC_IMAGE" ]; then
  curl -fL --retry 2 'https://buildbot.libretro.com/stable/1.22.2/apple/osx/universal/RetroArch_Metal.dmg' -o "$NEXARC_IMAGE"
fi
NEXARC_MOUNT="$(mktemp -d /private/tmp/nexarc-retro.XXXXXX)"
trap 'hdiutil detach "$NEXARC_MOUNT" >/dev/null 2>&1 || true; rmdir "$NEXARC_MOUNT" 2>/dev/null || true' EXIT
hdiutil attach -readonly -nobrowse -mountpoint "$NEXARC_MOUNT" "$NEXARC_IMAGE" >/dev/null
ditto --noextattr --norsrc "$NEXARC_MOUNT/RetroArch.app" "$NEXARC_RETRO/RetroArch.app"
python3 - "$NEXARC_SOURCE" "$NEXARC_RETRO" <<'PY'
import sys,pathlib,json,subprocess,zipfile,hashlib
source,root=map(pathlib.Path,sys.argv[1:])
for record in json.loads((source/'Resources/Notices/core-downloads.json').read_text()):
 p=root/'downloads'/(record['core']+'.zip')
 if not p.exists():
  bundled=source/'Vendor/CoreArchives'/(record['core']+'.zip')
  if bundled.exists():p.write_bytes(bundled.read_bytes())
  else:subprocess.run(['curl','-fL','--retry','2',record['url'],'-o',str(p)],check=True)
 if hashlib.sha256(p.read_bytes()).hexdigest()!=record['sha256']:
  raise SystemExit(f"Core snapshot changed: {record['core']}. Review the new upstream build and update the manifest before packaging.")
 with zipfile.ZipFile(p) as archive:
  for name in archive.namelist():
   if name.endswith('.dylib'):(root/'cores'/pathlib.Path(name).name).write_bytes(archive.read(name))
print('Restored all 16 core snapshots.')
PY
