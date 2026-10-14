import json,struct,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
class ModelAssetTests(unittest.TestCase):
    def test_all_switches_have_stable_glb_metadata(self):
        raw=(ROOT/'ui/models/klawos.glb').read_bytes()
        self.assertEqual(raw[:4],b'glTF');self.assertEqual(struct.unpack_from('<I',raw,4)[0],2)
        length=struct.unpack_from('<I',raw,12)[0];model=json.loads(raw[20:20+length])
        ids=[n['extras']['inputID'] for n in model['nodes'] if 'inputID' in n.get('extras',{})]
        self.assertEqual(set(ids),{f'key:{r}:{c}' for r in range(4) for c in range(4)})
        self.assertEqual(len(ids),16)
        self.assertFalse(any('uri' in b for b in model['buffers']))
    def test_encoder_directions_are_separate_accessible_controls(self):
        mapping=json.loads((ROOT/'ui/models/control-map.json').read_text())
        self.assertEqual(len(mapping),18)
        for direction in ['cw','ccw']:self.assertTrue(mapping[f'encoder:0:{direction}']['separateControl'])
