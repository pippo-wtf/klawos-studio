import test from 'node:test';import assert from 'node:assert/strict';
import {keyName,changeTitle,changeRows,tabLabel,settingLabel,combinationName} from '../../ui/copy.mjs';
const names=['Work','Dota','Wardogs','Layer 4','Layer 5','Layer 6'];
test('friendly labels preserve the exact meaning of keys and layers',()=>{assert.equal(keyName('KC_A',names),'A');assert.equal(keyName('TO(1)',names),'Switch to Dota');assert.equal(keyName('KC_TRNS',names),'Use lower layer');assert.equal(keyName(65500,names),'Key code 65500');assert.equal(tabLabel('Matrix tester'),'Test keys');});
test('save preview names physical keys and changed macro slots',()=>{assert.equal(changeTitle('hardware.layout.1.0.3',names),'Dota · Press knob');const rows=changeRows({region:'macro',before:[[],[['text','keep']]],after:[[['text','hello']], [['text','keep']]]},names);assert.equal(rows.length,1);assert.equal(rows[0].title,'Macro 1');assert.match(rows[0].after,/hello/);assert.doesNotMatch(rows[0].after,/\[\[/);});
test('Mac action preview keeps default and app exceptions distinct',()=>{const rows=changeRows({region:'Mac action · key:0:0',before:null,after:{default:{kind:'openApp',parameters:{bundleID:'com.apple.TextEdit'}},overrides:{'com.openai.codex':{kind:'none',parameters:{}}}}},names);assert.match(rows[0].after,/TextEdit/);assert.match(rows[0].after,/ChatGPT: Do nothing/);});
test('advanced settings use Mac names without changing source schema',()=>{assert.equal(settingLabel({qsid:21,bit:2,title:'Swap Left Alt and GUI'}),'Swap left Option and Command');});
test('friendly key entry roundtrips without guessing ambiguous labels',async()=>{const {parseKeyChoice}=await import('../../ui/copy.mjs');const catalog=[{code:'KC_A',label:'A'},{code:'KC_B',label:'B'},{code:'CUSTOM_1',label:'Same'},{code:'CUSTOM_2',label:'Same'}];assert.equal(parseKeyChoice('B','KC_A',names,catalog),'KC_B');assert.equal(parseKeyChoice('Same','KC_A',names,catalog),'Same');assert.equal(parseKeyChoice('Same (CUSTOM_2)','KC_A',names,catalog),'CUSTOM_2');assert.equal(parseKeyChoice('Switch to Dota','TO(1)',names,catalog),'TO(1)');});
test('common Vial codes and app shortcuts have readable names',async()=>{const {presetAction,presetForAction}=await import('../../ui/app-shortcuts.mjs');assert.equal(keyName('KC_BSPACE'),'Backspace');assert.equal(keyName('KC_MINUS'),'Minus');const chosen=presetAction('claude.new-chat');assert.equal(presetForAction(chosen)?.name,'New chat');const rows=changeRows({region:'Mac action · key:0:0',before:null,after:{default:chosen,overrides:{}}},names);assert.match(rows[0].after,/Claude: New chat/);});
test('recorded keyboard shortcuts display as familiar keys',()=>{assert.equal(keyName('LCTL(LALT(KC_B))'),'Control + Option + B');assert.equal(keyName('LCA(KC_B)'),'Control + Option + B');});
test('device readback codes retain readable shortcut names',()=>{
 const catalog=[{code:'KC_B',label:'B',value:5}];
 assert.equal(keyName('0xc05',[],catalog),'Option + Command + B');
 assert.equal(keyName(0xc05,[],catalog),'Option + Command + B');
 assert.equal(keyName('0x1405',[],catalog),'Right Option + B');
 assert.equal(keyName('HYPR(KC_B)',[],catalog),'Control + Shift + Option + Command + B');
 assert.equal(keyName('0xffff',[],catalog),'Key code 65535');
});
test('combination names follow recorded keys and results, including empty slots',()=>{
 const entry=['KC_NO','KC_NO','KC_NO','KC_NO','LCTL(LALT(KC_B))'];
 assert.equal(combinationName(entry,0),'Control + Option + B');
 entry[0]='KC_A';entry[1]='KC_B';
 assert.equal(combinationName(entry,0),'A + B → Control + Option + B');
 entry[4]='KC_NO';assert.equal(combinationName(entry,0),'A + B');
 assert.equal(combinationName(['KC_NO',0,null,'KC_NO','KC_NO'],2),'Empty combination 3');
});
