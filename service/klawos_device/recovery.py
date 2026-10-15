"""Recovery is a previewed draft, never an automatic replay."""
import copy,json,os,uuid
from .diff import plan_changes,_persistent,_set,_value
from .apply import sync_directory,durable_json

def recovery_draft(before,intended,current,choice):
    if before.identity!=intended.identity or before.identity!=current.identity:raise ValueError('Recovery belongs to another keyboard definition')
    if choice not in {'keepCurrent','completeIntended','restoreChangedRegions'}:raise ValueError('Unknown recovery choice')
    result=copy.deepcopy(current)
    if choice=='keepCurrent':return result
    changes=plan_changes(before,intended,before)
    root=_persistent(result)
    for op in changes.operations:
        source=_persistent(intended if choice=='completeIntended' else before)
        paths={'.'.join(path.split('.')[:3]) if path.startswith('hardware.macro.') else path for path in op.field_paths}
        for path in sorted(paths):_set(root,path,_value(source,path))
    return result

def directory_for(store,identifier):
    if str(uuid.UUID(identifier))!=identifier:raise ValueError('Invalid recovery identifier')
    root=(store/'backups').resolve();directory=(root/identifier).resolve()
    if directory.parent!=root:raise ValueError('Invalid recovery path')
    return directory

def _resolved(directory):
    try: return json.loads((directory/'resolution.json').read_bytes())=={'state':'resolved'}
    except (OSError,ValueError): return False

def list_recoveries(store):
    result=[]
    root=store/'backups'
    if not root.exists():return result
    for directory in sorted(root.iterdir()):
        journal=directory/'journal.jsonl'
        if not journal.is_file() or _resolved(directory):continue
        try:
            rows=[json.loads(line) for line in journal.read_bytes().splitlines()]
            if rows and rows[-1]['state'] not in {'complete','resolved'}:
                result.append({'id':directory.name,'state':rows[-1]['state'],'regions':list(dict.fromkeys(r['region'] for r in rows if 'region' in r))})
        except (ValueError,KeyError,TypeError):result.append({'id':directory.name,'state':'journalIncomplete','regions':[]})
    return result

def resolve(store,identifier):
    directory=directory_for(store,identifier)
    if not (directory/'journal.jsonl').is_file(): raise ValueError('Missing recovery journal')
    # Resolution is independent of parseability; retain every byte of original evidence.
    temporary=directory/(str(uuid.uuid4())+'.tmp')
    try:
        durable_json(temporary,{'state':'resolved'})
        os.replace(temporary,directory/'resolution.json')
        sync_directory(directory)
    finally:
        temporary.unlink(missing_ok=True)

def prune_verified(store,keep=20):
    """Only completed app-generated transactions are eligible; unresolved journals are retained."""
    import shutil
    root=store/'backups';groups={}
    if not root.exists():return
    for directory in root.iterdir():
        if directory.is_symlink() or not directory.is_dir():continue
        try:
            if str(uuid.UUID(directory.name))!=directory.name:continue
            evidence=(directory/'journal.jsonl').read_bytes()
            if not evidence.endswith(b'\n'):continue
            rows=[json.loads(line) for line in evidence.splitlines()]
            if not rows or (rows[-1]['state'] not in {'complete','resolved'} and not _resolved(directory)):continue
            before=json.loads((directory/'before.json').read_bytes());uid=before['identity']['uid']
            groups.setdefault(uid,[]).append(directory)
        except (OSError,ValueError,KeyError,TypeError):continue
    for directories in groups.values():
        for directory in sorted(directories,key=lambda p:p.stat().st_mtime,reverse=True)[keep:]:shutil.rmtree(directory)
    sync_directory(root)
