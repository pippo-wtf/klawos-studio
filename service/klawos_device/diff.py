"""Three-way persistent-field merge and aggregate-aware device change planning."""
from __future__ import annotations
import copy,uuid
from dataclasses import dataclass
from .model import Snapshot,canonical_revision
from .validation import KNOWN_HARDWARE
from .keycodes import encode_keycode
from .macro_codec import normalize_macro

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
    # Macro grouping changes on readback; merge whole slots using their semantic value.
    if path.startswith('hardware.macro.') and len(path.split('.'))==3: return [path]
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

def _semantic_persistent(snapshot):
    # Vial can return a shortcut as an alias or hex value; compare exact 16-bit codes.
    hardware=copy.deepcopy(snapshot.hardware)
    key=lambda value:encode_keycode(value,snapshot.identity.vial_protocol)
    for layer in hardware.get('layout',[]):
        for row in layer:
            row[:]=[key(value) for value in row]
    for layer in hardware.get('encoder_layout',[]):
        for pair in layer:
            pair[:]=[key(value) for value in pair]
    if 'macro' in hardware:
        hardware['macro']=[normalize_macro(macro,snapshot.identity.vial_protocol) for macro in hardware['macro']]
    for entry in hardware.get('combo',[]):entry[:]=[key(value) for value in entry]
    for entry in hardware.get('tap_dance',[]):entry[:4]=[key(value) for value in entry[:4]]
    for family,fields in [('key_override',('trigger','replacement')),('alt_repeat_key',('keycode','alt_keycode'))]:
        for entry in hardware.get(family,[]):
            for field in fields:entry[field]=key(entry[field])
    return {'hardware':hardware,'lighting':snapshot.lighting}

def merge_snapshot(base:Snapshot,actual:Snapshot,desired:Snapshot)->MergeResult:
    if base.identity!=actual.identity or base.identity!=desired.identity: raise ValueError('Different device definitions')
    previous=_semantic_persistent(base); current=_semantic_persistent(actual); wanted=_semantic_persistent(desired)
    changes=_walk(previous,wanted); conflicts=[];merged=copy.deepcopy(actual)
    target=_persistent(merged)
    for path in changes:
        old=_value(previous,path); now=_value(current,path); new=_value(wanted,path)
        if now!=old and now!=new: conflicts.append(path)
        else: _set(target,path,_value(_persistent(desired),path))
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
    paths=_walk(_semantic_persistent(actual),_semantic_persistent(merged));regions={}
    for path in paths: regions.setdefault(_region(path),[]).append(path)
    operations=[]
    old=_persistent(actual);new=_persistent(merged)
    for region,field_paths in sorted(regions.items()):
        region_path='hardware.macro' if region=='macro' else region
        operations.append(DeviceOperation(str(uuid.uuid4()),field_paths,copy.deepcopy(_value(old,region_path)),
                                          copy.deepcopy(_value(new,region_path)),region))
    return ChangePlan(operations,canonical_revision(actual))
