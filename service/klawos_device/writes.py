"""Bounded persistent-setting packets, adapted from the pinned Vial serializer.

No bootloader, EEPROM reset, implicit unlock, or runtime layer selection.
"""
import struct
from .keycodes import encode_keycode
from .macro_codec import macro_payload
from .vial.settings import QmkSettings

def validate_lighting(old,new):
    if set(old)!=set(new):raise ValueError('Lighting capability cannot change')
    for family,before in old.items():
        after=new[family]
        if before==after:continue
        if family!='vialrgb':raise ValueError('This lighting family is not writable yet')
        editable={'mode','speed','hsv'}
        if {k:v for k,v in before.items() if k not in editable}!={k:v for k,v in after.items() if k not in editable}:
            raise ValueError('Lighting capability cannot change')
        if type(after.get('mode')) is not int or after['mode'] not in before.get('effects',[]):raise ValueError('Unsupported lighting effect')
        if type(after.get('speed')) is not int or not 0<=after['speed']<=255:raise ValueError('Invalid lighting speed')
        hsv=after.get('hsv')
        if not isinstance(hsv,list) or len(hsv)!=3 or any(type(v) is not int or not 0<=v<=255 for v in hsv):raise ValueError('Invalid lighting color')
        if hsv[2]>before.get('maximumBrightness',255):raise ValueError('Brightness exceeds device limit')

def packets_for(operation,protocol):
    parts=operation.region_id.split('.');v=operation.desired_new
    key=lambda code:encode_keycode(code,protocol)
    if parts[:2]==['hardware','layout'] and len(parts)==5:
        return [struct.pack('>BBBBH',5,*map(int,parts[2:]),key(v))]
    if parts[:2]==['hardware','encoder_layout'] and len(parts)==5:
        return [struct.pack('>BBBBBH',0xfe,4,*map(int,parts[2:]),key(v))]
    if operation.region_id=='macro':
        data=macro_payload(v,protocol)
        return [struct.pack('>BHB',15,i,len(data[i:i+28]))+data[i:i+28] for i in range(0,len(data),28)]
    if len(parts)==3 and parts[0]=='hardware':
        family=parts[1];index=int(parts[2])
        if family=='tap_dance':return [bytes([254,13,2,index])+struct.pack('<HHHHH',*[key(x) for x in v[:4]],v[4])]
        if family=='combo':return [bytes([254,13,4,index])+struct.pack('<HHHHH',*[key(x) for x in v])]
        if family=='key_override':
            return [bytes([254,13,6,index])+struct.pack('<HHHBBBB',key(v['trigger']),key(v['replacement']),v['layers'],v['trigger_mods'],v['negative_mod_mask'],v['suppressed_mods'],v['options'])]
        if family=='alt_repeat_key':
            return [bytes([254,13,8,index])+struct.pack('<HHBB',key(v['keycode']),key(v['alt_keycode']),v['allowed_mods'],v['options'])]
        if family=='settings':
            if not QmkSettings.is_qsid_supported(index):raise ValueError('Unknown setting is read-only')
            return [struct.pack('<BBH',254,11,index)+QmkSettings.qsid_serialize(index,v)]
    if operation.region_id=='hardware.layout_options':
        if type(v) is not int or not 0<=v<=0xffffffff:raise ValueError('Invalid layout option')
        return [struct.pack('>BBI',3,2,v)]
    if operation.region_id=='lighting.vialrgb':
        return [struct.pack('<BBHBBBB',7,65,v['mode'],v['speed'],*v['hsv']),b'\x09']
    raise ValueError('Unsupported write region')
