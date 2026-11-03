"""Layer labels remain portable without changing keyboard settings."""
import copy,json,tempfile,unittest
from pathlib import Path
from klawos_device.app_service import handle
from klawos_device.model import parse_snapshot

ROOT=Path(__file__).resolve().parents[2]

class LayerNameTests(unittest.TestCase):
    def setUp(self):
        snapshot=parse_snapshot((ROOT/'tests/fixtures/baseline.vil').read_bytes())
        snapshot.capabilities=json.loads((ROOT/'tests/fixtures/capabilities.json').read_text())
        snapshot.capabilities['macro_bytes']=2845
        self.payload={'base':snapshot.to_wire(),'hardware':snapshot.to_wire()['hardware'],
                      'lighting':snapshot.lighting,'profiles':{},
                      'projectDocument':{'metadata':{'layerNames':['Writing','Editing','Music','Drawing','Layer 5','Layer 6']}}}
        self.directory=tempfile.TemporaryDirectory();self.addCleanup(self.directory.cleanup)
        self.store=Path(self.directory.name)

    def test_all_layer_names_survive_reopen_and_export_without_device_access(self):
        before=copy.deepcopy(self.payload)
        handle({'operation':'saveDraft','payload':self.payload},'/nonexistent',self.store)
        loaded=handle({'operation':'loadDraft'},'/nonexistent',self.store)
        exported=handle({'operation':'export','payload':loaded},'/nonexistent',self.store)
        imported=handle({'operation':'import','payload':{'base':self.payload['base'],'document':exported['document']}},'/nonexistent',self.store)
        self.assertEqual(imported['projectDocument']['metadata']['layerNames'],['Writing','Editing','Music','Drawing','Layer 5','Layer 6'])
        self.assertEqual(loaded['hardware'],before['hardware'])
        self.assertEqual(loaded['profiles'],before['profiles'])
        self.assertEqual(self.payload,before)

    def test_nonportable_names_never_replace_a_saved_draft(self):
        handle({'operation':'saveDraft','payload':self.payload},'/nonexistent',self.store)
        original=(self.store/'draft.json').read_bytes()
        for invalid in ['Writing',[42],['A']*17,['A'*81],['A\0B']]:
            with self.subTest(names=repr(invalid)):
                bad=copy.deepcopy(self.payload);bad['projectDocument']['metadata']['layerNames']=invalid
                with self.assertRaisesRegex(ValueError,'layer names'):
                    handle({'operation':'saveDraft','payload':bad},'/nonexistent',self.store)
                self.assertEqual((self.store/'draft.json').read_bytes(),original)

    def test_nonportable_names_cannot_be_imported_or_exported(self):
        valid=json.loads(handle({'operation':'export','payload':self.payload},'/nonexistent',self.store)['document'])
        for invalid in ['Writing',[None],['A']*17,['A'*81],['A\0B']]:
            with self.subTest(names=repr(invalid)):
                document=copy.deepcopy(valid);document['metadata']['layerNames']=invalid
                with self.assertRaisesRegex(ValueError,'layer names'):
                    handle({'operation':'import','payload':{'base':self.payload['base'],'document':json.dumps(document)}},'/nonexistent',self.store)
                bad=copy.deepcopy(self.payload);bad['projectDocument']['metadata']['layerNames']=invalid
                with self.assertRaisesRegex(ValueError,'layer names'):
                    handle({'operation':'export','payload':bad},'/nonexistent',self.store)
