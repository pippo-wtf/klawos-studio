import copy,json,unittest
from pathlib import Path
from klawos_device.model import parse_snapshot
from klawos_device.diff import merge_snapshot,plan_changes
ROOT=Path(__file__).resolve().parents[2]
def sample(): return parse_snapshot((ROOT/'tests/fixtures/baseline.vil').read_bytes())
class DiffTests(unittest.TestCase):
    def test_disjoint_edits_merge(self):
        base=sample();actual=copy.deepcopy(base);desired=copy.deepcopy(base)
        actual.hardware['layout'][0][0][0]='KC_B'
        desired.hardware['layout'][0][0][1]='KC_C'
        result=merge_snapshot(base,actual,desired)
        self.assertEqual(result.conflicts,[])
        self.assertEqual(result.snapshot.hardware['layout'][0][0][:2],['KC_B','KC_C'])
    def test_same_field_conflict_stops_plan(self):
        base=sample();actual=copy.deepcopy(base);desired=copy.deepcopy(base)
        actual.hardware['layout'][0][0][0]='KC_B';desired.hardware['layout'][0][0][0]='KC_C'
        result=merge_snapshot(base,actual,desired)
        self.assertIn('hardware.layout.0.0.0',result.conflicts)
        with self.assertRaises(ValueError):plan_changes(actual,desired,base)
    def test_macro_one_slot_change_preserves_aggregate(self):
        base=sample();desired=copy.deepcopy(base)
        desired.hardware['macro'][0]=[['text','Hello']]
        plan=plan_changes(base,desired,base)
        macros=[op for op in plan.operations if op.region_id=='macro']
        self.assertEqual(len(macros),1)
        self.assertEqual(len(macros[0].desired_new),100)
        self.assertEqual(macros[0].desired_new[1:],base.hardware['macro'][1:])
    def test_unknown_field_change_rejected(self):
        base=sample();desired=copy.deepcopy(base);desired.hardware['vendor_extension']={'new':1}
        with self.assertRaises(ValueError):plan_changes(base,desired,base)
