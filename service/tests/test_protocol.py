import json, lzma, struct, unittest
from klawos_device.features import read_snapshot, select_descriptor, ReadOnlyExchange

UID = 6994672159869375106
class Transcript:
    def __init__(self):
        definition={'name':'Synthetic transcript pad','matrix':{'rows':4,'cols':4}, 'lighting':'vialrgb', 'layouts':{'keymap':[[f'{r},{c}' for c in range(4)] for r in range(4)]+[['0,0'+chr(10)*9+'e','0,1'+chr(10)*9+'e']]}}
        self.definition=lzma.compress(json.dumps(definition).encode())
        self.keymap=b''.join(struct.pack('>H', 0x5011 if i==3 else 4 if i==0 else 0) for i in range(96))
        self.calls=[]
    def __call__(self, report):
        assert len(report)==32
        self.calls.append(report)
        cmd=report[0]; sub=report[1]
        data=None
        if cmd==1: data=b'\x01\x00\x09'
        elif cmd==0x11: data=b'\x11\x06'
        elif cmd==0x0c: data=b'\x0c\x64'
        elif cmd==0x0d: data=b'\x0d\x04\x00'
        elif cmd in (0x12,0x0e):
            offset=int.from_bytes(report[1:3],'big'); size=report[3]
            data=report[:4]+(self.keymap[offset:offset+size] if cmd==0x12 else bytes(size))
        elif cmd==0xfe:
            if sub==0: data=struct.pack('<IQ',5,UID)
            elif sub==1: data=struct.pack('<I',len(self.definition))
            elif sub==2:
                block=int.from_bytes(report[2:6],'little'); data=self.definition[block*32:block*32+32]
            elif sub==3: data=struct.pack('>HH',0xF9,0xFA)
            elif sub==9:
                after=int.from_bytes(report[2:4],'little'); ids=[x for x in range(1,22) if x>after][:16]
                if len(ids)<16: ids+=[65535]*(16-len(ids))
                data=struct.pack('<'+'H'*16,*ids)
            elif sub==10: data=bytes(32)
            elif sub==13:
                if report[2]==0: data=bytes([32,32,32,0])
                else: data=bytes(32)
        elif cmd==8:
            if sub==0x40: data=report[:2]+bytes([1,0,255])
            elif sub==0x41: data=report[:2]+struct.pack('<HBBBB',2,63,170,255,23)
            elif sub==0x42: data=report[:2]+struct.pack('<'+'H'*15,1,2,*([65535]*13))
        if data is None: raise AssertionError('Unexpected or mutating packet '+report.hex())
        return data.ljust(32,b'\0')

class ProtocolTests(unittest.TestCase):
    def test_reads_all_sections_from_transcript(self):
        tx=Transcript(); snapshot=read_snapshot(tx, {'pathToken':'fixture-1','generation':'g1'})
        self.assertEqual(snapshot.identity.uid, str(UID))
        self.assertEqual(len(snapshot.hardware['layout']),6)
        self.assertEqual(snapshot.hardware['layout'][0][0][0], 'KC_A')
        self.assertEqual(snapshot.hardware['layout'][0][0][3], 'TO(1)')
        self.assertEqual(snapshot.hardware['encoder_layout'][0], [['KC_WH_U','KC_WH_D']])
        self.assertEqual(len(snapshot.hardware['macro']),100)
        for field in ['tap_dance','combo','key_override']: self.assertEqual(len(snapshot.hardware[field]),32)
        self.assertEqual(snapshot.hardware['alt_repeat_key'],[])
        self.assertEqual(len(snapshot.hardware['settings']),21)
        self.assertEqual(snapshot.capabilities['macroBytes'],1024)
        self.assertEqual(snapshot.lighting['vialrgb']['hsv'],[170,255,23])
        self.assertEqual(snapshot.lighting['vialrgb']['effects'],[0,1,2])
    def test_guard_rejects_every_mutating_command(self):
        tx=Transcript(); guard=ReadOnlyExchange(tx)
        for report in [bytes([5]),bytes([3]),bytes([7]),bytes([9]),bytes([15]),bytes([0xfe,4]),bytes([0xfe,6]),bytes([0xfe,7]),bytes([0xfe,8]),bytes([0xfe,11]),bytes([0xfe,12]),bytes([0xfe,13,2]),bytes([0xfe,13,4])]:
            with self.assertRaises(ValueError): guard(report)
        self.assertEqual(tx.calls,[])
    def test_short_report_timeout_and_wrong_echo_fail(self):
        for exchange in [lambda r:bytes(31), lambda r:bytes(32)]:
            with self.assertRaises(ValueError): read_snapshot(exchange, {'pathToken':'x','generation':'g'})
        def timeout(r): raise TimeoutError('fixture timeout')
        with self.assertRaises(TimeoutError): read_snapshot(timeout, {'pathToken':'x','generation':'g'})
    def test_duplicate_identity_requires_explicit_selection(self):
        devices=[{'pathToken':'a'},{'pathToken':'b'}]
        with self.assertRaises(ValueError): select_descriptor(devices)
        self.assertEqual(select_descriptor(devices,'b'),devices[1])
        with self.assertRaises(ValueError): select_descriptor(devices,'gone')
    def test_query_loop_cannot_run_forever(self):
        tx=Transcript()
        def malformed(report):
            if report[:2]==bytes([0xfe,9]): return bytes(32)
            return tx(report)
        with self.assertRaises(ValueError): read_snapshot(malformed,{'pathToken':'x','generation':'g'})
