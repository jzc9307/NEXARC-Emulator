import contextlib
import importlib.util
import io
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
import zipfile

SPEC=importlib.util.spec_from_file_location('nexarc_release',Path(__file__).resolve().parents[1]/'scripts/release.py')
release=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
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
        self.assertEqual(history.count('| **Newest** |'),1)
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


if __name__=='__main__':unittest.main()
