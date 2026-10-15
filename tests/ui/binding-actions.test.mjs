import test from 'node:test';
import assert from 'node:assert/strict';
import {keyboardAction,keyboardCode,setBindingAction,setKeyboardBinding} from '../../ui/binding-actions.mjs';
const keys=[{keyCode:0,name:'A'},{keyCode:11,name:'B'},{keyCode:36,name:'ENT'},{keyCode:49,name:'SPC'},{keyCode:105,name:'F13'}];
const firmware=[{code:'KC_A',value:4},{code:'KC_B',value:5},{code:'KC_F13',value:104},{code:'MO(1)',value:0x5221}];
const id='key:0:0',app='com.anthropic.claudefordesktop';
const open={kind:'openApp',parameters:{bundleID:'com.apple.TextEdit'}};
const draft=(code='KC_B')=>({hardware:{layout:[[[code]]]},profiles:{}});
test('app override preserves original supported key using native shortcut descriptor',()=>{
 const d=draft('LCTL(LALT(KC_B))');setBindingAction(d,id,app,open,keys,firmware);
 assert.deepEqual(d.profiles[id],{default:{kind:'shortcut',parameters:{keyCode:11,modifiers:['control','option']}},overrides:{[app]:open}});
 assert.equal(d.hardware.layout[0][0][0],'LCTL(LALT(KC_B))');
});
test('numeric firmware values resolve by catalog and never as native key codes',()=>{
 assert.deepEqual(keyboardAction(5,keys,firmware),{kind:'shortcut',parameters:{keyCode:11,modifiers:[]}});
 assert.deepEqual(keyboardAction(0x305,keys,firmware),{kind:'shortcut',parameters:{keyCode:11,modifiers:['control','shift']}});
 assert.deepEqual(keyboardAction('KC_ENTER',keys,firmware),{kind:'shortcut',parameters:{keyCode:36,modifiers:[]}});
});
test('unsupported and reserved original keys require an explicit fallback without mutation',()=>{
 for(const code of ['MO(1)','KC_F13',104,'RCTL(KC_B)','KC_NO']){const d=draft(code),before=structuredClone(d);assert.throws(()=>setBindingAction(d,id,app,open,keys,firmware),/fallback/i);assert.deepEqual(d,before)}
 const d=draft('KC_F13');setBindingAction(d,id,app,open,keys,firmware,'KC_A');assert.deepEqual(d.profiles[id].default,{kind:'shortcut',parameters:{keyCode:0,modifiers:[]}});
});
test('returning default to keyboard retains every app override and real fallback',()=>{
 const d=draft('KC_F13');d.profiles[id]={default:open,overrides:{[app]:open,'com.openai.codex':open}};
 setKeyboardBinding(d,id,'default','LSFT(KC_B)',keys,firmware);
 assert.deepEqual(d.profiles[id].overrides,{[app]:open,'com.openai.codex':open});assert.equal(d.profiles[id].default.kind,'shortcut');
 assert.equal(d.profiles[id].default.parameters.keyCode,11);assert.deepEqual(d.profiles[id].default.parameters.modifiers,['shift']);
});
test('returning default to hardware requires a real choice before deleting the profile',()=>{
 const d=draft('KC_F13');d.profiles[id]={default:open,overrides:{}};const before=structuredClone(d);
 assert.throws(()=>setKeyboardBinding(d,id,'default',null,keys,firmware),/choose/i);assert.deepEqual(d,before);
 assert.throws(()=>setKeyboardBinding(d,id,'default','KC_F13',keys,firmware),/reserved/i);assert.deepEqual(d,before);
 setKeyboardBinding(d,id,'default','KC_B',keys,firmware);assert.equal(d.profiles[id],undefined);assert.equal(d.hardware.layout[0][0][0],'KC_B');
});
test('known keyboard shortcut converts back without hidden profile metadata',()=>{
 const d=draft('KC_F13');d.profiles[id]={default:{kind:'shortcut',parameters:{keyCode:11,modifiers:['command','shift']}},overrides:{}};
 assert.equal(keyboardCode(d,id,keys,firmware),'LGUI(LSFT(KC_B))');
 setKeyboardBinding(d,id,'default',keyboardCode(d,id,keys,firmware),keys,firmware);assert.equal(d.profiles[id],undefined);
});
test('removing one inherited exception never removes other overrides or its default',()=>{
 const d=draft();setBindingAction(d,id,app,open,keys,firmware);setBindingAction(d,id,'com.openai.codex',open,keys,firmware);
 const fallback=structuredClone(d.profiles[id].default);setBindingAction(d,id,app,null,keys,firmware);
 assert.deepEqual(d.profiles[id].default,fallback);assert.deepEqual(d.profiles[id].overrides,{'com.openai.codex':open});
});
test('valid default-only profiles accept and remove exceptions without changing their default',()=>{
 const d=draft('KC_F13');d.profiles[id]={default:open};assert.doesNotThrow(()=>setBindingAction(d,id,app,null,keys,firmware));setBindingAction(d,id,app,open,keys,firmware);assert.deepEqual(d.profiles[id].default,open);assert.deepEqual(d.profiles[id].overrides,{[app]:open});
});
test('profiles with an omitted default cannot create an implicit Do nothing fallback',()=>{
 const d=draft('KC_F13');d.profiles[id]={overrides:{'com.openai.codex':open}};const before=structuredClone(d);
 assert.throws(()=>setBindingAction(d,id,app,open,keys,firmware),/fallback/i);assert.deepEqual(d,before);
 setBindingAction(d,id,app,open,keys,firmware,'KC_B');assert.equal(d.profiles[id].default.parameters.keyCode,11);assert.deepEqual(d.profiles[id].overrides,{'com.openai.codex':open,[app]:open});
});
test('held modifier originals are refused instead of becoming a tapped fallback',()=>{
 const native=[...keys,{keyCode:56,name:'LSFT'},{keyCode:59,name:'LCTL'},{keyCode:58,name:'LALT'},{keyCode:55,name:'LGUI'}];
 for(const code of ['KC_LSFT','KC_LCTL','KC_LALT','KC_LGUI']){assert.equal(keyboardAction(code,native,firmware),null);const d=draft(code),before=structuredClone(d);assert.throws(()=>setBindingAction(d,id,app,open,native,firmware),/fallback/i);assert.deepEqual(d,before)}
});
