"""Bounded, portable project validation before any device operation."""
from __future__ import annotations
import copy,json,re
from dataclasses import dataclass
from .model import load_document,parse_snapshot,Snapshot
from .keycodes import encode_keycode
from .macro_codec import macro_payload
from .vial.settings import QmkSettings

@dataclass
class ValidatedProject:
    document: dict
    snapshot: Snapshot
    read_only_fields: list[str]

KNOWN_HARDWARE = {'version','uid','layout','encoder_layout','layout_options','macro',
                  'vial_protocol','via_protocol','tap_dance','combo','key_override','alt_repeat_key','settings'}
ACTION_KINDS = {'none','shortcut','appShortcut','openURL','openApp','namedShortcut','menuCommand'}
FORBIDDEN_KEYS = {'command','script','shell','appleScript','executable','pathToExecutable'}

def _capacity(caps,camel,snake,default=None):
    value=caps.get(camel,caps.get(snake,default))
    if type(value) is not int or value<0: raise ValueError('Invalid device capability')
    return value

def _validate_action(action):
    kind=action['kind'];p=action.get('parameters')
    if action.get('id') is not None and not isinstance(action['id'],str): raise ValueError('Invalid action identifier')
    if not isinstance(kind,str) or kind not in ACTION_KINDS: raise ValueError('Unsupported action kind')
    if not isinstance(p,dict): raise ValueError('Invalid action parameters')
    valid=False
    if kind=='none': valid=not p
    elif kind=='openApp':
        bundle=p.get('bundleID')
        valid=set(p)=={'bundleID'} and isinstance(bundle,str) and 0<len(bundle)<=255 and re.fullmatch(r'[A-Za-z0-9.-]+',bundle) is not None
    elif kind in {'shortcut','appShortcut'}:
        required={'keyCode','modifiers'} | ({'bundleID'} if kind=='appShortcut' else set())
        mods=p.get('modifiers');key=p.get('keyCode')
        valid=(set(p)==required and type(key) is int and 0<=key<=127 and isinstance(mods,list) and len(mods)<=4
               and all(isinstance(mod,str) and mod in {'command','control','option','shift'} for mod in mods))
        if kind=='appShortcut': valid=valid and p.get('bundleID') in ('com.openai.codex','com.anthropic.claudefordesktop')
    elif kind=='openURL': valid=set(p)=={'url'} and p['url']=='claude://claude.ai/new'
    elif kind=='namedShortcut':
        name=p.get('name')
        valid=set(p)=={'name'} and isinstance(name,str) and 0<len(name)<=256 and '\0' not in name and not name.startswith('-')
    elif kind=='menuCommand':
        bundle=p.get('bundleID');path=p.get('menuPath')
        valid=(set(p)=={'bundleID','menuPath'} and isinstance(bundle,str) and bool(bundle) and isinstance(path,list)
               and 2<=len(path)<=6 and all(isinstance(title,str) and 0<len(title)<200 for title in path))
    if not valid: raise ValueError('Invalid action parameters')

def _action_tree(value):
    if isinstance(value,dict):
        if any(key in FORBIDDEN_KEYS for key in value): raise ValueError('Executable action imports are unavailable')
        if 'kind' in value: _validate_action(value)
        for child in value.values(): _action_tree(child)
    elif isinstance(value,list):
        for child in value: _action_tree(child)

def _macro_bytes(macros,protocol):
    return len(macro_payload(macros,protocol))

def validate_project(document:bytes,capabilities:dict)->ValidatedProject:
    data=load_document(document)
    if data.get('format_version')!=1: raise ValueError('Unsupported project version')
    identity=data.get('identity')
    if not isinstance(identity,dict) or not isinstance(identity.get('uid'),str): raise ValueError('Missing device UID')
    hardware=data.get('hardware')
    if not isinstance(hardware,dict): raise ValueError('Missing Vial hardware document')
    snapshot=parse_snapshot(json.dumps(hardware,allow_nan=False).encode())
    if identity['uid']!=snapshot.identity.uid: raise ValueError('Project belongs to another device')
    if 'uid' in capabilities and str(capabilities['uid'])!=identity['uid']: raise ValueError('Project/device UID mismatch')
    layers=_capacity(capabilities,'layers','layers')
    rows=_capacity(capabilities,'rows','rows',capabilities.get('matrix',{}).get('rows'))
    cols=_capacity(capabilities,'cols','cols',capabilities.get('matrix',{}).get('cols'))
    encoders=_capacity(capabilities,'encoders','encoders')
    if len(hardware['layout'])!=layers: raise ValueError('Layer count differs from device')
    protocol=hardware.get('vial_protocol',-1)
    if protocol not in range(7): raise ValueError('Unsupported Vial protocol')
    for layer in hardware['layout']:
        if len(layer)!=rows or any(len(row)!=cols for row in layer): raise ValueError('Matrix differs from device')
        for row in layer:
            for code in row: encode_keycode(code,protocol)
    encoder_layout=hardware.get('encoder_layout')
    if not isinstance(encoder_layout,list) or len(encoder_layout)!=layers: raise ValueError('Encoder layers differ')
    for layer in encoder_layout:
        if len(layer)!=encoders or any(not isinstance(pair,list) or len(pair)!=2 for pair in layer):
            raise ValueError('Encoder count differs')
        for pair in layer:
            for code in pair: encode_keycode(code,protocol)
    counts={'macro':('macroSlots','macro_slots'),'tap_dance':('tapDanceSlots','tap_dance_slots'),
            'combo':('comboSlots','combo_slots'),'key_override':('keyOverrideSlots','key_override_slots'),
            'alt_repeat_key':('altRepeatSlots','alt_repeat_slots')}
    for field,(camel,snake) in counts.items():
        expected=_capacity(capabilities,camel,snake)
        if not isinstance(hardware.get(field),list) or len(hardware[field])!=expected:
            raise ValueError(f'{field} capacity differs from device')
    for entry in hardware['tap_dance']:
        if not isinstance(entry,list) or len(entry)!=5: raise ValueError('Invalid tap dance')
        for code in entry[:4]: encode_keycode(code,protocol)
        if type(entry[4]) is not int or not 0<=entry[4]<=65535: raise ValueError('Invalid tap dance interval')
    for entry in hardware['combo']:
        if not isinstance(entry,list) or len(entry)!=5: raise ValueError('Invalid combo')
        for code in entry: encode_keycode(code,protocol)
    for entry in hardware['key_override']:
        if not isinstance(entry,dict) or set(entry)!={'trigger','replacement','layers','trigger_mods','negative_mod_mask','suppressed_mods','options'}:
            raise ValueError('Invalid key override')
        for key in ('trigger','replacement'): encode_keycode(entry[key],protocol)
        for key in ('layers','trigger_mods','negative_mod_mask','suppressed_mods','options'):
            maximum=65535 if key=='layers' else 255
            if type(entry[key]) is not int or not 0<=entry[key]<=maximum: raise ValueError('Invalid key override mask')
    for entry in hardware['alt_repeat_key']:
        if not isinstance(entry,dict) or set(entry)!={'keycode','alt_keycode','allowed_mods','options'}:
            raise ValueError('Invalid alt repeat')
        for key in ('keycode','alt_keycode'): encode_keycode(entry[key],protocol)
        for key in ('allowed_mods','options'):
            if type(entry[key]) is not int or not 0<=entry[key]<=255: raise ValueError('Invalid alt repeat mask')
    byte_limit=_capacity(capabilities,'macroBytes','macro_bytes')
    if _macro_bytes(hardware['macro'],protocol)>byte_limit: raise ValueError('Macro buffer exceeds device')
    settings=hardware.get('settings',{})
    if not isinstance(settings,dict): raise ValueError('Invalid QMK settings')
    supported={str(x) for x in capabilities.get('settings',range(1,22))}
    for key,value in settings.items():
        if key not in supported or type(value) is not int or value<0: raise ValueError('Unsupported QMK setting')
        if QmkSettings.is_qsid_supported(int(key)):
            for field in QmkSettings.qsid_fields[int(key)]:
                if field['type']=='integer' and not field.get('min',0)<=value<=field.get('max',(1<<(8*field.get('width',1)))-1):
                    raise ValueError('QMK setting exceeds its documented range')
            try: QmkSettings.qsid_serialize(int(key),value)
            except OverflowError as error: raise ValueError('QMK setting exceeds firmware width') from error
    metadata=data.get('metadata',{})
    if not isinstance(metadata,dict) or any(key.lower() in {'password','token','secret','credential','permissions','localpath','absolutepath'} for key in metadata):
        raise ValueError('Local secrets and permissions cannot be imported')
    profiles=data.get('profiles',{})
    if not isinstance(profiles,dict): raise ValueError('Invalid action profiles')
    _action_tree(profiles)
    lighting=data.get('lighting',{})
    if not isinstance(lighting,dict): raise ValueError('Invalid lighting')
    snapshot.lighting=copy.deepcopy(lighting)
    read_only=[f'hardware.{key}' for key in hardware if key not in KNOWN_HARDWARE]
    return ValidatedProject(copy.deepcopy(data),snapshot,read_only)
