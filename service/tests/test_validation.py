import copy,json,unittest
from pathlib import Path
from klawos_device.validation import validate_project
ROOT=Path(__file__).resolve().parents[2]
class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.project=json.loads((ROOT/'tests/fixtures/project.klawos').read_text())
        self.caps=json.loads((ROOT/'tests/fixtures/capabilities.json').read_text())
        self.caps['macroBytes']=2845
    def raw(self): return json.dumps(self.project).encode()
    def test_valid_project_preserves_unknown_fields(self):
        self.project['hardware']['futureField']={'numeric':65535}
        result=validate_project(self.raw(),self.caps)
        self.assertEqual(result.document['hardware']['futureField']['numeric'],65535)
        self.assertIn('hardware.futureField',result.read_only_fields)
    def test_rejects_other_uid_and_invalid_count(self):
        self.project['identity']['uid']='2'
        with self.assertRaises(ValueError): validate_project(self.raw(),self.caps)
        self.project['identity']['uid']='6994672159869375106'
        self.project['hardware']['layout'].pop()
        with self.assertRaises(ValueError): validate_project(self.raw(),self.caps)
    def test_rejects_executable_import_actions(self):
        for kind in ['shell','appleScript','terminal','urlScript']:
            self.project['profiles']={'default':{'kind':kind,'command':'rm -rf /'}}
            with self.subTest(kind=kind),self.assertRaises(ValueError):validate_project(self.raw(),self.caps)
    def test_rejects_duplicate_keys_and_unsupported_setting(self):
        raw=self.raw().replace(b'"format_version": 1',b'"format_version": 1, "format_version": 1',1)
        with self.assertRaises(ValueError):validate_project(raw,self.caps)
        self.project['hardware']['settings']['999']=1
        with self.assertRaises(ValueError):validate_project(self.raw(),self.caps)
    def test_rejects_macro_memory_overflow_without_truncation(self):
        self.project['hardware']['macro'][0]=[['text','x'*2845]]
        with self.assertRaises(ValueError):validate_project(self.raw(),self.caps)
    def test_rejects_null_macro_text_and_overwide_settings(self):
        self.project['hardware']['macro'][0]=[['text','a\0b']]
        with self.assertRaises(ValueError):validate_project(self.raw(),self.caps)
        self.project['hardware']['macro'][0]=[]
        self.project['hardware']['settings']['1']=1000000
        with self.assertRaises(ValueError):validate_project(self.raw(),self.caps)
    def test_rejects_malformed_dynamic_entry(self):
        self.project['hardware']['tap_dance'][0][4]=65536
        with self.assertRaises(ValueError):validate_project(self.raw(),self.caps)
    def test_lighting_is_separate_from_vil(self):
        result=validate_project(self.raw(),self.caps)
        self.assertEqual(result.snapshot.to_vil()['uid'],6994672159869375106)
        self.assertNotIn('lighting',result.snapshot.to_vil())
