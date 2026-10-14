import copy,json,tempfile,unittest
from pathlib import Path
from klawos_device.model import parse_snapshot
from klawos_device.apply import ApplyCoordinator,RecoveryRequired
ROOT=Path(__file__).resolve().parents[2]
class ApplyTests(unittest.TestCase):
    def setUp(self):
        self.base=parse_snapshot((ROOT/'tests/fixtures/baseline.vil').read_bytes())
        self.actual=copy.deepcopy(self.base);self.desired=copy.deepcopy(self.base)
        self.desired.hardware['layout'][0][0][0]='KC_B'
        self.directory=tempfile.TemporaryDirectory();self.addCleanup(self.directory.cleanup)
        self.writes=[]
    def read(self):return copy.deepcopy(self.actual)
    def write(self,op):
        self.writes.append(op)
        self.actual.hardware['layout'][0][0][0]=op.desired_new
    def coordinator(self,write=None):
        return ApplyCoordinator(Path(self.directory.name),self.read,write or self.write)
    def test_verified_save_keeps_backup_and_journal(self):
        result=self.coordinator().apply(self.base,self.desired)
        self.assertEqual(result['status'],'verified');self.assertEqual(len(self.writes),1)
        backup=json.loads(next(Path(self.directory.name).glob('*/before.json')).read_text())
        self.assertEqual(backup['hardware']['layout'][0][0][0],'KC_A')
    def test_conflict_prevents_writes(self):
        self.actual.hardware['layout'][0][0][0]='KC_C'
        with self.assertRaises(ValueError):self.coordinator().apply(self.base,self.desired)
        self.assertEqual(self.writes,[])
    def test_ambiguous_success_is_read_back_not_replayed(self):
        def write(op):self.write(op);raise TimeoutError()
        self.assertEqual(self.coordinator(write).apply(self.base,self.desired)['status'],'verified')
        self.assertEqual(len(self.writes),1)
    def test_failed_write_retains_recovery(self):
        def write(op):self.writes.append(op);raise TimeoutError()
        with self.assertRaises(RecoveryRequired):self.coordinator(write).apply(self.base,self.desired)
        self.assertEqual(len(self.writes),1)
        journal=next(Path(self.directory.name).glob('*/journal.jsonl')).read_text()
        self.assertIn('recoveryRequired',journal)
    def test_backup_failure_has_zero_writes(self):
        bad=Path(self.directory.name)/'file';bad.write_text('occupied')
        with self.assertRaises(OSError):ApplyCoordinator(bad,self.read,self.write).apply(self.base,self.desired)
        self.assertEqual(self.writes,[])
    def test_unrelated_external_change_is_preserved(self):
        self.actual.hardware['layout'][1][0][0]='KC_Z'
        result=self.coordinator().apply(self.base,self.desired)
        self.assertEqual(result['snapshot']['hardware']['layout'][1][0][0],'KC_Z')
    def test_final_drift_never_claims_verified(self):
        calls=0
        def read():
            nonlocal calls
            calls+=1
            if calls==4:self.actual.hardware['layout'][0][0][0]='KC_C'
            return self.read()
        with self.assertRaises(RecoveryRequired):ApplyCoordinator(Path(self.directory.name),read,self.write).apply(self.base,self.desired)

    def test_merged_macro_capacity_rejected_before_any_write(self):
        from klawos_device.app_service import validate
        self.base.capabilities=json.loads((ROOT/'tests/fixtures/capabilities.json').read_text())
        self.base.hardware['macro']=[[] for _ in self.base.hardware['macro']]
        self.actual=copy.deepcopy(self.base);self.desired=copy.deepcopy(self.base)
        self.actual.hardware['macro'][1]=[['text','x'*1500]]
        self.desired.hardware['macro'][0]=[['text','y'*1500]]
        with self.assertRaisesRegex(ValueError,'Macro buffer'):
            ApplyCoordinator(self.directory.name,self.read,self.write,lambda s:validate(self.base,s)).apply(self.base,self.desired)
        self.assertEqual(self.writes,[])
