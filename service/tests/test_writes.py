import copy,unittest
from klawos_device.writes import packets_for,validate_lighting
from klawos_device.diff import DeviceOperation
class WriteTests(unittest.TestCase):
    def packets(self,region,value):return packets_for(DeviceOperation('x',[],None,value,region),5)
    def test_key_and_encoder_match_upstream(self):
        self.assertEqual(self.packets('hardware.layout.2.3.1','KC_A'),[bytes.fromhex('050203010004')])
        self.assertEqual(self.packets('hardware.encoder_layout.1.0.1','KC_B'),[bytes.fromhex('fe040100010005')])
    def test_dynamic_entries_use_little_endian(self):
        self.assertEqual(self.packets('hardware.tap_dance.3',['KC_A','KC_B','KC_NO','KC_TRNS',200]),[bytes.fromhex('fe0d02030400050000000100c800')])
        self.assertEqual(self.packets('hardware.combo.2',['KC_A']*5),[bytes.fromhex('fe0d040204000400040004000400')])
    def test_macro_all_slots_and_chunk_offsets(self):
        result=self.packets('macro',[[['text','a'*40]],[]])
        self.assertEqual(result[0][:4],bytes.fromhex('0f00001c'))
        self.assertEqual(result[1][:4],bytes.fromhex('0f001c0e'))
        self.assertEqual(b''.join(p[4:] for p in result),b'a'*40+b'\0\0')
    def test_unsupported_region_rejected(self):
        with self.assertRaises(ValueError):self.packets('hardware.uid',0)
    def test_lighting_ranges_and_capabilities(self):
        old={'version':1,'maximumBrightness':255,'mode':3,'speed':63,'hsv':[208,93,71],'effects':[0,3]}
        new=copy.deepcopy(old);new['hsv'][2]=100
        validate_lighting({'vialrgb':old},{'vialrgb':new})
        self.assertEqual(self.packets('lighting.vialrgb',new),[bytes.fromhex('074103003fd05d64'),b'\x09'])
        new['mode']=100
        with self.assertRaises(ValueError):validate_lighting({'vialrgb':old},{'vialrgb':new})
    def test_unknown_lighting_metadata_cannot_change(self):
        old={'vialrgb':{'mode':3,'speed':63,'hsv':[1,2,3],'effects':[3],'maximumBrightness':255}}
        new=copy.deepcopy(old);new['vialrgb']['effects']=[9]
        with self.assertRaises(ValueError):validate_lighting(old,new)
