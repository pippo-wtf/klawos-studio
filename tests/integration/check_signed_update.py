"""Opt-in real certificate check; never launches an app or changes permissions."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('app_update',ROOT/'scripts/app_update.py')
updates=importlib.util.module_from_spec(spec);spec.loader.exec_module(updates)

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('app',type=Path)
parser.add_argument('--identity',required=True,help='Fingerprint of the same Apple signing certificate')
args=parser.parse_args()
with tempfile.TemporaryDirectory(prefix='klawos-signing-proof-') as temporary:
    root=Path(temporary);candidate=root/'candidate.app';unsigned=root/'temporary.app'
    target=root/'Applications/KLAWOS Studio.app';data=root/'data';data.mkdir()
    (data/'draft.json').write_text('{"keep":"my settings"}')
    updates.run('/usr/bin/ditto',args.app,candidate)
    marker=candidate/'Contents/Resources/update-identity-check.txt';marker.write_text('different contents, same publisher')
    updates.run('/usr/bin/codesign','--force','--deep','--sign',args.identity,candidate)
    old=updates.inspect(args.app);new=updates.inspect(candidate)
    assert old==new,'The designated requirements must stay the same'
    def code_hash(app):
        output=updates.run('/usr/bin/codesign','-dv','--verbose=4',app)
        return re.search(r'^CDHash=(.+)$',output,re.M)[1]
    assert code_hash(args.app)!=code_hash(candidate),'This check must use genuinely different signed contents'
    updates.install(args.app,target,root/'backups',data,is_running=lambda:False)
    backup=updates.install(candidate,target,root/'backups',data,is_running=lambda:False)
    assert (target/'Contents/Resources/update-identity-check.txt').read_text()==marker.read_text()
    assert (data/'draft.json').read_text()=='{"keep":"my settings"}'
    with zipfile.ZipFile(backup/'previous-app.zip') as archive:assert archive.testzip() is None
    updates.run('/usr/bin/ditto',candidate,unsigned)
    updates.run('/usr/bin/codesign','--force','--deep','--sign','-',unsigned)
    try:updates.verify_update(unsigned,target)
    except updates.UpdateError:pass
    else:raise AssertionError('A temporary signature must never replace the stable app')
    print(json.dumps({'sameRequirements':True,'differentCodeHashes':True,'twoVersionsInstalledAtOnePath':True,
                      'settingsPreserved':True,'rollbackArchiveVerified':True,'temporarySignatureRejected':True,
                      'actualMacOSPermissionRetention':'Requires live GUI acceptance after the one-time migration'}))
