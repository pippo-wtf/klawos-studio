"""Small, verified lighting-only updates; EEPROM is saved only on settle."""
import struct
from .writes import validate_lighting

def update_lighting(base, desired, expected, persist, exchange):
    validate_lighting(base.lighting,desired)
    validate_lighting(base.lighting,expected)
    if type(persist) is not bool or set(desired)!={'vialrgb'}:raise ValueError('Invalid lighting request')
    protocol,uid=struct.unpack('<IQ',exchange(b'\xfe\x00')[:12])
    if str(uid)!=base.identity.uid or protocol!=base.identity.vial_protocol:raise ValueError('Different keyboard definition')
    def values(rgb):return (rgb['mode'],rgb['speed'],*rgb['hsv'])
    def read():
        reply=exchange(b'\x08\x41')
        if reply[:2]!=b'\x08\x41':raise ValueError('Invalid lighting response')
        return struct.unpack('<HBBBB',reply[2:8])
    if read()!=values(expected['vialrgb']):raise ValueError('Lighting changed outside the app. Refresh before trying again.')
    target=values(desired['vialrgb'])
    exchange(b'\x07\x41'+struct.pack('<HBBBB',*target))
    if read()!=target:raise ValueError('Lighting readback failed')
    if persist:exchange(b'\x09')
