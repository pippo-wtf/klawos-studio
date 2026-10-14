"""Read-only pinned Vial adapter. The exchange boundary independently rejects all writes."""
import hashlib,json,lzma,datetime
from .model import parse_snapshot,DeviceIdentity
from .vial.protocol.keyboard_comm import Keyboard

def select_descriptor(devices,path=None):
    matches=[d for d in devices if path is None or d['pathToken']==path]
    if len(matches)!=1: raise ValueError('Select one connected physical KLAWOS')
    return matches[0]

class ReadOnlyExchange:
    def __init__(self, exchange): self.exchange=exchange; self.count=0; self.last_query={}
    def __call__(self, report):
        if not report or len(report)>32: raise ValueError('Invalid report length')
        cmd=report[0]; sub=report[1] if len(report)>1 else -1
        allowed=cmd in {1,0x0c,0x0d,0x0e,0x11,0x12}
        allowed|=cmd==2 and sub==2
        allowed|=cmd==8 and sub in {9,10,0x80,0x81,0x82,0x83,0x40,0x41,0x42}
        allowed|=cmd==0xfe and sub in {0,1,2,3,5,9,10}
        allowed|=cmd==0xfe and sub==13 and len(report)>2 and report[2] in {0,1,3,5,7}
        if not allowed: raise ValueError('Read-only mode refuses this packet')
        self.count+=1
        if self.count>16384: raise ValueError('Readback packet budget exceeded')
        if (cmd,sub) in {(0xfe,9),(8,0x42)}:
            if self.last_query.get((cmd,sub))==report: raise ValueError('Non-progressing capability query')
            self.last_query[(cmd,sub)]=report
        packet=report.ljust(32,b'\0'); reply=self.exchange(packet)
        if not isinstance(reply,bytes) or len(reply)!=32: raise ValueError('Expected exactly 32 response bytes')
        echo=4 if cmd in {0x0e,0x12} else 2 if cmd in {2,8} else 1 if cmd in {1,0x0c,0x0d,0x11} else 0
        if reply[:echo]!=packet[:echo]: raise ValueError('Unexpected response command; readback aborted')
        return reply

def decompress_definition(data):
    decoder=lzma.LZMADecompressor(memlimit=64*1024*1024)
    result=decoder.decompress(data,max_length=4*1024*1024+1)
    if len(result)>4*1024*1024 or not decoder.eof: raise ValueError('Oversized or truncated definition')
    return result

def read_snapshot(exchange,descriptor):
    if not descriptor.get('pathToken') or not descriptor.get('generation'): raise ValueError('Missing physical device generation')
    guard=ReadOnlyExchange(exchange)
    settings_raw={}
    def usb_send(dev,packet,**kwargs):
        # Upstream retries are deliberately disabled: a lost/mis-correlated exchange terminates this read.
        reply=guard(packet)
        if packet[:2]==bytes([0xfe,10]): settings_raw[str(int.from_bytes(packet[2:4],'little'))]=reply.hex()
        return reply
    keyboard=Keyboard(None,usb_send=usb_send); keyboard.reload()
    snapshot=parse_snapshot(keyboard.save_layout())
    definition_raw=json.dumps(keyboard.definition,sort_keys=True,separators=(',',':')).encode()
    snapshot.identity=DeviceIdentity(str(keyboard.keyboard_id),keyboard.via_protocol,keyboard.vial_protocol,hashlib.sha256(definition_raw).hexdigest())
    snapshot.capabilities={'rows':keyboard.rows,'cols':keyboard.cols,'layers':keyboard.layers,'encoders':keyboard.encoder_count,
        'macroSlots':keyboard.macro_count,'macroBytes':keyboard.macro_memory,'tapDanceSlots':keyboard.tap_dance_count,
        'comboSlots':keyboard.combo_count,'keyOverrideSlots':keyboard.key_override_count,'altRepeatSlots':keyboard.alt_repeat_key_count,
        'settings':sorted(keyboard.supported_settings),'features':sorted(keyboard.supported_features),
        'lighting':keyboard.definition.get('lighting'),'definition':keyboard.definition}
    snapshot.lighting={}
    if keyboard.lighting_vialrgb:
        snapshot.lighting['vialrgb']={'version':keyboard.rgb_version,'maximumBrightness':keyboard.rgb_maximum_brightness,
            'mode':keyboard.rgb_mode,'speed':keyboard.rgb_speed,'hsv':list(keyboard.rgb_hsv),'effects':sorted(keyboard.rgb_supported_effects)}
    if keyboard.lighting_qmk_rgblight:
        snapshot.lighting['rgblight']={'brightness':keyboard.underglow_brightness,'effect':keyboard.underglow_effect,
            'speed':keyboard.underglow_effect_speed,'color':list(keyboard.underglow_color)}
    if keyboard.lighting_qmk_backlight: snapshot.lighting['backlight']={'brightness':keyboard.backlight_brightness,'effect':keyboard.backlight_effect}
    snapshot.metadata={'descriptor':descriptor,'readPackets':guard.count,'rawSettings':settings_raw}
    snapshot.unreadable_fields=[f'settings.{qsid}' for qsid in sorted(keyboard.supported_settings) if qsid not in keyboard.settings]
    snapshot.captured_at=datetime.datetime.now(datetime.timezone.utc).isoformat()
    return snapshot
