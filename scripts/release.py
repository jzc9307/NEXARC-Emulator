#!/usr/bin/env python3
"""Version and package NEXARC; contact GitHub only with the publish command."""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SEMVER = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:alpha|beta|rc)\.[1-9]\d*))?")


def run(args, root=ROOT, capture=True, check=True):
    return subprocess.run(args, cwd=root, check=check, text=True,
                          stdout=subprocess.PIPE if capture else None,
                          stderr=subprocess.PIPE if capture else None)


def layout(root=ROOT):
    parent = root.parent
    if (parent / '.nexarc-workspace').is_file():
        return parent, parent / 'outputs'
    return root, root / 'dist'


def parse_version(value):
    match = SEMVER.fullmatch(value)
    if not match:
        raise ValueError('Use a version like 0.3.1 or 0.4.0-beta.1.')
    return tuple(map(int, match.group(1, 2, 3)))


def next_version(current, bump='patch', prerelease=None):
    major, minor, patch = parse_version(current)
    if bump == 'major': major, minor, patch = major + 1, 0, 0
    elif bump == 'minor': minor, patch = minor + 1, 0
    else: patch += 1
    value = f'{major}.{minor}.{patch}'
    return value + (f'-{prerelease}.1' if prerelease else '')


def state(root=ROOT):
    version = (root / 'VERSION').read_text().strip()
    parse_version(version)
    build = int((root / 'BUILD_NUMBER').read_text().strip())
    if build < 1: raise ValueError('BUILD_NUMBER must be positive.')
    return version, build


def atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str): data = data.encode()
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream: stream.write(data)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def sections(changelog):
    return list(re.finditer(r'^## \[([^\]]+)\] - (\d{4}-\d{2}-\d{2})\s*$', changelog, re.M))


def notes_for(changelog, version):
    entries = sections(changelog)
    for i, entry in enumerate(entries):
        if entry[1] == version:
            end = entries[i + 1].start() if i + 1 < len(entries) else len(changelog)
            return changelog[entry.end():end].strip()
    raise ValueError(f'CHANGELOG.md has no entry for {version}.')


def write_metadata(root, version, build, changelog):
    plist_path = root / 'Resources/Info.plist'
    info = plistlib.loads(plist_path.read_bytes())
    info['CFBundleShortVersionString'] = version.split('-')[0]
    info['CFBundleVersion'] = str(build)
    info['NEXARCReleaseVersion'] = version
    readme = (root / 'README.md').read_text()
    marker = r'<!-- nexarc:version -->.*?<!-- /nexarc:version -->'
    block = f'<!-- nexarc:version -->\n**Newest version: `{version}`** · [Version history](docs/RELEASES.md) · [Release guide](docs/GITHUB.md)\n<!-- /nexarc:version -->'
    if not re.search(marker, readme, re.S): raise ValueError('README version markers are missing.')
    readme = re.sub(marker, lambda _: block, readme, flags=re.S)
    rows = []
    for entry in sections(changelog):
        rows.append(f'| `{entry[1]}` | {entry[2]} | {"**Newest**" if entry[1] == version else "Previous"} |')
    history = '# NEXARC version history\n\n'
    history += 'This includes local/prepared versions. Published downloads live in GitHub → Releases.\n\n'
    history += '| Version | Date | Status |\n|---|---|---|\n' + '\n'.join(rows) + '\n\n'
    history += 'See [CHANGELOG.md](../CHANGELOG.md) for changes. Releases keep their original tags and downloads; publishing a new one does not replace older releases. GitHub marks the newest normal release **Latest**. Alpha, beta and rc versions are prereleases.\n'
    updates = {root/'VERSION': version+'\n', root/'BUILD_NUMBER': str(build)+'\n',
               plist_path: plistlib.dumps(info, sort_keys=False), root/'README.md': readme,
               root/'CHANGELOG.md': changelog, root/'docs/RELEASES.md': history}
    original = {p: p.read_bytes() if p.exists() else None for p in updates}
    try:
        for path, data in updates.items(): atomic(path, data)
    except Exception:
        for path, data in original.items():
            if data is None: path.unlink(missing_ok=True)
            else: atomic(path, data)
        raise


def check_metadata(root=ROOT):
    version, build = state(root)
    info = plistlib.loads((root/'Resources/Info.plist').read_bytes())
    expected = (version.split('-')[0], str(build), version)
    actual = tuple(info.get(k) for k in ['CFBundleShortVersionString','CFBundleVersion','NEXARCReleaseVersion'])
    if actual != expected: raise ValueError('Version metadata differs. Run python3 scripts/release.py sync.')
    notes_for((root/'CHANGELOG.md').read_text(), version)
    if f'**Newest version: `{version}`**' not in (root/'README.md').read_text():
        raise ValueError('README version differs. Run release.py sync.')
    return version, build


def prepare(root=ROOT, bump='patch', prerelease=None, notes=None):
    current, build = check_metadata(root)
    pending = local_cache(root,'.release/prepared.json')
    if pending.exists():
        previous = json.loads(pending.read_text())
        if previous.get('version') == current:
            raise ValueError(f'{current} is already prepared. Finish/retry that release instead of bumping twice.')
    version = next_version(current, bump, prerelease)
    changelog = (root/'CHANGELOG.md').read_text()
    unreleased = re.search(r'^## \[Unreleased\]\s*\n(.*?)(?=^## \[|\Z)', changelog, re.M|re.S)
    if not unreleased: raise ValueError('CHANGELOG.md needs an [Unreleased] section.')
    notes = (notes or unreleased[1]).strip()
    if not notes or notes == '_No changes recorded yet._':
        raise ValueError('Add real release notes to [Unreleased], or pass --notes-file.')
    if re.search(r'^## \[', notes, re.M): raise ValueError('Release notes cannot contain version section headings.')
    today = dt.date.today().isoformat()
    replacement = f'## [Unreleased]\n\n_No changes recorded yet._\n\n## [{version}] - {today}\n\n{notes}\n\n'
    updated = changelog[:unreleased.start()] + replacement + changelog[unreleased.end():]
    write_metadata(root, version, build+1, updated)
    atomic(pending, json.dumps({'version':version,'previous':current,'build':build+1}, indent=2)+'\n')
    return version


def files(root=ROOT, tracked=False):
    args=['git','ls-files','-z']
    if not tracked: args += ['--cached','--others','--exclude-standard']
    return sorted(set(p for p in run(args,root).stdout.split('\0') if p))


def preflight(root=ROOT):
    problems=[]
    forbidden={'.keys','.pem','.p12','.p8','.nsp','.xci','.nca','.nds','.3ds','.cia','.iso','.wbfs','.sav','.srm','.state'}
    token=re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,}|(?m:^-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----))')
    for name in files(root):
        path=root/name;parts=Path(name).parts
        if path.is_symlink():
            problems.append(name+': review symlinks before publishing');continue
        if not path.is_file():continue
        if any(p in {'bin','obj','work','dist','.release','Games','Saves','States','Covers','Sessions'} for p in parts):
            problems.append(name+': local/generated data must be ignored');continue
        if path.suffix.lower() in forbidden or path.name=='.env' or path.name.startswith('.env.') and path.name!='.env.example':
            problems.append(name+': personal game data or credential format');continue
        if path.stat().st_size>=100*1024*1024:problems.append(name+': exceeds regular Git file limit')
        if path.suffix.lower() in {'.swift','.m','.c','.h','.py','.sh','.md','.json','.yml','.yaml','.xml','.txt','.cs','.config'}:
            if token.search(path.read_bytes()):problems.append(name+': possible secret; review locally')
    if problems: raise ValueError('\n'.join(problems[:30]))
    return len(files(root))


def clean_head(root=ROOT):
    if run(['git','status','--porcelain'],root).stdout.strip():
        raise ValueError('Commit the reviewed source and version files first. The package must match one clean commit.')
    return run(['git','rev-parse','HEAD'],root).stdout.strip()


def sha(path):
    digest=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):digest.update(block)
    return digest.hexdigest()


def local_cache(root, relative):
    path=root/relative
    cursor=root
    for part in Path(relative).parts:
        cursor=cursor/part
        if cursor.is_symlink():raise ValueError('Release staging must be a real folder inside the source repository; symlinks are not allowed.')
    if not path.resolve().is_relative_to(root.resolve()):
        raise ValueError('Release staging must stay inside the source repository.')
    return path


def acquire_lock(root=ROOT):
    path=local_cache(root,'.release/release.lock');path.parent.mkdir(parents=True,exist_ok=True)
    handle=path.open('a')
    try:fcntl.flock(handle.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close();raise ValueError('Another release command is running. Wait for it to finish.')
    return handle


def package(root=ROOT):
    version,build=check_metadata(root);preflight(root);commit=clean_head(root)
    project,output=layout(root);app=project/'NEXARC.app';binary=output/'NEXARC-macOS.zip'
    if not binary.is_file():raise ValueError('Build the current app with bash scripts/build.sh first.')
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if info.get('NEXARCReleaseVersion')!=version or info.get('CFBundleVersion')!=str(build):
        raise ValueError('The app version differs. Rebuild before packaging.')
    with zipfile.ZipFile(binary) as archive:
        zipped=plistlib.loads(archive.read('NEXARC.app/Contents/Info.plist'))
    if zipped.get('NEXARCReleaseVersion')!=version or zipped.get('CFBundleVersion')!=str(build):
        raise ValueError('The app ZIP version differs. Rebuild before packaging.')
    dest=local_cache(root,'.release/current');dest.mkdir(parents=True,exist_ok=True)
    # This directory is disposable staging; historical downloads stay on GitHub.
    for path in dest.iterdir():
        if path.is_file():path.unlink()
    app_zip=dest/f'NEXARC-{version}-macOS-arm64.zip';shutil.copy2(binary,app_zip)
    source_zip=dest/f'NEXARC-{version}-source.zip'
    with zipfile.ZipFile(source_zip,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for name in files(root,tracked=True):
            path=root/name
            if path.is_file():archive.write(path,'NEXARC/'+name)
    atomic(dest/'NOTES.md',notes_for((root/'CHANGELOG.md').read_text(),version)+'\n')
    assets=[app_zip,source_zip]
    sums=''.join(f'{sha(path)}  {path.name}\n' for path in assets)
    atomic(dest/'SHA256SUMS.txt',sums);assets.append(dest/'SHA256SUMS.txt')
    manifest={'version':version,'build':build,'commit':commit,'assets':{p.name:sha(p) for p in assets}}
    atomic(dest/'manifest.json',json.dumps(manifest,indent=2)+'\n')
    return dest


def publish(root=ROOT, dry_run=False, draft=False):
    version,_=check_metadata(root);preflight(root);commit=clean_head(root)
    pending=local_cache(root,'.release/prepared.json')
    if not pending.exists() or json.loads(pending.read_text()).get('version')!=version:
        raise ValueError('Prepare a new version first; the local baseline is not an automatic release.')
    if run(['git','branch','--show-current'],root).stdout.strip()!='main':
        raise ValueError('Publish from main after reviewing and merging your changes.')
    origin=run(['git','remote','get-url','origin'],root,check=False)
    if origin.returncode:raise ValueError('No origin remote. Connect your GitHub repository first; see docs/GITHUB.md.')
    if not re.fullmatch(r'(?:https://github\.com/|git@github\.com:)[\w.-]+/[\w.-]+(?:\.git)?',origin.stdout.strip()):
        raise ValueError('Use a normal GitHub HTTPS/SSH origin without embedded credentials.')
    dest=local_cache(root,'.release/current');manifest=json.loads((dest/'manifest.json').read_text())
    if manifest['version']!=version or manifest['commit']!=commit:raise ValueError('Repackage the current commit before publishing.')
    for name,digest in manifest['assets'].items():
        if Path(name).name!=name or sha(dest/name)!=digest:raise ValueError('A release asset changed; repackage first.')
    tag='v'+version;is_pre='-' in version
    local_tag=run(['git','rev-parse','--verify',f'refs/tags/{tag}^{{commit}}'],root,check=False)
    if local_tag.returncode==0 and local_tag.stdout.strip()!=commit:
        raise ValueError('This version tag already identifies different code. Never move or overwrite a release tag.')
    commands=[]
    if local_tag.returncode:commands.append(['git','tag','-a',tag,'-m',f'NEXARC {version}'])
    commands.append(['git','push','--atomic','origin','HEAD:refs/heads/main',f'refs/tags/{tag}'])
    create=['gh','release','create',tag,*[str(dest/n) for n in manifest['assets']],
            '--verify-tag','--title',f'NEXARC {version}','--notes-file',str(dest/'NOTES.md'),'--draft']
    if is_pre:create += ['--prerelease']
    commands.append(create)
    if not draft:commands.append(['gh','release','edit',tag,'--draft=false','--latest=false' if is_pre else '--latest=true'])
    if dry_run:
        for command in commands:print(shlex.join(command))
        return
    if not shutil.which('gh'):raise ValueError('GitHub CLI is not installed. Install gh and run gh auth login; see docs/GITHUB.md.')
    run(['gh','auth','status'],root)
    if not is_pre:
        remote_tags=run(['git','ls-remote','--tags','origin'],root).stdout
        for line in remote_tags.splitlines():
            name=line.split('refs/tags/')[-1]
            if name.startswith('v') and SEMVER.fullmatch(name[1:]) and '-' not in name and name!=tag:
                if parse_version(name[1:])>=parse_version(version):raise ValueError('A newer normal version already exists on origin; update main before releasing.')
    # Refuse to rewrite a published release, and allow a failed draft upload to resume.
    existing=run(['gh','release','view',tag,'--json','isDraft,url'],root,check=False)
    resume=False
    if existing.returncode==0:
        record=json.loads(existing.stdout)
        if not record['isDraft']:raise ValueError('This release is already published. Keep it intact and prepare a new version.')
        resume=True
    elif 'not found' not in existing.stderr.lower():
        raise ValueError('Could not check the GitHub release; no push was attempted. '+existing.stderr.strip())
    for command in commands:
        if command==create and resume:
            run(['gh','release','upload',tag,*[str(dest/n) for n in manifest['assets']],'--clobber'],root,capture=False)
            run(['gh','release','edit',tag,'--notes-file',str(dest/'NOTES.md')],root)
        else:run(command,root,capture=False)
    if not draft:pending.unlink()
    print(f'NEXARC {version} '+('draft uploaded; publish it when ready.' if draft else 'published.'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    sub.add_parser('check');sub.add_parser('sync');sub.add_parser('preflight')
    plan=sub.add_parser('plan');plan.add_argument('--bump',choices=['patch','minor','major'],default='patch')
    prep=sub.add_parser('prepare');prep.add_argument('--bump',choices=['patch','minor','major'],default='patch');prep.add_argument('--prerelease',choices=['alpha','beta','rc']);prep.add_argument('--notes-file',type=Path)
    sub.add_parser('package')
    pub=sub.add_parser('publish');pub.add_argument('--dry-run',action='store_true');pub.add_argument('--draft',action='store_true')
    args=parser.parse_args()
    held_lock=None
    try:
        if args.command in {"sync","prepare","package","publish"} and not getattr(args,"dry_run",False):held_lock=acquire_lock()
        if args.command=='check':print('Version metadata OK:',*check_metadata())
        elif args.command=='sync':
            version,build=state();write_metadata(ROOT,version,build,(ROOT/'CHANGELOG.md').read_text());print('Synchronized',version)
        elif args.command=='preflight':print('Source preflight OK:',preflight(),'candidate files; review the staged diff before pushing.')
        elif args.command=='plan':
            version,build=check_metadata();print(f'Current {version} (build {build}); next {next_version(version,args.bump)} (build {build+1}). No files changed.')
            print('Pending release:',(ROOT/'.release/prepared.json').exists())
        elif args.command=='prepare':print('Prepared',prepare(bump=args.bump,prerelease=args.prerelease,notes=args.notes_file.read_text() if args.notes_file else None))
        elif args.command=='package':print('Packaged',package())
        else:publish(dry_run=args.dry_run,draft=args.draft)
    except (ValueError,FileNotFoundError,subprocess.CalledProcessError,KeyError,json.JSONDecodeError) as error:
        print('Release stopped:',str(error),file=sys.stderr);return 1
    finally:
        if held_lock:held_lock.close()
    return 0


if __name__=='__main__':sys.exit(main())
