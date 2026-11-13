"""Create a drag-to-Applications macOS installer from the verified app bundle."""
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile


def create(app, target, version, build):
    app=Path(app);target=Path(target)
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if info.get('NEXARCReleaseVersion')!=version or info.get('CFBundleVersion')!=str(build):
        raise ValueError('The app version differs. Rebuild before creating its DMG.')
    subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
    target.parent.mkdir(parents=True,exist_ok=True)
    # Build to a temporary image first so a failed hdiutil invocation keeps the old installer.
    with tempfile.TemporaryDirectory(prefix='nexarc-dmg-',dir=target.parent) as folder:
        temp=Path(folder);stage=temp/'payload';stage.mkdir()
        subprocess.run(['ditto','--noextattr','--norsrc',str(app),str(stage/'NEXARC.app')],check=True)
        (stage/'Applications').symlink_to('/Applications',target_is_directory=True)
        (stage/'Install NEXARC.txt').write_text(f'''NEXARC {version} — Apple Silicon / macOS 14 or later

1. Drag NEXARC.app onto Applications.
2. Eject this disk image and open NEXARC from Applications.
3. Import your own compatible game files.

This build is locally signed and is not notarized by Apple. macOS may block
its first launch; follow your Mac's Privacy & Security settings only if you
trust the source. Do not disable Gatekeeper globally.

No commercial ROMs, console keys, or firmware are included.
Your existing library and progress stay in:
~/Library/Application Support/NEXARC

When updating, quit the game and NEXARC before replacing the app.
Skins, engines and dependencies retain their bundled licenses/notices.
''')
        result=temp/'NEXARC.dmg'
        subprocess.run(['hdiutil','create','-volname','NEXARC '+version,'-srcfolder',str(stage),'-fs','HFS+','-format','UDZO','-ov',str(result)],check=True)
        subprocess.run(['hdiutil','verify',str(result)],check=True)
        os.replace(result,target)
    return target
