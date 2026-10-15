"""Install one signed KLAWOS app without changing its permission identity."""
import argparse
import fcntl
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone

STUDIO_ID='com.pippo.klawos.studio'
HELPER_ID='com.pippo.klawos.helper'
HELPER=Path('Contents/Library/LoginItems/KLAWOS Helper.app')

class UpdateError(Exception):
    pass

def run(*args):
    try:
        result=subprocess.run([str(arg) for arg in args],check=True,capture_output=True,text=True,timeout=150)
        return result.stdout+result.stderr
    except (subprocess.CalledProcessError,subprocess.TimeoutExpired) as error:
        raise UpdateError('Could not finish: '+str(args[0])+'\n'+str(getattr(error,'stderr','') or error)) from error

def signer(output):
    fields=dict(re.findall(r'^(Identifier|TeamIdentifier|Signature)=(.+)$',output,re.M))
    team=fields.get('TeamIdentifier','')
    if fields.get('Signature')=='adhoc' or not re.fullmatch(r'[A-Z0-9]{10}',team):
        raise UpdateError('A stable Apple signing certificate is required. Temporary development signatures cannot preserve permissions.')
    return {'identifier':fields.get('Identifier'),'team':team}

def inspect(app,command=run):
    command('/usr/bin/codesign','--verify','--deep','--strict',app)
    result={}
    for relative,identifier in [(Path('.'),STUDIO_ID),(HELPER,HELPER_ID)]:
        bundle=app/relative
        with (bundle/'Contents/Info.plist').open('rb') as file:
            if plistlib.load(file).get('CFBundleIdentifier')!=identifier:
                raise UpdateError('The update has an unexpected app identity.')
        info=signer(command('/usr/bin/codesign','-dv','--verbose=2',bundle))
        if info['identifier']!=identifier:
            raise UpdateError('The signed app identity does not match its package.')
        command('/usr/bin/codesign','--verify','--strict','-R','=anchor apple generic',bundle)
        requirement=command('/usr/bin/codesign','-d','-r-',bundle)
        match=re.search(r'^(?:# )?designated => (.+)$',requirement,re.M)
        if not match or 'cdhash' in match[1]:
            raise UpdateError('This build has no stable signing requirement.')
        result[relative]={'team':info['team'],'requirement':match[1]}
    if len({item['team'] for item in result.values()})!=1:
        raise UpdateError('Studio and its helper must use the same signing team.')
    return result

def verify_update(candidate,current=None,command=run):
    new=inspect(candidate,command)
    if current is None:return
    old=inspect(current,command)
    for relative in new:
        if new[relative]['team']!=old[relative]['team']:
            raise UpdateError('The update changes the signing team. The installed app was not replaced.')
        # Both directions prevent a wider replacement requirement from being accepted.
        command('/usr/bin/codesign','--verify','--strict','-R','='+old[relative]['requirement'],candidate/relative)
        command('/usr/bin/codesign','--verify','--strict','-R','='+new[relative]['requirement'],current/relative)

def running():
    output=run('/bin/ps','-axo','comm=')
    return any(Path(line.strip()).name in {'KlawosStudio','KlawosAgent'} for line in output.splitlines())

def install(candidate,destination,backups,data,verify=verify_update,is_running=running):
    candidate=Path(candidate).resolve();destination=Path(destination)
    if destination.is_symlink() or candidate==destination.resolve() or destination.resolve() in candidate.parents:
        raise UpdateError('Build the update separately from the installed app.')
    current=destination if destination.exists() else None
    verify(candidate,current)
    if is_running():raise UpdateError('Quit KLAWOS Studio and KLAWOS Helper, then run the update again.')
    destination.parent.mkdir(parents=True,exist_ok=True)
    lock=destination.parent/'.klawos-update.lock'
    with lock.open('a') as handle:
        try:fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError as error:raise UpdateError('Another KLAWOS update is already running.') from error
        # Repeat after the lock: another updater may have finished since preflight.
        current=destination if destination.exists() else None
        verify(candidate,current)
        stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        backup=Path(backups)/stamp;backup.mkdir(parents=True,mode=0o700)
        if Path(data).exists():shutil.copytree(data,backup/'app-data',symlinks=True)
        if current:
            run('/usr/bin/ditto','-c','-k','--sequesterRsrc','--keepParent',current,backup/'previous-app.zip')
        with tempfile.TemporaryDirectory(prefix='.klawos-update-',dir=destination.parent) as temporary:
            folder=Path(temporary);staged=folder/'KLAWOS Studio.app';previous=folder/'previous.app'
            run('/usr/bin/ditto',candidate,staged)
            verify(staged,current)
            if is_running():raise UpdateError('KLAWOS started during preparation. Quit it and run the update again.')
            moved=False;installed=False
            try:
                if current:destination.rename(previous);moved=True
                staged.rename(destination);installed=True
                verify(destination,previous if moved else None)
            except BaseException:
                if installed:shutil.rmtree(destination)
                if moved:previous.rename(destination)
                raise
        return backup

def refresh_helper(target,command=run):
    for attempt in range(2):
        try:
            command('/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister','-f',target)
            return command(target/'Contents/MacOS/KlawosStudio','--refresh-helper-registration')
        except UpdateError:
            if attempt==1:raise

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate',type=Path)
    parser.add_argument('--check',action='store_true',help='Check signing without installing')
    args=parser.parse_args()
    if args.check:
        inspect(args.candidate);print('Stable app and helper signing verified.');return
    target=Path.home()/'Applications/KLAWOS Studio.app'
    data=Path.home()/'Library/Application Support/KLAWOS Studio'
    backup=install(args.candidate,target,Path(__file__).resolve().parents[1]/'configs/app-updates',data)
    print('Updated '+str(target)+'\nBackup: '+str(backup))
    # Run only from the final location so service registration cannot refer to a build folder.
    try:
        print(refresh_helper(target))
    except UpdateError as error:
        raise UpdateError('The app is installed, but its helper could not restart. Reopen Studio and use Restart helper.\n'+str(error)) from error

if __name__=='__main__':
    try:main()
    except (UpdateError,OSError,ValueError) as error:
        print(str(error),file=__import__('sys').stderr);raise SystemExit(1)
