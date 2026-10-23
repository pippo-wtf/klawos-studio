import test from 'node:test';
import assert from 'node:assert/strict';
import * as editor from '../../ui/editor-actions.mjs';
import {createDraft} from '../../ui/state.mjs';
import {keyName,reviewRows} from '../../ui/copy.mjs';
const snapshot={hardware:{layout:Array.from({length:6},()=>Array.from({length:4},()=>Array(4).fill('KC_A')))},lighting:{}};
test('macro waits accept numbers while text and key steps keep their exact meaning',()=>{
 assert.deepEqual(editor.macroStep('delay',200,x=>x),['delay',200]);
 assert.deepEqual(editor.macroStep('text','A + B, C',x=>x),['text','A + B, C']);
 assert.deepEqual(editor.macroStep('tap','A + B',x=>'KC_'+x),['tap','KC_A','KC_B']);
 for(const value of [-1,1.5,65025,NaN])assert.throws(()=>editor.macroStep('delay',value,x=>x),/Wait/);
});
test('slot assignments are staged, locate usage, and protect manual knob switching',()=>{
 const d=createDraft(snapshot);d.profiles={'key:2:3':{default:{kind:'openApp',parameters:{bundleID:'example.app'}}}};
 const base=structuredClone(d.base);
 editor.assignSlot(d,'macro',2,0,'key:2:3');
 assert.equal(d.hardware.layout[0][2][3],'M2');assert.equal(d.profiles['key:2:3'],undefined);
 assert.deepEqual(editor.slotUses(d,'macro',2),[{layer:0,id:'key:2:3'}]);assert.deepEqual(d.base,base);
 assert.throws(()=>editor.assignSlot(d,'tap_dance',0,0,'key:0:3'),/knob/i);
 editor.assignSlot(d,'tap_dance',0,1,'key:1:0');assert.equal(d.hardware.layout[1][1][0],'TD(0)');
});
test('review describes app outcomes without exposing reserved transport changes',()=>{
 const d=createDraft(snapshot);d.hardware.layout[0][2][3]='KC_F13';d.profiles={'key:2:3':{default:{kind:'openApp',parameters:{bundleID:'com.openai.codex'}},overrides:{}}};
 const changes=[{region:'hardware.layout.0.2.3',before:'KC_A',after:'KC_F13'},{region:'Mac action · key:2:3',before:null,after:d.profiles['key:2:3']}];
 const rows=reviewRows(changes,d);assert.equal(rows.length,1);assert.match(rows[0].title,/Layer 1.*Key 12/);assert.match(rows[0].after,/Open Codex/);assert.doesNotMatch(JSON.stringify(rows),/F13|KC_/);
 d.baseProfiles=structuredClone(d.profiles);d.profiles={};d.hardware.layout[0][2][3]='KC_B';
 const reset=reviewRows([{region:'Mac action · key:2:3',before:d.baseProfiles['key:2:3'],after:null}],d);
 assert.match(reset[0].after,/B/);assert.doesNotMatch(reset[0].after,/F13/);
});

test('assigned slots have readable button names',()=>{assert.equal(keyName('M2'),'Macro 3');assert.equal(keyName('TD(0)'),'Tap & hold 1');});
