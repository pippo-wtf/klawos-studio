import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]

class BuildSigningTests(unittest.TestCase):
    def test_default_build_without_certificate_stops_before_compiling_or_replacing_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'scripts').mkdir();(root/'bin').mkdir()
            shutil.copy2(ROOT/'scripts/build-app.sh',root/'scripts/build-app.sh')
            marker=root/'compiled'
            (root/'bin/swift').write_text('#!/bin/sh\ntouch "'+str(marker)+'"\nexit 42\n')
            (root/'bin/security').write_text('#!/bin/sh\necho "0 valid identities found"\n')
            for file in (root/'bin').iterdir():file.chmod(0o755)
            env={**os.environ,'PATH':str(root/'bin')+':/usr/bin:/bin'}
            env.pop('KLAWOS_SIGNING_IDENTITY',None)
            result=subprocess.run(['bash',str(root/'scripts/build-app.sh')],env=env,text=True,capture_output=True)
            self.assertNotEqual(result.returncode,0)
            self.assertFalse(marker.exists(),'A normal update must refuse an unstable identity before starting a build')
            self.assertIn('signing',result.stderr.lower())


spec=importlib.util.spec_from_file_location('app_update',ROOT/'scripts/app_update.py')
updater=importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.new=self.root/'build/Studio.app';self.current=self.root/'Applications/KLAWOS Studio.app'
        self.backups=self.root/'backups';self.data=self.root/'data';self.data.mkdir();(self.data/'draft.json').write_text('keep my edits')
        for app,value in [(self.new,'new'),(self.current,'old')]:
            (app/'Contents').mkdir(parents=True);(app/'Contents/version').write_text(value)
    def install(self,**options):
        return updater.install(self.new,self.current,self.backups,self.data,
            verify=options.get('verify',lambda new,old:None),is_running=options.get('is_running',lambda:False))
    def test_update_uses_same_path_keeps_settings_and_archives_previous_app(self):
        backup=self.install()
        self.assertEqual((self.current/'Contents/version').read_text(),'new')
        self.assertEqual((self.data/'draft.json').read_text(),'keep my edits')
        self.assertEqual((backup/'app-data/draft.json').read_text(),'keep my edits')
        self.assertTrue((backup/'previous-app.zip').is_file())
        self.assertEqual(list(self.current.parent.glob('*.app')),[self.current])
    def test_identity_failure_leaves_current_app_and_settings_untouched(self):
        def reject(new,old):raise updater.UpdateError('Different signing identity')
        with self.assertRaises(updater.UpdateError):self.install(verify=reject)
        self.assertEqual((self.current/'Contents/version').read_text(),'old')
        self.assertFalse(self.backups.exists())
    def test_failed_final_verification_restores_previous_app(self):
        def reject_final(new,old):
            if new==self.current:raise updater.UpdateError('Signature changed during installation')
        with self.assertRaises(updater.UpdateError):self.install(verify=reject_final)
        self.assertEqual((self.current/'Contents/version').read_text(),'old')
        self.assertEqual((self.data/'draft.json').read_text(),'keep my edits')
    def test_running_app_prevents_replacement(self):
        with self.assertRaises(updater.UpdateError):self.install(is_running=lambda:True)
        self.assertEqual((self.current/'Contents/version').read_text(),'old')
    def test_launch_during_preparation_prevents_replacement(self):
        checks=iter([False,True])
        with self.assertRaises(updater.UpdateError):self.install(is_running=lambda:next(checks))
        self.assertEqual((self.current/'Contents/version').read_text(),'old')

class SigningPolicyTests(unittest.TestCase):
    def test_ad_hoc_identity_is_rejected(self):
        with self.assertRaises(updater.UpdateError):updater.signer('Identifier=com.pippo.klawos.studio\nSignature=adhoc\nTeamIdentifier=not set')
    def test_missing_or_non_apple_team_is_rejected(self):
        with self.assertRaises(updater.UpdateError):updater.signer('Identifier=com.pippo.klawos.studio\nAuthority=Local cert')
    def test_certificate_identity_is_retained_in_parsed_metadata(self):
        self.assertEqual(updater.signer('Identifier=com.pippo.klawos.studio\nAuthority=Developer ID Application: Pippo\nTeamIdentifier=ABCDEFGHIJ'),{'identifier':'com.pippo.klawos.studio','team':'ABCDEFGHIJ'})

class IdentityContinuityTests(unittest.TestCase):
    def setUp(self):
        import plistlib
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.new=self.root/'new.app';self.old=self.root/'old.app'
        self.calls=[];self.wrong_team=None;self.reject_requirement=None
        for app in [self.new,self.old]:
            for relative,identifier in [(Path('.'),updater.STUDIO_ID),(updater.HELPER,updater.HELPER_ID)]:
                folder=app/relative/'Contents';folder.mkdir(parents=True)
                (folder/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':identifier}))
    def system(self,*args):
        self.calls.append(args);path=Path(args[-1])
        helper=path.name=='KLAWOS Helper.app';identifier=updater.HELPER_ID if helper else updater.STUDIO_ID
        if '-dv' in args:
            team='ZZZZZZZZZZ' if path==self.wrong_team else 'ABCDEFGHIJ'
            return f'Identifier={identifier}\nAuthority=Developer ID Application: Pippo\nTeamIdentifier={team}'
        if '-r-' in args:return f'designated => identifier "{identifier}" and anchor apple generic and certificate leaf[subject.OU] = "ABCDEFGHIJ"'
        if '-R' in args and args[args.index('-R')+1]!='=anchor apple generic' and path==self.reject_requirement:
            raise updater.UpdateError('Does not satisfy prior identity')
        return ''
    def test_changed_helper_signer_is_rejected(self):
        self.wrong_team=self.new/updater.HELPER
        with self.assertRaises(updater.UpdateError):updater.verify_update(self.new,self.old,self.system)
    def test_wider_new_requirement_cannot_replace_old_identity(self):
        self.reject_requirement=self.old
        with self.assertRaises(updater.UpdateError):updater.verify_update(self.new,self.old,self.system)
    def test_same_identity_checks_both_bundles_in_both_directions(self):
        updater.verify_update(self.new,self.old,self.system)
        checks=[args for args in self.calls if '-R' in args and args[args.index('-R')+1]!='=anchor apple generic']
        self.assertEqual({Path(args[-1]) for args in checks},{self.new,self.old,self.new/updater.HELPER,self.old/updater.HELPER})
    def test_bundle_id_change_is_rejected(self):
        import plistlib
        (self.new/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'some.other.app'}))
        with self.assertRaises(updater.UpdateError):updater.verify_update(self.new,self.old,self.system)

class HelperRefreshTests(unittest.TestCase):
    def test_first_registration_failure_retries_from_same_installed_location(self):
        calls=[]
        def command(*args):
            calls.append(args)
            if '--refresh-helper-registration' in args and sum('--refresh-helper-registration' in call for call in calls)==1:
                raise updater.UpdateError('Could not communicate with helper')
            return 'helper ready'
        target=Path('/Applications/KLAWOS Studio.app')
        self.assertEqual(updater.refresh_helper(target,command),'helper ready')
        self.assertEqual([args[-1] for args in calls if '-f' in args],[target,target])
        self.assertEqual(sum('--refresh-helper-registration' in args for args in calls),2)
    def test_persistent_failure_is_reported_after_two_attempts(self):
        calls=[]
        def command(*args):
            calls.append(args)
            if '--refresh-helper-registration' in args:raise updater.UpdateError('Helper unavailable')
            return ''
        with self.assertRaises(updater.UpdateError):updater.refresh_helper(Path('/Applications/KLAWOS Studio.app'),command)
        self.assertEqual(sum('--refresh-helper-registration' in args for args in calls),2)

if __name__=='__main__':unittest.main()

