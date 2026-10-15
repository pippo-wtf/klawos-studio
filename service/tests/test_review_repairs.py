"""Boundary regressions for review findings 1 and 10–13; no physical device access."""
import copy,json,subprocess,tempfile,unittest,uuid
from pathlib import Path
from unittest.mock import patch
from klawos_device.app_service import handle,validate
from klawos_device.apply import ApplyCoordinator,RecoveryRequired
from klawos_device.diff import merge_snapshot,plan_changes
from klawos_device.model import parse_snapshot
from klawos_device.recovery import list_recoveries,resolve,prune_verified
from klawos_device.validation import _action_tree,_macro_bytes
from klawos_device.writes import macro_payload,packets_for
from klawos_device.vial.protocol.macro import ProtocolMacro
from klawos_device.user_messages import user_message
ROOT=Path(__file__).resolve().parents[2]

class ReviewRepairTests(unittest.TestCase):
    def setUp(self):
        self.base=parse_snapshot((ROOT/'tests/fixtures/baseline.vil').read_bytes())
        self.base.capabilities=json.loads((ROOT/'tests/fixtures/capabilities.json').read_text())
        self.base.metadata['descriptor']={'pathToken':'fake','generation':'fake'}
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.store=Path(self.tmp.name)
    def payload(self):
        return {'base':self.base.to_wire(),'hardware':copy.deepcopy(self.base.hardware),'lighting':copy.deepcopy(self.base.lighting)}
    def roundtrip(self,macros,protocol=5):
        codec=ProtocolMacro();codec.vial_protocol=protocol;codec.macro_count=len(macros)
        return [[action.save() for action in slot] for slot in codec.macros_deserialize(macro_payload(macros,protocol))]
    def test_all_shipped_presets_survive_draft_preview_export_import(self):
        script="import {appShortcuts} from './ui/app-shortcuts.mjs'; console.log(JSON.stringify(appShortcuts))"
        presets=json.loads(subprocess.check_output(['node','--input-type=module','-e',script],cwd=ROOT))
        self.assertEqual(len(presets),10)
        for preset in presets:
            with self.subTest(preset=preset['id']):
                payload=self.payload();payload['profiles']={'0:0:0':{'default':preset['action'],'overrides':{}}}
                handle({'operation':'saveDraft','payload':payload},'/unused',self.store)
                self.assertEqual(handle({'operation':'loadDraft'},'/unused',self.store)['profiles'],payload['profiles'])
                class Session:
                    def __enter__(inner):return inner
                    def __exit__(inner,*args):pass
                    def read(inner):return copy.deepcopy(self.base)
                with patch('klawos_device.app_service.DeviceSession',return_value=Session()):
                    self.assertEqual(handle({'operation':'preview','payload':payload},'/unused',self.store)['changes'],[])
                exported=handle({'operation':'export','payload':payload},'/unused',self.store)
                imported=handle({'operation':'import','payload':{'base':payload['base'],**exported}},'/unused',self.store)
                self.assertEqual(imported['profiles'],payload['profiles'])
    def test_host_actions_reject_unsafe_or_malformed_native_parameters(self):
        cases=[('appShortcut',{'bundleID':'com.apple.Terminal','keyCode':11,'modifiers':['command']}),
               ('appShortcut',{'bundleID':'com.openai.codex','keyCode':True,'modifiers':[]}),
               ('appShortcut',{'bundleID':'com.openai.codex','keyCode':128,'modifiers':[]}),
               ('appShortcut',{'bundleID':'com.openai.codex','keyCode':11,'modifiers':['fn']}),
               ('appShortcut',{'bundleID':'com.openai.codex','keyCode':11,'modifiers':['command']*5}),
               ('appShortcut',{'bundleID':'com.openai.codex','keyCode':11,'modifiers':[],'extra':1}),
               ('openURL',{'url':'https://claude.ai/new'}),('openURL',{'url':'claude://claude.ai/new','extra':1}),
               ('openApp',{'bundleID':'/Applications/Terminal.app'}),('shortcut',{'keyCode':-1,'modifiers':[]}),
               ('none',{'extra':1}),('namedShortcut',{'name':'-unsafe'}),
               ('menuCommand',{'bundleID':'com.apple.TextEdit','menuPath':['File']}),('verifiedCommand',{})]
        for kind,parameters in cases:
            with self.subTest(kind=kind,parameters=parameters),self.assertRaises(ValueError):
                _action_tree({'default':{'kind':kind,'parameters':parameters}})
    def test_invalid_host_profiles_never_reach_preview_or_apply_transport(self):
        for operation in ['preview','apply']:
            payload=self.payload();payload['profiles']={'0:0:0':{'default':{'kind':'openURL','parameters':{'url':'file:///tmp/private'}}}}
            with self.subTest(operation=operation),patch('klawos_device.app_service.DeviceSession',side_effect=AssertionError('opened device')):
                with self.assertRaises(ValueError):handle({'operation':operation,'payload':payload},'/unused',self.store)

    def test_native_descriptor_id_and_parameter_types_are_restricted(self):
        for descriptor in [{'kind':'none','id':1,'parameters':{}}, {'kind':'openURL','parameters':['claude://claude.ai/new']}, {'kind':[],'parameters':{}}]:
            with self.subTest(descriptor=descriptor),self.assertRaises(ValueError):_action_tree(descriptor)
        for kind,parameters in [('none',{}),('openApp',{'bundleID':'com.apple.TextEdit'}),('namedShortcut',{'name':'Review draft'}),('menuCommand',{'bundleID':'com.apple.TextEdit','menuPath':['File','New']})]:
            _action_tree({'kind':kind,'id':'valid','parameters':parameters})
    def test_macro_rejects_every_reserved_extended_escape_for_each_key_action(self):
        for tag in ['tap','down','up']:
            for value in [0,*range(0xFF01,0x10000)]:
                with self.subTest(tag=tag,value=value),self.assertRaises(ValueError):
                    macro_payload([[[tag,value]],[['text','keep']]],5)

    def test_macro_grouping_roundtrip_verifies_without_weakening_actions(self):
        desired=copy.deepcopy(self.base)
        desired.hardware['macro'][0]=[['tap','KC_A'],['tap','KC_B'],['text','a'],['text','b'],['down','KC_LCTL'],['down','KC_LSFT'],['delay',1],['up','KC_LCTL'],['up','KC_LSFT']]
        actual=copy.deepcopy(self.base)
        def read():return copy.deepcopy(actual)
        def write(op):actual.hardware['macro']=self.roundtrip(op.desired_new)
        result=ApplyCoordinator(self.store,read,write,lambda s:validate(self.base,s)).apply(self.base,desired)
        self.assertEqual(result['status'],'verified')
        self.assertEqual(actual.hardware['macro'][0][:2],[['tap','KC_A','KC_B'],['text','ab']])
        self.assertEqual(plan_changes(actual,desired,desired).operations,[])
        damaged=copy.deepcopy(actual);damaged.hardware['macro'][0][0][2]='KC_C'
        self.assertTrue(merge_snapshot(desired,damaged,desired).snapshot.hardware['macro'][0][0][2]=='KC_C')
        actual=copy.deepcopy(self.base)
        def wrong_write(op):
            write(op);actual.hardware['macro'][0][1]=['text','changed']
        with self.assertRaises(RecoveryRequired):ApplyCoordinator(self.store,read,wrong_write).apply(self.base,desired)
    def test_macro_normalized_merge_keeps_raw_step_grouping_and_other_slots(self):
        base=copy.deepcopy(self.base);base.hardware['macro'][0]=[['tap','KC_A'],['tap','KC_B'],['text','x']]
        actual=copy.deepcopy(base);actual.hardware['macro']=self.roundtrip(actual.hardware['macro']);actual.hardware['macro'][1]=[['text','other Mac']]
        desired=copy.deepcopy(base);desired.hardware['macro'][0][2]=['text','y']
        merged=merge_snapshot(base,actual,desired)
        self.assertEqual(merged.conflicts,[])
        self.assertEqual(merged.snapshot.hardware['macro'][0],desired.hardware['macro'][0])
        self.assertEqual(merged.snapshot.hardware['macro'][1],[['text','other Mac']])
        actual.hardware['macro'][0][1]=['text','z']
        self.assertTrue(merge_snapshot(base,actual,desired).conflicts)
    def test_macro_rejects_delimiter_escape_codes_and_nonascii_before_writes(self):
        cases=[[['tap','KC_NO']],[['down',0]],[['up','0xFF01']],[['tap',65535]],
               [['text','\x01bad']],[['text','a\nb']],[['text','\x7f']],[['text','ä']],
               [['tap','missing']],[['delay',True]],[['delay',65025]]]
        for macro in cases:
            with self.subTest(macro=macro):
                (self.store/'draft.json').unlink(missing_ok=True)
                payload=self.payload();payload['hardware']['macro'][0]=macro;payload['hardware']['macro'][1]=[['text','keep']]
                for operation in ['saveDraft','preview','apply','export']:
                    with self.subTest(operation=operation),patch('klawos_device.app_service.DeviceSession',side_effect=AssertionError('opened device')):
                        with self.assertRaises(ValueError):handle({'operation':operation,'payload':payload},'/unused',self.store)
                self.assertFalse((self.store/'draft.json').exists())
                with self.assertRaises(ValueError):macro_payload(payload['hardware']['macro'],5)
    def test_legacy_macro_protocol_rejects_extended_codes_and_wait_before_serializing(self):
        for macro in [[['tap','0x1200']],[['delay',1]]]:
            with self.subTest(macro=macro),self.assertRaises(ValueError):macro_payload([macro],1)
        self.assertEqual(self.roundtrip([[['tap','KC_A'],['tap','KC_B']],[['text','keep']]],1),[[['tap','KC_A','KC_B']],[['text','keep']]])
    def test_empty_macro_steps_are_equivalent_to_their_encoded_sequence(self):
        desired=copy.deepcopy(self.base);desired.hardware['macro'][0]=[['text',''],['tap'],['text','a'],['text',''],['text','b']]
        actual=copy.deepcopy(desired);actual.hardware['macro']=self.roundtrip(desired.hardware['macro'])
        self.assertEqual(plan_changes(actual,desired,self.base).operations,[])
    def test_failed_resolution_rename_keeps_recovery_visible_and_evidence_intact(self):
        identifier=str(uuid.uuid4());directory=self.store/'backups'/identifier;directory.mkdir(parents=True)
        journal=directory/'journal.jsonl';journal.write_bytes(b'{"state":')
        with patch('klawos_device.recovery.os.replace',side_effect=OSError('disk failure')):
            with self.assertRaises(OSError):resolve(self.store,identifier)
        self.assertEqual(journal.read_bytes(),b'{"state":')
        self.assertEqual(list_recoveries(self.store),[{'id':identifier,'state':'journalIncomplete','regions':[]}])
        self.assertEqual(list(directory.iterdir()),[journal])

    def test_macro_valid_codes_preserve_all_slots_and_unknown_keymap_values(self):
        macros=[[['tap','0xFF00','0x1200','KC_A'],['text',' !~'],['delay',65024]],[['text','keep']],[]]
        decoded=self.roundtrip(macros)
        from klawos_device.keycodes import encode_keycode
        self.assertEqual([encode_keycode(k,5) for k in decoded[0][0][1:]],[0xFF00,0x1200,4])
        self.assertEqual(decoded[1:],[ [['text','keep']],[] ])
        self.assertEqual(_macro_bytes(macros,5),len(macro_payload(macros,5)))
        desired=copy.deepcopy(self.base);desired.hardware['layout'][0][0][0]=65535
        validate(self.base,desired)
        self.assertEqual(packets_for(plan_changes(self.base,desired,self.base).operations[0],5)[0][-2:],b'\xff\xff')
    def test_macro_preflight_message_explains_safe_text_and_key_actions(self):
        for macro,expected in [([['text','ä']],'ASCII'),([['tap','KC_NO']],'macro')]:
            try:_macro_bytes([macro],5)
            except ValueError as error:self.assertIn(expected,user_message(error))
            else:self.fail('unsafe macro was accepted')
    def test_macro_guidance_does_not_forward_private_error_context(self):
        self.assertNotIn('/private/secret',user_message(ValueError('/private/secret cannot be stored')))

    def test_damaged_journal_resolution_is_durable_and_preserves_original_evidence(self):
        for content in [b'{"state":"prepared"}\n{"state":',b'\xff\xfe',b'{"state":"writeIntent"}',b'null\n']:
            with self.subTest(content=content):
                identifier=str(uuid.uuid4());directory=self.store/'backups'/identifier;directory.mkdir(parents=True)
                journal=directory/'journal.jsonl';journal.write_bytes(content)
                (directory/'before.json').write_text('{"identity":{"uid":"1"}}')
                self.assertIn(identifier,[r['id'] for r in list_recoveries(self.store)])
                resolve(self.store,identifier)
                self.assertNotIn(identifier,[r['id'] for r in list_recoveries(self.store)])
                self.assertEqual(journal.read_bytes(),content)
                resolve(self.store,identifier)
                self.assertEqual(journal.read_bytes(),content)
                prune_verified(self.store,keep=0)
                self.assertTrue(journal.exists(),'dismissal must not destroy damaged evidence')
