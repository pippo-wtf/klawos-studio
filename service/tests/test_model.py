import copy
import json
import unittest
from pathlib import Path

from klawos_device.model import parse_snapshot, canonical_revision, validate_message, resolve_binding

FIXTURE = Path(__file__).resolve().parents[2] / 'tests/fixtures/baseline.vil'


class ModelTests(unittest.TestCase):
    def document(self):
        return json.loads(FIXTURE.read_bytes())

    def parse(self, document=None):
        result = parse_snapshot(json.dumps(document or self.document()).encode())
        self.assertIsNotNone(result, 'A valid Vial document must yield a snapshot')
        return result

    def test_uid_stays_exact_across_native_model_and_vial_export(self):
        s = self.parse()
        self.assertEqual(s.identity.uid, '6994672159869375106')
        self.assertEqual(s.to_vil()['uid'], 6994672159869375106)
        self.assertEqual(s.to_wire()['hardware']['uid'], '6994672159869375106')

    def test_retains_all_layers_encoder_bindings_and_extension_fields(self):
        s = self.parse()
        self.assertEqual(len(s.hardware['layout']), 6)
        self.assertEqual(s.hardware['layout'][0][0][3], 'TO(1)')
        self.assertEqual(s.hardware['layout'][1][0][3], 'TO(2)')
        self.assertEqual(s.hardware['layout'][2][0][3], 'TO(0)')
        self.assertEqual(s.hardware['encoder_layout'][0], [['KC_WH_U', 'KC_WH_D']])
        self.assertEqual(s.hardware['vendor_extension'], {'sentinel': 65535})

    def test_unknown_numeric_keycode_round_trips_without_normalization(self):
        d = self.document(); d['layout'][5][3][3] = 65534
        self.assertEqual(self.parse(d).to_vil()['layout'][5][3][3], 65534)

    def test_large_unknown_integer_is_retained_in_original_document(self):
        d = self.document(); d['vendor_extension']['large_value'] = 18446744073709551615
        self.assertEqual(self.parse(d).to_vil()['vendor_extension']['large_value'], 18446744073709551615)

    def test_rejects_duplicate_object_keys(self):
        with self.assertRaises(ValueError):
            parse_snapshot(b'{"uid":1,"uid":2}')

    def test_rejects_nonfinite_numbers(self):
        with self.assertRaises(ValueError):
            parse_snapshot(b'{"uid":NaN}')

    def test_rejects_more_than_32_levels(self):
        d = self.document(); value = 0
        for _ in range(33): value = {'nested': value}
        d['vendor_extension'] = value
        with self.assertRaises(ValueError): parse_snapshot(json.dumps(d).encode())

    def test_rejects_documents_above_four_mebibytes(self):
        with self.assertRaises(ValueError): parse_snapshot(b' ' * (4 * 1024 * 1024 + 1))

    def test_rejects_float_boolean_and_out_of_range_uids(self):
        for uid in [6994672159869375106.0, True, -1, 18446744073709551616, '0x1234']:
            with self.subTest(uid=uid):
                d = self.document(); d['uid'] = uid
                with self.assertRaises(ValueError): parse_snapshot(json.dumps(d).encode())

    def test_revision_ignores_capture_time_and_key_order(self):
        a = self.parse(); b = self.parse(dict(reversed(list(self.document().items()))))
        a.captured_at = 'yesterday'; b.captured_at = 'today'
        self.assertEqual(canonical_revision(a), canonical_revision(b))
        self.assertEqual(len(canonical_revision(a)), 64)

    def test_revision_changes_when_hardware_or_lighting_changes(self):
        a = self.parse(); b = self.parse(); c = self.parse()
        b.hardware['layout'][0][1][0] = 'KC_ESCAPE'
        c.lighting = {'hsv': [0, 255, 23]}
        self.assertNotEqual(canonical_revision(a), canonical_revision(b))
        self.assertNotEqual(canonical_revision(a), canonical_revision(c))

    def test_snapshot_does_not_share_mutable_import_data(self):
        s = self.parse(); exported = s.to_vil()
        exported['layout'][0][0][0] = 'KC_ESCAPE'
        self.assertEqual(s.hardware['layout'][0][0][0], 'KC_A')

    def test_explicit_none_does_not_inherit_default_action(self):
        profiles = {'default': {'kind': 'app', 'id': 'terminal'}, 'overrides': {'claude': {'kind': 'none'}}}
        self.assertEqual(resolve_binding(profiles, 'claude'), {'kind': 'none'})
        self.assertEqual(resolve_binding(profiles, 'codex'), {'kind': 'app', 'id': 'terminal'})

    def test_request_requires_known_operation_and_correlation(self):
        base = {'requestID': 'read-1', 'operationID': 'device-generation-1', 'kind': 'command',
                'operation': 'read', 'payload': {}}
        self.assertEqual(validate_message(json.dumps(base).encode()), base)
        for field, value in [('requestID', ''), ('operationID', ''), ('kind', 'execute-shell'), ('operation', 'shell')]:
            d = copy.deepcopy(base); d[field] = value
            with self.subTest(field=field):
                with self.assertRaises(ValueError): validate_message(json.dumps(d).encode())

    def test_draft_patch_refuses_missing_and_expired_revisions(self):
        d = {'requestID': 'patch-1', 'operationID': 'g1', 'kind': 'command', 'operation': 'patch', 'payload': {}}
        with self.assertRaises(ValueError): validate_message(json.dumps(d).encode(), known_revisions={'r1'})
        d['draftRevision'] = 'expired'
        with self.assertRaises(ValueError): validate_message(json.dumps(d).encode(), known_revisions={'r1'})
        d['draftRevision'] = 'r1'
        self.assertEqual(validate_message(json.dumps(d).encode(), known_revisions={'r1'})['draftRevision'], 'r1')


if __name__ == '__main__': unittest.main()
