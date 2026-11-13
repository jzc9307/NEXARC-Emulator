import contextlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest import mock
import zipfile

SPEC=importlib.util.spec_from_file_location('nexarc_release',Path(__file__).resolve().parents[1]/'scripts/release.py')
release=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        def fake_dmg(app,target,version,build):
            Path(target).write_bytes(b'dmg-fixture:'+version.encode());return target
        patch=mock.patch.object(release.dmg,'create',side_effect=fake_dmg);patch.start();self.addCleanup(patch.stop)
        self.temp=tempfile.TemporaryDirectory(prefix='nexarc-release-test-');self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        (self.root/'Resources').mkdir();(self.root/'docs').mkdir()
        (self.root/'VERSION').write_text('0.3.0\n');(self.root/'BUILD_NUMBER').write_text('3\n')
        (self.root/'Resources/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString':'0.3.0','CFBundleVersion':'3'}))
        (self.root/'Resources/CoreInfo.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString':'1.3.335'}))
        (self.root/'README.md').write_text('# NEXARC\n<!-- nexarc:version -->\n<!-- /nexarc:version -->\n')
        changelog='# Changelog\n\n## [Unreleased]\n\n_No changes recorded yet._\n\n## [0.3.0] - 2026-11-13\n\nLocal baseline.\n'
        (self.root/'CHANGELOG.md').write_text(changelog)
        (self.root/'.gitignore').write_text('/.release/\n/dist/\n*.app/\n/work/\n**/bin/\n**/obj/\n')
        release.write_metadata(self.root,'0.3.0',3,changelog)
        data=release.release_catalog.load(self.root);data['repository']='example/NEXARC';(self.root/'release-history.json').write_text(__import__('json').dumps(data));release.write_metadata(self.root,'0.3.0',3,changelog)
        self.git('init','-b','main');self.git('config','user.name','NEXARC test fixture');self.git('config','user.email','fixture@example.invalid')

    def git(self,*args):
        return subprocess.run(['git',*args],cwd=self.root,check=True,capture_output=True,text=True).stdout

    def commit(self):
        self.git('add','.');self.git('commit','-m','Fixture snapshot')

    def prepared(self,pre=None):
        return release.prepare(self.root,prerelease=pre,notes='- A real fixture improvement.\n- Preserve existing progress.')

    def built(self):
        app=self.root/'NEXARC.app/Contents';app.mkdir(parents=True,exist_ok=True)
        info=(self.root/'Resources/Info.plist').read_bytes();(app/'Info.plist').write_bytes(info)
        output=self.root/'dist';output.mkdir(exist_ok=True)
        with zipfile.ZipFile(output/'NEXARC-macOS.zip','w') as archive:archive.writestr('NEXARC.app/Contents/Info.plist',info)

    def package(self,pre=None):
        self.prepared(pre);self.commit();self.built();return release.package(self.root)

    def test_semantic_version_increments(self):
        self.assertEqual(release.next_version('0.3.9'),'0.3.10')
        self.assertEqual(release.next_version('0.3.9','minor'),'0.4.0')
        self.assertEqual(release.next_version('0.3.9','major'),'1.0.0')
        for value in ['0.03.0','1.2','1.2.3;echo x','1.2.3-beta.0']:
            with self.assertRaises(ValueError):release.parse_version(value)

    def test_prepare_syncs_all_app_metadata_and_preserves_engine_version(self):
        engine=(self.root/'Resources/CoreInfo.plist').read_bytes()
        self.assertEqual(self.prepared(),'0.3.1')
        self.assertEqual(release.check_metadata(self.root),('0.3.1',4))
        self.assertEqual(engine,(self.root/'Resources/CoreInfo.plist').read_bytes())
        history=(self.root/'docs/RELEASES.md').read_text()
        self.assertIn('| `0.3.1` |',history);self.assertIn('| `0.3.0` |',history)
        self.assertEqual(history.count('**Newest**'),1)
        self.assertIn('Local baseline.',(self.root/'CHANGELOG.md').read_text())

    def test_pending_release_cannot_bump_twice_on_retry(self):
        self.prepared()
        with self.assertRaisesRegex(ValueError,'already prepared'):self.prepared()
        self.assertEqual(release.state(self.root),('0.3.1',4))

    def test_empty_notes_do_not_change_version(self):
        with self.assertRaisesRegex(ValueError,'real release notes'):release.prepare(self.root)
        self.assertEqual(release.state(self.root),('0.3.0',3))

    def test_prerelease_keeps_numeric_macos_version(self):
        self.prepared('beta')
        info=plistlib.loads((self.root/'Resources/Info.plist').read_bytes())
        self.assertEqual(info['NEXARCReleaseVersion'],'0.3.1-beta.1')
        self.assertEqual(info['CFBundleShortVersionString'],'0.3.1')

    def test_package_contains_only_committed_source_and_matching_versions(self):
        dest=self.package()
        (self.root/'dist/private.keys').write_text('fixture, not a real key')
        dest=release.package(self.root)
        with zipfile.ZipFile(dest/'NEXARC-0.3.1-source.zip') as archive:
            names=archive.namelist();self.assertIn('NEXARC/VERSION',names)
            self.assertFalse(any('private.keys' in name or '/.git/' in name or '/dist/' in name for name in names))
        self.assertTrue((dest/'SHA256SUMS.txt').is_file())
        self.assertTrue((dest/'NEXARC-0.3.1-macOS-arm64.dmg').is_file())

    def test_source_archive_uses_committed_bytes_not_hidden_checkout_edits(self):
        self.package();(self.root/'.gitattributes').write_text('*.md text eol=lf\n');self.commit()
        readme=self.root/'README.md';readme.write_bytes(readme.read_bytes().replace(b'\n',b'\r\n'))
        # Model a checkout filter/assume-unchanged file. The archive must use
        # Git's committed bytes even when the working tree looks clean.
        self.git('update-index','--assume-unchanged','README.md')
        self.assertEqual(self.git('status','--porcelain').strip(),'')
        dest=release.package(self.root)
        with zipfile.ZipFile(dest/'NEXARC-0.3.1-source.zip') as archive:
            expected=subprocess.check_output(['git','show','HEAD:README.md'],cwd=self.root)
            self.assertEqual(archive.read('NEXARC/README.md'),expected)

    def test_package_rejects_dirty_source_and_stale_binary(self):
        self.package();(self.root/'README.md').write_text((self.root/'README.md').read_text()+'\nUncommitted change\n')
        with self.assertRaisesRegex(ValueError,'Commit the reviewed'):release.package(self.root)
        self.commit()
        info=plistlib.loads((self.root/'NEXARC.app/Contents/Info.plist').read_bytes());info['NEXARCReleaseVersion']='0.2.0'
        (self.root/'NEXARC.app/Contents/Info.plist').write_bytes(plistlib.dumps(info))
        with self.assertRaisesRegex(ValueError,'app version differs'):release.package(self.root)

    def test_personal_rom_and_mock_secret_are_rejected(self):
        (self.root/'private.nds').write_bytes(b'fixture')
        with self.assertRaisesRegex(ValueError,'personal game data'):release.preflight(self.root)
        (self.root/'private.nds').unlink();(self.root/'token.txt').write_text('ghp_'+'x'*40)
        with self.assertRaisesRegex(ValueError,'possible secret'):release.preflight(self.root)

    def test_staging_cannot_escape_through_a_symlink(self):
        with tempfile.TemporaryDirectory() as elsewhere:
            (self.root/'.release').symlink_to(elsewhere,target_is_directory=True)
            with self.assertRaisesRegex(ValueError,'inside the source repository'):self.prepared()
            self.assertEqual(release.state(self.root),('0.3.0',3))

    def test_internal_staging_symlink_cannot_target_source(self):
        (self.root/'.release').symlink_to(self.root/'Resources',target_is_directory=True)
        with self.assertRaisesRegex(ValueError,'symlinks are not allowed'):self.prepared()
        self.assertTrue((self.root/'Resources/Info.plist').is_file())

    def test_release_commands_do_not_run_concurrently(self):
        first=release.acquire_lock(self.root)
        try:
            with self.assertRaisesRegex(ValueError,'Another release command'):release.acquire_lock(self.root)
        finally:first.close()
        release.acquire_lock(self.root).close()

    def test_dry_publish_preserves_tags_and_selects_latest_only_for_normal_release(self):
        self.package();self.git('remote','add','origin','https://github.com/example/NEXARC.git')
        out=io.StringIO()
        with contextlib.redirect_stdout(out):release.publish(self.root,dry_run=True)
        self.assertIn('--latest=true',out.getvalue());self.assertIn('--atomic',out.getvalue())
        self.assertIn('--draft',out.getvalue());self.assertEqual(self.git('tag').strip(),'')

    def test_prerelease_does_not_replace_latest(self):
        self.package('alpha');self.git('remote','add','origin','git@github.com:example/NEXARC.git')
        out=io.StringIO()
        with contextlib.redirect_stdout(out):release.publish(self.root,dry_run=True)
        self.assertIn('--prerelease',out.getvalue());self.assertIn('--latest=false',out.getvalue())

    def test_existing_version_tag_cannot_move_to_different_code(self):
        self.commit();self.git('tag','v0.3.1');self.prepared();self.commit();self.built();release.package(self.root)
        self.git('remote','add','origin','https://github.com/example/NEXARC.git')
        with self.assertRaisesRegex(ValueError,'different code'):release.publish(self.root,dry_run=True)

    def published_record(self,manifest):
        return {'draft':False,'tag_name':'v'+manifest['version'],'published_at':'2026-11-13T06:00:00Z',
                'html_url':'https://github.com/example/NEXARC/releases/tag/v'+manifest['version'],
                'assets':[{'name':name,'state':'uploaded','digest':'sha256:'+digest} for name,digest in manifest['assets'].items()]}

    def publication_runner(self,record,commit,fail_push=False):
        original=release.run
        def fake(args,root=release.ROOT,capture=True,check=True):
            if args[:2]==['gh','api']:return subprocess.CompletedProcess(args,0,json.dumps(record),'')
            if args[:3]==['git','ls-remote','--tags']:return subprocess.CompletedProcess(args,0,commit+'\trefs/tags/'+record['tag_name']+'^{}\n','')
            if args[:2]==['git','push']:
                if fail_push:raise subprocess.CalledProcessError(1,args)
                return subprocess.CompletedProcess(args,0,'','')
            return original(args,root,capture,check)
        return fake

    def test_main_readme_has_every_version_and_only_real_download_links(self):
        self.prepared()
        readme=(self.root/'README.md').read_text()
        self.assertIn('### All versions',readme);self.assertIn('| `0.3.1` |',readme);self.assertIn('| `0.3.0` |',readme)
        self.assertNotIn('/releases/download/',readme)
        catalog=release.release_catalog.load(self.root);catalog['versions']['0.3.0']['status']='published'
        release.write_metadata(self.root,'0.3.1',4,(self.root/'CHANGELOG.md').read_text(),catalog=catalog)
        readme=(self.root/'README.md').read_text()
        self.assertIn('/releases/download/v0.3.0/NEXARC-0.3.0-macOS-arm64.dmg',readme)
        self.assertNotIn('/releases/download/v0.3.1/',readme)

    def test_published_prerelease_preserves_stable_latest(self):
        self.prepared('beta');catalog=release.release_catalog.load(self.root)
        catalog['versions']['0.3.0']['status']='published';catalog['versions']['0.3.1-beta.1']['status']='published'
        release.write_metadata(self.root,'0.3.1-beta.1',4,(self.root/'CHANGELOG.md').read_text(),catalog=catalog)
        readme=(self.root/'README.md').read_text()
        self.assertIn('[Download NEXARC 0.3.0 for macOS]',readme)
        self.assertIn('/NEXARC-0.3.1-beta.1-macOS-arm64.dmg',readme)
        self.assertIn('| Prerelease |',readme)

    def test_publication_updates_readme_only_after_dmg_and_tag_verified(self):
        dest=self.package();manifest=json.loads((dest/'manifest.json').read_text());record=self.published_record(manifest)
        pending=self.root/'.release/prepared.json'
        with mock.patch.object(release,'run',side_effect=self.publication_runner(record,manifest['commit'])):
            release.finish_publication(self.root,'0.3.1',manifest,pending)
        self.assertFalse(pending.exists());self.assertEqual(self.git('status','--porcelain').strip(),'')
        readme=(self.root/'README.md').read_text()
        self.assertIn('NEXARC-0.3.1-macOS-arm64.dmg',readme);self.assertIn('| **Latest** |',readme)
        changed=self.git('diff','--name-only','HEAD~1','HEAD').splitlines()
        self.assertEqual(set(changed),{'README.md','docs/RELEASES.md','release-history.json'})
        self.assertEqual(json.loads((dest/'manifest.json').read_text())['commit'],manifest['commit'])

    def test_missing_published_dmg_never_creates_a_fake_download(self):
        dest=self.package();manifest=json.loads((dest/'manifest.json').read_text());record=self.published_record(manifest)
        record['assets']=[a for a in record['assets'] if not a['name'].endswith('.dmg')]
        with mock.patch.object(release,'run',side_effect=self.publication_runner(record,manifest['commit'])):
            with self.assertRaisesRegex(ValueError,'missing'):release.finish_publication(self.root,'0.3.1',manifest,self.root/'.release/prepared.json')
        self.assertNotIn('/releases/download/',(self.root/'README.md').read_text())

    def test_different_published_bytes_are_rejected(self):
        dest=self.package();manifest=json.loads((dest/'manifest.json').read_text());record=self.published_record(manifest)
        record['assets'][0]['digest']='sha256:wrong'
        with mock.patch.object(release,'run',side_effect=self.publication_runner(record,manifest['commit'])):
            with self.assertRaisesRegex(ValueError,'checksum differs'):release.finish_publication(self.root,'0.3.1',manifest,self.root/'.release/prepared.json')
        self.assertNotIn('/releases/download/',(self.root/'README.md').read_text())

    def test_failed_documentation_push_can_resume_without_bumping(self):
        dest=self.package();manifest=json.loads((dest/'manifest.json').read_text());record=self.published_record(manifest);pending=self.root/'.release/prepared.json'
        with mock.patch.object(release,'run',side_effect=self.publication_runner(record,manifest['commit'],fail_push=True)):
            with self.assertRaises(subprocess.CalledProcessError):release.finish_publication(self.root,'0.3.1',manifest,pending)
        self.assertTrue(pending.exists());first=self.git('rev-parse','HEAD')
        self.assertEqual(json.loads(pending.read_text())['documentation_commit'],first.strip())
        with mock.patch.object(release,'run',side_effect=self.publication_runner(record,manifest['commit'])):
            release.finish_publication(self.root,'0.3.1',manifest,pending)
        self.assertFalse(pending.exists());self.assertEqual(self.git('rev-parse','HEAD'),first)


if __name__=='__main__':unittest.main()
