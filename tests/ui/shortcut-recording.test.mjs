import test from 'node:test';
import assert from 'node:assert/strict';
import {recordedChord,recordingComplete,keyboardShortcutCode,directChord} from '../../ui/shortcut-recording.mjs';

const chord=[['down','KC_LCTL'],['delay',12],['down','KC_LALT'],['down','KC_B'],['up','KC_B'],['up','KC_LALT'],['up','KC_LCTL']];

test('records simultaneous keys and waits for their release',()=>{
 assert.equal(recordingComplete(chord.slice(0,4)),false);
 assert.equal(recordingComplete(chord),true);
 assert.deepEqual(recordedChord(chord),['KC_LCTL','KC_LALT','KC_B']);
});
test('finishes when the main key is released even if modifier release events are missing',()=>{
 const partial=chord.slice(0,5);
 assert.equal(recordingComplete(partial),true);
 assert.deepEqual(recordedChord(partial),['KC_LCTL','KC_LALT','KC_B']);
});
test('modifier releases alone do not end a recording',()=>{
 const modifiersOnly=[['down','KC_LCTL'],['down','KC_LALT'],['up','KC_LALT'],['up','KC_LCTL']];
 assert.equal(recordingComplete(modifiersOnly),false);
 assert.equal(recordingComplete([...modifiersOnly,['down','KC_B'],['up','KC_B']]),true);
 assert.deepEqual(recordedChord([...modifiersOnly,['down','KC_B'],['up','KC_B']]),['KC_LCTL','KC_LALT','KC_B']);
});

test('rejects sequential or oversized key combinations',()=>{
 assert.deepEqual(recordedChord([['down','KC_A'],['up','KC_A'],['down','KC_B'],['up','KC_B']]),['KC_A']);
 assert.throws(()=>recordedChord([['down','KC_A'],['down','KC_B'],['down','KC_C'],['down','KC_D'],['down','KC_E']]),/four/);
});

test('converts a recorded Mac chord into a Vial keyboard shortcut',()=>{
 assert.equal(keyboardShortcutCode(recordedChord(chord)),'LCTL(LALT(KC_B))');
 assert.throws(()=>keyboardShortcutCode(['KC_LCTL','KC_LALT']),/letter or key/);
});
test('reads physical shortcut fields by key position instead of the typed symbol',()=>{
 assert.deepEqual(directChord({code:'KeyB',key:'∫',ctrlKey:true,altKey:true,metaKey:false,shiftKey:false}),['KC_LCTL','KC_LALT','KC_B']);
 assert.deepEqual(directChord({code:'ControlLeft',ctrlKey:true,altKey:false,metaKey:false,shiftKey:false}),[]);
 assert.deepEqual(directChord({code:'Digit3',ctrlKey:false,altKey:false,metaKey:true,shiftKey:true}),['KC_LGUI','KC_LSFT','KC_3']);
});
