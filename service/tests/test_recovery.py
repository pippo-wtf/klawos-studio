import copy,unittest
from pathlib import Path
from klawos_device.model import parse_snapshot
from klawos_device.recovery import recovery_draft
ROOT=Path(__file__).resolve().parents[2]
class RecoveryTests(unittest.TestCase):
    def test_restoration_only_touches_original_regions(self):
        before=parse_snapshot((ROOT/'tests/fixtures/baseline.vil').read_bytes());intended=copy.deepcopy(before)
        intended.hardware['layout'][0][0][0]='KC_B';current=copy.deepcopy(intended)
        current.hardware['layout'][3][2][2]='KC_Z'
        recovered=recovery_draft(before,intended,current,'restoreChangedRegions')
        self.assertEqual(recovered.hardware['layout'][0][0][0],'KC_A')
        self.assertEqual(recovered.hardware['layout'][3][2][2],'KC_Z')
        self.assertEqual(current.hardware['layout'][0][0][0],'KC_B')
        self.assertEqual(recovery_draft(before,intended,recovered,'restoreChangedRegions'),recovered)
    def test_keep_current_never_replays(self):
        s=parse_snapshot((ROOT/'tests/fixtures/baseline.vil').read_bytes());wanted=copy.deepcopy(s);wanted.hardware['layout'][0][0][0]='KC_B'
        self.assertEqual(recovery_draft(s,wanted,s,'keepCurrent'),s)
    def test_retention_keeps_unresolved_backups(self):
        import tempfile,uuid
        from klawos_device.recovery import prune_verified
        with tempfile.TemporaryDirectory() as tmp:
            store=Path(tmp);root=store/'backups';root.mkdir()
            for i in range(24):
                directory=root/str(uuid.uuid4());directory.mkdir()
                (directory/'before.json').write_text('{"identity":{"uid":"1"}}')
                (directory/'journal.jsonl').write_text('{"state":"complete"}\n')
            unresolved=root/str(uuid.uuid4());unresolved.mkdir()
            (unresolved/'before.json').write_text('{"identity":{"uid":"1"}}')
            (unresolved/'journal.jsonl').write_text('{"state":"writeIntent"}\n')
            prune_verified(store)
            self.assertTrue(unresolved.exists());self.assertEqual(len(list(root.iterdir())),21)
