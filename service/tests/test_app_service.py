import copy,json,tempfile,unittest
from pathlib import Path
from klawos_device.app_service import from_wire,handle,validate
from klawos_device.model import parse_snapshot
ROOT=Path(__file__).resolve().parents[2]
class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.snapshot=parse_snapshot((ROOT/'tests/fixtures/baseline.vil').read_bytes())
        self.snapshot.capabilities=json.loads((ROOT/'tests/fixtures/capabilities.json').read_text())
        self.snapshot.capabilities['macro_bytes']=2845
        self.dir=tempfile.TemporaryDirectory();self.addCleanup(self.dir.cleanup);self.store=Path(self.dir.name)
    def test_wire_revision_and_uid_roundtrip(self):
        wire=self.snapshot.to_wire();self.assertEqual(from_wire(wire).identity,self.snapshot.identity)
        wire['hardware']['layout'][0][0][0]='KC_B'
        with self.assertRaises(ValueError):from_wire(wire)
    def test_draft_roundtrip_without_any_device(self):
        s=self.snapshot;payload={'base':s.to_wire(),'hardware':s.to_wire()['hardware'],'lighting':s.lighting}
        handle({'operation':'saveDraft','payload':payload},'/nonexistent',self.store)
        loaded=handle({'operation':'loadDraft'},'/nonexistent',self.store)
        self.assertEqual(loaded,payload)
    def test_invalid_draft_never_saves(self):
        s=self.snapshot;payload={'base':s.to_wire(),'hardware':copy.deepcopy(s.hardware),'lighting':{}}
        payload['hardware']['layout'][0][0][0]='arbitrary script'
        with self.assertRaises(ValueError):handle({'operation':'saveDraft','payload':payload},'/nonexistent',self.store)
        self.assertFalse((self.store/'draft.json').exists())
    def test_export_retains_numeric_vial_uid_without_device_access(self):
        s=self.snapshot;r=handle({'operation':'export','payload':{'base':s.to_wire(),'hardware':s.hardware,'lighting':{},'format':'vil'}},'/nonexistent',self.store)
        self.assertEqual(json.loads(r['document'])['uid'],6994672159869375106)
    def test_unknown_operation_rejected(self):
        with self.assertRaises(ValueError):handle({'operation':'shell'},'/nonexistent',self.store)

    def test_large_integer_wire_roundtrip(self):
        self.snapshot.hardware['future']=9007199254740993
        self.assertEqual(from_wire(self.snapshot.to_wire()).hardware['future'],9007199254740993)
    def test_native_import_export_retains_extensions(self):
        s=self.snapshot
        document={'format_version':1,'identity':s.identity.to_wire(),'hardware':s.to_vil(),'lighting':{},'profiles':{},'metadata':{'layerNames':['Work']},'futureSafeField':{'value':42}}
        imported=handle({'operation':'import','payload':{'base':s.to_wire(),'document':json.dumps(document)}},'/nonexistent',self.store)
        exported=handle({'operation':'export','payload':{'base':s.to_wire(),**imported}},'/nonexistent',self.store)
        result=json.loads(exported['document'])
        self.assertEqual(result['metadata'],document['metadata']);self.assertEqual(result['futureSafeField'],document['futureSafeField'])
    def test_validation_does_not_mutate_snapshot_uid_representation(self):
        desired=copy.deepcopy(self.snapshot);before=copy.deepcopy(desired)
        validate(self.snapshot,desired)
        self.assertEqual(desired,before)
