"""Safe Vial macro compilation and grouping-independent comparison."""
from .keycodes import encode_keycode
from .vial.macro.tags import tag_to_action
from .vial.protocol.macro import macro_deserialize_v1,macro_deserialize_v2


def normalize_macro(macro,protocol):
    if not isinstance(macro,list): raise ValueError('Invalid macro')
    result=[]
    for item in macro:
        if not isinstance(item,list) or not item or not isinstance(item[0],str) or item[0] not in tag_to_action:
            raise ValueError('Invalid macro action')
        tag=item[0]
        if tag=='text':
            if len(item)!=2 or not isinstance(item[1],str): raise ValueError('Invalid macro text')
            value=item[1]
            if not value: continue
            if result and result[-1][0]==tag: result[-1][1]+=value
            else: result.append([tag,value])
        elif tag in {'tap','down','up'}:
            keys=[encode_keycode(value,protocol) for value in item[1:]]
            if not keys: continue
            if result and result[-1][0]==tag: result[-1].extend(keys)
            else: result.append([tag,*keys])
        else:
            if len(item)!=2 or type(item[1]) is not int or not 0<=item[1]<=65024:
                raise ValueError('Invalid macro delay')
            result.append([tag,item[1]])
    return result


def macro_payload(macros,protocol):
    if not isinstance(macros,list): raise ValueError('Invalid macros')
    slots=[];normalized=[]
    for macro in macros:
        canonical=normalize_macro(macro,protocol);normalized.append(canonical);parts=[]
        for item in canonical:
            tag=item[0]
            if tag=='text':
                # Firmware sends bytes; Unicode typing has not been established.
                if any(not 32<=ord(ch)<=126 for ch in item[1]):
                    raise ValueError('Macro text supports printable ASCII only. Use key steps for Tab, Enter, or shortcuts.')
            elif tag in {'tap','down','up'}:
                # Zero separates slots; FF01..FFFF are reserved extended-key escapes.
                if any(key==0 or key>0xFF00 or (protocol<2 and key>255) for key in item[1:]):
                    raise ValueError('This key cannot be stored in a macro. Choose another key step.')
                item=[tag,*(f'0x{key:04X}' for key in item[1:])]
            elif protocol<2:
                raise ValueError('Invalid macro delay: this keyboard protocol cannot store wait steps')
            action=tag_to_action[tag]();action.restore(item);parts.append(action.serialize(protocol))
        slots.append(b''.join(parts))
    payload=b'\0'.join(slots)+b'\0'
    decode=macro_deserialize_v2 if protocol>=2 else macro_deserialize_v1
    # Check the entire buffer, including slot boundaries, before producing any packet.
    if payload.count(b'\0')!=len(macros) or [normalize_macro([a.save() for a in decode(slot)],protocol) for slot in payload.split(b'\0')[:-1]]!=normalized:
        raise ValueError('This macro cannot be stored without changing its steps. Choose another key step.')
    return payload
