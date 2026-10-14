"""Pinned protocol-specific Vial tables with lossless unknown values."""
from types import SimpleNamespace
from .vial.keycodes.keycodes import Keycode,recreate_keyboard_keycodes
from .vial.any_keycode import AnyKeycode
_current_protocol=None
def _select(protocol):
    global _current_protocol
    if protocol not in range(7): raise ValueError('Unsupported Vial keycode protocol')
    if _current_protocol!=protocol or Keycode.protocol!=protocol:
        recreate_keyboard_keycodes(SimpleNamespace(vial_protocol=protocol,layers=32,macro_count=256,
            tap_dance_count=256,custom_keycodes=None,midi='advanced',supported_features=set()))
        _current_protocol=protocol

def decode_keycode(value,protocol):
    if type(value) is not int or not 0<=value<=65535: raise ValueError('Keycode out of range')
    _select(protocol)
    result=Keycode.serialize(value)
    return value if result.startswith('0x') else result

def encode_keycode(value,protocol):
    _select(protocol)
    try:
        if type(value) is int: result=value
        elif isinstance(value,str): result=Keycode.deserialize(value,reraise=True)
        else: raise ValueError('Invalid keycode')
        if type(result) is not int or not 0<=result<=65535: raise ValueError('Keycode out of range')
        return result
    except Exception as e: raise ValueError('Unsupported keycode expression') from e
