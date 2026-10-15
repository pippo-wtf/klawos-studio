import copy,json,unittest
from pathlib import Path
from klawos_device.model import parse_snapshot
from klawos_device.diff import merge_snapshot,plan_changes
ROOT=Path(__file__).resolve().parents[2]
def sample(): return parse_snapshot((ROOT/'tests/fixtures/baseline.vil').read_bytes())
class DiffTests(unittest.TestCase):
    def test_equivalent_keycode_spelling_is_not_an_external_conflict(self):
        base=sample();base.hardware['layout'][0][0][0]='LCTL(LALT(KC_B))'
        actual=copy.deepcopy(base);actual.hardware['layout'][0][0][0]='LCA(KC_B)'
        desired=copy.deepcopy(base)
        self.assertEqual(plan_changes(actual,desired,base).operations,[])
        desired.hardware['layout'][0][0][0]='KC_C'
        self.assertEqual(len(plan_changes(actual,desired,base).operations),1)
    def test_keycode_aliases_match_across_advanced_regions_without_changing_numbers_or_text(self):
        base=sample()
        base.hardware.update(encoder_layout=[[['LCTL(LALT(KC_B))','KC_B']]],
            macro=[[['tap','LCTL(LALT(KC_B))'],['text','KC_A'],['delay',100]]],
            combo=[['KC_A','KC_B','KC_NO','KC_NO','LCTL(LALT(KC_B))']],
            tap_dance=[['LCTL(LALT(KC_B))','KC_NO','KC_NO','KC_NO',200]],
            key_override=[{'trigger':'KC_A','replacement':'LCTL(LALT(KC_B))','layers':65535}],
            alt_repeat_key=[{'keycode':'LCTL(LALT(KC_B))','alt_keycode':'KC_B','options':1}])
        actual=copy.deepcopy(base)
        def alias(value):
            if isinstance(value,list):return [alias(v) for v in value]
            if isinstance(value,dict):return {k:alias(v) for k,v in value.items()}
            return 'LCA(KC_B)' if value=='LCTL(LALT(KC_B))' else value
        actual.hardware=alias(actual.hardware)
        before=copy.deepcopy(base)
        def previous(value):
            if isinstance(value,list):return [previous(v) for v in value]
            if isinstance(value,dict):return {k:previous(v) for k,v in value.items()}
            return 'KC_C' if value=='LCTL(LALT(KC_B))' else value
        before.hardware=previous(before.hardware)
        self.assertEqual(plan_changes(actual,base,before).operations,[])
        desired=copy.deepcopy(base);desired.hardware['macro'][0][1]=['text','KC_B']
        self.assertEqual([op.region_id for op in plan_changes(actual,desired,base).operations],['macro'])
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
