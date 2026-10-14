"""Three-way persistent-field merge and aggregate-aware device change planning."""
from __future__ import annotations
import copy,uuid
from dataclasses import dataclass
from .model import Snapshot,canonical_revision
from .validation import KNOWN_HARDWARE

MISSING=object()
@dataclass
class MergeResult:
    snapshot:Snapshot
    conflicts:list[str]
@dataclass
class DeviceOperation:
    operation_id:str
    field_paths:list[str]
    expected_old:object
    desired_new:object
    region_id:str
@dataclass
class ChangePlan:
    operations:list[DeviceOperation]
    source_revision:str

def _walk(before,after,path=''):
    if before==after: return []
    if isinstance(before,dict) and isinstance(after,dict):
        return [p for key in sorted(before.keys()|after.keys())
                for p in _walk(before.get(key,MISSING),after.get(key,MISSING),f'{path}.{key}' if path else str(key))]
    if isinstance(before,list) and isinstance(after,list) and len(before)==len(after):
        return [p for index,(a,b) in enumerate(zip(before,after))
                for p in _walk(a,b,f'{path}.{index}' if path else str(index))]
    return [path]

def _value(root,path):
    current=root
    for part in path.split('.'):
        try: current=current[int(part)] if isinstance(current,list) else current.get(part,MISSING)
        except (IndexError,ValueError,TypeError): return MISSING
        if current is MISSING: return MISSING
    return current

def _set(root,path,value):
    parts=path.split('.');current=root
    for part in parts[:-1]: current=current[int(part)] if isinstance(current,list) else current[part]
    last=parts[-1]
    if isinstance(current,list): current[int(last)]=copy.deepcopy(value)
    elif value is MISSING: current.pop(last,None)
    else: current[last]=copy.deepcopy(value)

def _persistent(snapshot): return {'hardware':snapshot.hardware,'lighting':snapshot.lighting}

def merge_snapshot(base:Snapshot,actual:Snapshot,desired:Snapshot)->MergeResult:
    if base.identity!=actual.identity or base.identity!=desired.identity: raise ValueError('Different device definitions')
    previous=_persistent(base); current=_persistent(actual); wanted=_persistent(desired)
    changes=_walk(previous,wanted); conflicts=[];merged=copy.deepcopy(actual)
    target=_persistent(merged)
    for path in changes:
        old=_value(previous,path); now=_value(current,path); new=_value(wanted,path)
        if now!=old and now!=new: conflicts.append(path)
        else: _set(target,path,new)
    merged.hardware=target['hardware']; merged.lighting=target['lighting']
    return MergeResult(merged,sorted(conflicts))

def _region(path):
    parts=path.split('.')
    if parts[:2]==['hardware','macro']: return 'macro'
    if parts[:2]==['hardware','layout'] and len(parts)>=5: return '.'.join(parts[:5])
    if parts[:2]==['hardware','encoder_layout'] and len(parts)>=5: return '.'.join(parts[:5])
    if parts[1] in {'tap_dance','combo','key_override','alt_repeat_key'} and len(parts)>=3: return '.'.join(parts[:3])
    if parts[:2]==['hardware','settings'] and len(parts)>=3: return '.'.join(parts[:3])
    return '.'.join(parts[:2]) if len(parts)>1 else path

def plan_changes(actual:Snapshot,desired:Snapshot,base:Snapshot)->ChangePlan:
    merge=merge_snapshot(base,actual,desired)
    if merge.conflicts: raise ValueError('Conflicting device edits: '+','.join(merge.conflicts))
    merged=merge.snapshot
    for key in set(actual.hardware)|set(merged.hardware):
        if key not in KNOWN_HARDWARE and actual.hardware.get(key)!=merged.hardware.get(key):
            raise ValueError('Unknown hardware field cannot be written')
    paths=_walk(_persistent(actual),_persistent(merged));regions={}
    for path in paths: regions.setdefault(_region(path),[]).append(path)
    operations=[]
    old=_persistent(actual);new=_persistent(merged)
    for region,field_paths in sorted(regions.items()):
        region_path='hardware.macro' if region=='macro' else region
        operations.append(DeviceOperation(str(uuid.uuid4()),field_paths,copy.deepcopy(_value(old,region_path)),
                                          copy.deepcopy(_value(new,region_path)),region))
    return ChangePlan(operations,canonical_revision(actual))
