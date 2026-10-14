import copy,struct,unittest
from types import SimpleNamespace
from klawos_device.live_lighting import update_lighting

class LightingTests(unittest.TestCase):
    def setUp(self):
        self.rgb={'version':1,'maximumBrightness':255,'effects':[0,1,3],'mode':3,'speed':63,'hsv':[107,18,71]}
        self.base=SimpleNamespace(identity=SimpleNamespace(uid='123',vial_protocol=5),lighting={'vialrgb':self.rgb})
        self.current=copy.deepcopy(self.rgb);self.sent=[]
    def exchange(self,p):
        self.sent.append(p)
        if p==b'\xfe\x00':return struct.pack('<IQ',5,123).ljust(32,b'\0')
        if p==b'\x08\x41':return (p+struct.pack('<HBBBB',self.current['mode'],self.current['speed'],*self.current['hsv'])).ljust(32,b'\0')
        if p[:2]==b'\x07\x41':
            mode,speed,h,s,v=struct.unpack('<HBBBB',p[2:]);self.current.update(mode=mode,speed=speed,hsv=[h,s,v])
        return p.ljust(32,b'\0')
    def test_preview_only_writes_lighting_and_commit_saves_once(self):
        desired=copy.deepcopy(self.base.lighting);desired['vialrgb']['hsv'][0]=150
        update_lighting(self.base,desired,self.base.lighting,False,self.exchange)
        self.assertEqual(self.current['hsv'][0],150);self.assertNotIn(b'\x09',self.sent)
        update_lighting(self.base,desired,desired,True,self.exchange)
        self.assertEqual(self.sent.count(b'\x09'),1)
        self.assertTrue(all(p[:2] in [b'\xfe\x00',b'\x08\x41',b'\x07\x41'] or p==b'\x09' for p in self.sent))
    def test_external_color_change_is_not_overwritten(self):
        self.current['hsv'][0]=9
        with self.assertRaisesRegex(ValueError,'changed'):update_lighting(self.base,self.base.lighting,self.base.lighting,True,self.exchange)
        self.assertFalse(any(p[0] in [7,9] for p in self.sent))
    def test_wrong_device_and_invalid_values_never_write(self):
        self.base.identity.uid='999'
        with self.assertRaises(ValueError):update_lighting(self.base,self.base.lighting,self.base.lighting,True,self.exchange)
        self.assertFalse(any(p[0] in [7,9] for p in self.sent))
        self.base.identity.uid='123';bad=copy.deepcopy(self.base.lighting);bad['vialrgb']['hsv'][2]=256
        with self.assertRaises(ValueError):update_lighting(self.base,bad,self.base.lighting,False,self.exchange)
    def test_failed_readback_does_not_persist(self):
        desired=copy.deepcopy(self.base.lighting);desired['vialrgb']['hsv'][0]=150
        def lost(p):
            if p[:2]==b'\x07\x41':return p.ljust(32,b'\0')
            return self.exchange(p)
        with self.assertRaises(ValueError):update_lighting(self.base,desired,self.base.lighting,True,lost)
        self.assertNotIn(b'\x09',self.sent)
