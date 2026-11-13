"""Generate the README download table from actual release state."""
import json
from pathlib import Path
import re

CATALOG='release-history.json'
MARKER=r'<!-- nexarc:version -->.*?<!-- /nexarc:version -->'


def load(root):
    path=root/CATALOG
    data=json.loads(path.read_text()) if path.exists() else {'repository':'jzc9307/NEXARC','versions':{}}
    if not re.fullmatch(r'[\w.-]+/[\w.-]+',data.get('repository','')):raise ValueError('Invalid release repository in release-history.json.')
    if not isinstance(data.get('versions'),dict):raise ValueError('release-history.json needs a versions object.')
    for version,record in data['versions'].items():
        if record.get('status') not in {'local','prepared','published'}:raise ValueError('Invalid release status for '+version)
    return data


def version_key(version):
    core,_,pre=version.partition('-');parts=tuple(int(x) for x in core.split('.'))
    label,_,number=pre.partition('.')
    return (*parts,1 if not pre else 0,{'alpha':0,'beta':1,'rc':2}.get(label,3),int(number or 0))


def ordered(entries):return sorted(entries,key=lambda entry:version_key(entry[0]),reverse=True)


def latest_published(data):
    versions=[v for v,r in data['versions'].items() if r['status']=='published' and '-' not in v]
    return max(versions,key=version_key) if versions else None


def table(data, entries, current):
    base='https://github.com/'+data['repository'];latest=latest_published(data)
    rows=['| Version | Date | Status | macOS installer | Release notes |',
          '|---|---|---|---|---|']
    for version,date in ordered(entries):
        status=data['versions'].get(version,{}).get('status','local')
        if status=='published':
            badge='**Latest**' if version==latest else 'Prerelease' if '-' in version else 'Previous'
            download=f'[Download DMG]({base}/releases/download/v{version}/NEXARC-{version}-macOS-arm64.dmg)'
            notes=f'[What changed]({base}/releases/tag/v{version})'
        else:
            badge=('**Newest** · ' if version==current else '')+('Awaiting publication' if status=='prepared' else 'Local build')
            download='DMG available after publication' if status=='prepared' else 'Not published'
            notes=f'[Changes](CHANGELOG.md#{version.replace(".","") }---{date})'
        rows.append(f'| `{version}` | {date} | {badge} | {download} | {notes} |')
    return '\n'.join(rows)


def render(data, entries, current):
    latest=latest_published(data);base='https://github.com/'+data['repository']
    if latest:
        callout=f'### [Download NEXARC {latest} for macOS]({base}/releases/download/v{latest}/NEXARC-{latest}-macOS-arm64.dmg)\n\nApple Silicon · macOS 14+ · DMG installer · **Latest release**'
    else:
        callout='**The first public DMG has not been published yet.** The local installer is ready to build; public downloads will appear here once a release is published.'
    return f'''<!-- nexarc:version -->
**Newest version: `{current}`**

{callout}

### All versions

{table(data,entries,current)}

Every published version keeps its own DMG, source archive, checksums, and release notes. Older downloads remain available under [GitHub Releases]({base}/releases). Local or prepared versions are listed without a live download link until publication succeeds.
<!-- /nexarc:version -->'''


def update(readme, data, entries, current):
    if not re.search(MARKER,readme,re.S):raise ValueError('README version markers are missing.')
    return re.sub(MARKER,lambda _:render(data,entries,current),readme,flags=re.S)
