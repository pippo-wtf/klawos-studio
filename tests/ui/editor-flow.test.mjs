import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {recordedChord,recordingComplete,keyboardShortcutCode} from '../../ui/shortcut-recording.mjs';
import {createDraft,setControl,changes} from '../../ui/state.mjs';
const source=fs.readFileSync(new URL('../../ui/app.js',import.meta.url),'utf8');
const slice=(from,to)=>source.slice(source.indexOf(from),source.indexOf(to));
const tick=async()=>{for(let i=0;i<30;i++)await Promise.resolve()};
const snapshot=()=>({identity:{uid:'test'},hardware:{layout:[[Array(4).fill('KC_A')]],encoder_layout:[[[]]]},lighting:{}});
async function recorder(send,capture){
 const controls=[],notices=[];
 let createShortcutRecording;
 try {({createShortcutRecording}=await import('../../ui/recording-session.mjs'))}catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error}
 const c={draft:createDraft(snapshot()),layer:0,selected:'key:0:0',tab:'Keymap',editGeneration:0,writing:false,recordingMacro:false,changes,stopChord:null,createShortcutRecording,request:send,recordingComplete,recordedChord,keyboardShortcutCode,setTimeout,clearTimeout,Date,message:(...x)=>notices.push(x),$:()=>({disabled:false}),button:(text,click)=>{const b={textContent:text,disabled:false,hidden:false,click};controls.push(b);return b},capture};
 vm.createContext(c);vm.runInContext(slice('function recordShortcut(', 'function updateControlLabels(')+';recordShortcut({},"Record shortcut",5,capture)',c);
 return {c,controls,notices};
}
test('invalid recording restores controls and permits retry',async()=>{
 const r=await recorder(async op=>op==='recordingStatus'?{active:true,events:[['down','KC_A'],['down','KC_B'],['up','KC_A']]}:{},keys=>keyboardShortcutCode(keys));
 await r.controls[0].click();await tick();
 assert.equal(r.controls[0].disabled,false);assert.equal(r.controls[1].hidden,true);assert.equal(r.c.stopChord,null);
});
test('native cancellation never assigns cleanup releases',async()=>{
 let accepted=false;
 const r=await recorder(async op=>op==='recordingStatus'?{active:false,events:[['down','KC_LCTL'],['down','KC_B'],['up','KC_B']]}:{},()=>accepted=true);
 await r.controls[0].click();await tick();assert.equal(accepted,false);
});
test('selection during recording start cancels the pending target',async()=>{
 let releaseStart,accepted=false;const pending=new Promise(resolve=>releaseStart=resolve);
 const r=await recorder(async op=>op==='recordingStart'?pending:op==='recordingStatus'?{active:true,events:[['down','KC_B'],['up','KC_B']]}:{},()=>accepted=true);
 const task=r.controls[0].click();r.c.stopChord?.();r.c.selected='key:0:1';releaseStart({});await task;await tick();
 assert.equal(accepted,false);assert.equal(r.controls[0].disabled,false);
});
test('sync response cannot reinstate a profile removed by a newer key edit',async()=>{
 const draft=createDraft(snapshot()),installed={'key:0:0':{default:{kind:'openApp',parameters:{bundleID:'com.apple.TextEdit'}},overrides:{}}};
 draft.profiles=structuredClone(installed);draft.baseProfiles=structuredClone(installed);
 let complete;const pending=new Promise(resolve=>complete=resolve);
 const c={draft,editGeneration:0,writing:false,recordingMacro:false,stopChord:null,structuredClone,changes,message:()=>{},render:()=>{},request:async op=>op==='syncStatus'?{status:'Settings are synced with iCloud.',layerNames:[]}:op==='helperConfiguration'?pending:{}};
 vm.createContext(c);vm.runInContext(slice('async function refreshSyncedSettings(', 'async function connect('),c);
 const task=c.refreshSyncedSettings();await tick();setControl(c.draft,0,'key:0:0','LCTL(LALT(KC_B))');c.editGeneration++;complete(installed);await task;
 assert.equal(c.draft.profiles['key:0:0'],undefined);
});
test('save locks editing controls until the result is installed',async()=>{
 const draft=createDraft(snapshot());setControl(draft,0,'key:0:0','KC_B');
 let complete;const pending=new Promise(resolve=>complete=resolve),controls=[{disabled:false},{disabled:true}],elements=new Map();
 const c={draft,writing:false,recordingMacro:false,editGeneration:0,editingLock:null,structuredClone,createDraft,changes,stopChord:null,message:()=>{},render:()=>{},document:{querySelectorAll:()=>controls},$:id=>{if(!elements.has(id))elements.set(id,{disabled:false,close(){}});return elements.get(id)},request:async op=>op==='apply'?pending:{}};
 vm.createContext(c);
 if(source.includes('function lockEditing('))vm.runInContext(slice('function lockEditing(', 'async function apply('),c);
 vm.runInContext(slice('async function apply(', 'for(const name of tabs)'),c);
 const task=c.apply();await tick();assert.equal(controls[0].disabled,true);complete({snapshot:snapshot()});await task;
 assert.equal(controls[0].disabled,false);assert.equal(controls[1].disabled,true);
});
test('successful explicit recording assigns Shift-only shortcut once',async()=>{
 const assigned=[];let stops=0;
 const r=await recorder(async op=>{if(op==='recordingStop')stops++;return op==='recordingStatus'?{active:true,events:[['down','KC_LSFT'],['down','KC_B'],['up','KC_B']]}:{}},keys=>assigned.push(keyboardShortcutCode(keys)));
 await r.controls[0].click();await tick();assert.deepEqual(assigned,['LSFT(KC_B)']);assert.equal(stops,1);assert.equal(r.controls[0].disabled,false);
});
test('a failed native start restores recording controls without assignment',async()=>{
 let assigned=false;
 const r=await recorder(async op=>{if(op==='recordingStart')throw Error('connection stopped');return {}},()=>assigned=true);
 await r.controls[0].click();await tick();assert.equal(assigned,false);assert.equal(r.c.stopChord,null);assert.equal(r.controls[0].disabled,false);assert.equal(r.controls[1].hidden,true);
});
test('key-name entry permits text selection without changing the button action',()=>{
 let assigned=false;const listeners={};
 const c={draft:{},layerNames:[],catalog:{keys:[]},displayKey:x=>x,parseKeyChoice:x=>x,layerName:()=>'',message:()=>{},directChord:()=>['KC_LGUI','KC_A'],keyboardShortcutCode,
 input:(value,type,change)=>({value,setAttribute(){},addEventListener(name,handler){listeners[name]=handler},change}),change:()=>assigned=true};
 vm.createContext(c);vm.runInContext(slice('function keyInput(','function changed()')+';var field=keyInput("B",change)',c);
 listeners.keydown?.({ctrlKey:false,altKey:false,metaKey:true,code:'KeyA',preventDefault(){},stopPropagation(){}});
 assert.equal(assigned,false);
});
test('pending macro completion prevents saving until its recorded steps are captured',async()=>{
 const draft=createDraft(snapshot());setControl(draft,0,'key:0:0','KC_B');let writes=0;
 const c={draft,writing:false,recordingMacro:true,editGeneration:0,editingLock:null,structuredClone,createDraft,changes,stopChord:null,message:()=>{},render:()=>{},document:{querySelectorAll:()=>[]},$:()=>({disabled:false,close(){}}),request:async op=>{if(op==='apply')writes++;return {snapshot:snapshot()}}};
 vm.createContext(c);vm.runInContext(slice('function lockEditing(', 'for(const name of tabs)'),c);await c.apply();assert.equal(writes,0);
});
test('save preview waits for the macro recorder to finish in the UI',async()=>{
 let requested=false;
 const c={draft:createDraft(snapshot()),recordingMacro:true,stopChord:null,autosave:null,clearTimeout,structuredClone,message:()=>{},request:async()=>{requested=true;return {changes:[]}},$:()=>({replaceChildren(){},showModal(){}})};
 vm.createContext(c);vm.runInContext(slice('async function preview(', 'function lockEditing('),c);
 await assert.rejects(()=>c.preview(),/recording/);assert.equal(requested,false);
});
