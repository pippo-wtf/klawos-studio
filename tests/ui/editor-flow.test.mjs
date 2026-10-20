import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {recordedChord,recordingComplete,keyboardShortcutCode} from '../../ui/shortcut-recording.mjs';
import {createDraft,setControl,getControl,changes} from '../../ui/state.mjs';
import * as layerActions from '../../ui/layer-actions.mjs';
const source=fs.readFileSync(new URL('../../ui/app.js',import.meta.url),'utf8');
const slice=(from,to)=>source.slice(source.indexOf(from),source.indexOf(to));
const tick=async()=>{for(let i=0;i<30;i++)await Promise.resolve()};
const snapshot=()=>({identity:{uid:'test'},hardware:{layout:[[Array(4).fill('KC_A')]],encoder_layout:[[[]]]},lighting:{}});
async function recorder(send,capture){
 const controls=[],notices=[];
 let createShortcutRecording;
 try {({createShortcutRecording}=await import('../../ui/recording-session.mjs'))}catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error}
 const c={draft:createDraft(snapshot()),layer:0,selected:'key:0:0',tab:'Keymap',editGeneration:0,writing:false,reviewedDraft:null,recordingMacro:false,changes,stopChord:null,createShortcutRecording,request:send,recordingComplete,recordedChord,keyboardShortcutCode,setTimeout,clearTimeout,Date,actionRow:parent=>parent,message:(...x)=>notices.push(x),$:()=>({disabled:false}),button:(text,click)=>{const b={textContent:text,disabled:false,hidden:false,click};controls.push(b);return b},capture};
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
 const c={draft,editGeneration:0,writing:false,reviewedDraft:null,recordingMacro:false,stopChord:null,structuredClone,changes,message:()=>{},render:()=>{},request:async op=>op==='syncStatus'?{status:'Settings are synced with iCloud.',layerNames:[]}:op==='helperConfiguration'?pending:{}};
 vm.createContext(c);vm.runInContext(slice('async function refreshSyncedSettings(', 'async function connect('),c);
 const task=c.refreshSyncedSettings();await tick();setControl(c.draft,0,'key:0:0','LCTL(LALT(KC_B))');c.editGeneration++;complete(installed);await task;
 assert.equal(c.draft.profiles['key:0:0'],undefined);
});
test('save locks editing controls until the result is installed',async()=>{
 const draft=createDraft(snapshot());setControl(draft,0,'key:0:0','KC_B');
 let complete;const pending=new Promise(resolve=>complete=resolve),controls=[{disabled:false},{disabled:true}],elements=new Map();
 const c={draft,writing:false,reviewedDraft:null,recordingMacro:false,editGeneration:0,editingLock:null,structuredClone,createDraft,changes,stopChord:null,message:()=>{},render:()=>{},document:{querySelectorAll:()=>controls},$:id=>{if(!elements.has(id))elements.set(id,{disabled:false,close(){}});return elements.get(id)},request:async op=>op==='apply'?pending:{}};
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
 const c={draft,writing:false,reviewedDraft:null,recordingMacro:true,editGeneration:0,editingLock:null,structuredClone,createDraft,changes,stopChord:null,message:()=>{},render:()=>{},document:{querySelectorAll:()=>[]},$:()=>({disabled:false,close(){}}),request:async op=>{if(op==='apply')writes++;return {snapshot:snapshot()}}};
 vm.createContext(c);vm.runInContext(slice('function lockEditing(', 'for(const name of tabs)'),c);await c.apply();assert.equal(writes,0);
});
test('save preview waits for the macro recorder to finish in the UI',async()=>{
 let requested=false;
 const c={draft:createDraft(snapshot()),writing:false,recordingMacro:true,stopChord:null,autosave:null,clearTimeout,structuredClone,message:()=>{},request:async()=>{requested=true;return {changes:[]}},$:()=>({replaceChildren(){},showModal(){}})};
 vm.createContext(c);vm.runInContext(slice('async function preview(', 'function lockEditing('),c);
 await assert.rejects(()=>c.preview(),/recording/);assert.equal(requested,false);
});

test('app inspector hides hardware controls and updates immediately when the action changes',async()=>{
 const {buttonBinding,buttonLabel,keyName,appName}=await import('../../ui/copy.mjs');
 const bindings=await import('../../ui/binding-actions.mjs');const presets=await import('../../ui/app-shortcuts.mjs');
 const draft=createDraft(snapshot());draft.profiles={'key:0:0':{default:{kind:'openApp',parameters:{bundleID:'com.openai.codex'}},overrides:{}}};
 draft.hardware.layout[0][0][0]='KC_F13';const before=structuredClone(draft);
 const element=(tag,text='')=>{let value;return {tag,textContent:text,children:[],append(...children){this.children.push(...children)},replaceChildren(...children){this.children=children},setAttribute(name,value){this[name]=value},get value(){return value??this.children.find(n=>n.tag==='option')?.value??''},set value(next){value=String(next)}}};
 const aside=element('aside'),workspace={classList:{toggle(){}}};let editor,updates=0;
 const c={draft,layer:0,selected:'key:0:0',tab:'Keymap',stopChord:null,buttonBinding,buttonLabel,getControl,setControl,viewer:null,catalog:{keys:[]},layerNames:['Work'],layerName:()=> 'Work',
  ...bindings,...presets,...layerActions,keyName,appName,structuredClone,request:async op=>op==='actionCatalog'?{apps:[{name:'Codex',bundleID:'com.openai.codex'}],keys:[{keyCode:11,name:'B'}]}:{},node:element,actionRow:parent=>parent,$:()=>aside,document:{querySelector:()=>workspace,createElement:element},controlLabel:()=> 'Key 1',displayKey:x=>x,message(){},changed(){},updateControlLabels(){updates++},
  keyInput:value=>element('input',value),label:(text,field,parent)=>parent.append(element('label',text),field),
  recordShortcut:(parent,title)=>parent.append(element('button',title)),button:(title,action,parent)=>parent.append(element('button',title))};
 vm.createContext(c);vm.runInContext(fs.readFileSync(new URL('../../ui/host-actions.js',import.meta.url),'utf8').replace(/^import .*;\n/gm,'').replace(/export /g,''),c);const realEditor=c.actionEditor;c.actionEditor=(parent,options)=>{editor=options;return realEditor(parent,options)};vm.runInContext(slice('function displayControl(', 'function recordShortcut('),c);c.renderInspector();await tick();
 const visible=()=>{const texts=[];function walk(n){texts.push(n.textContent);n.children.forEach(walk)}walk(aside);return texts.join('\n')};
 assert.match(visible(),/Open Codex/);assert.doesNotMatch(visible(),/F13|Key or shortcut|Record shortcut|Test keyboard output/);
 assert.deepEqual(draft,before);
 const editorInstance=editor;const labels=()=>{const all=[];function walk(n){all.push(n);n.children.forEach(walk)}walk(aside);return all};const action=labels().find(n=>n.tag==='label'&&n.children.some(c=>c.textContent==='Action')).children.find(n=>n.tag==='select');action.value='keyboard';action.onchange();await tick();assert.match(visible(),/Key or shortcut/);assert.match(visible(),/Record shortcut/);assert.equal(editor,editorInstance);
 const choose=labels().find(n=>n.tag==='label'&&n.children.some(c=>c.textContent==='Action')).children.find(n=>n.tag==='select');choose.value='openApp';choose.onchange();await tick();assert.doesNotMatch(visible(),/F13|Key or shortcut|Record shortcut/);assert.ok(updates>=1);
});
test('save preview locks editing until its exact reviewed snapshot is ready',async()=>{
 const draft=createDraft(snapshot());setControl(draft,0,'key:0:0','KC_B');let complete;const pending=new Promise(resolve=>complete=resolve),control={disabled:false},elements=new Map();
 const c={draft,writing:false,reviewedDraft:null,recordingMacro:false,stopChord:null,editingLock:null,autosave:null,clearTimeout,structuredClone,message(){},render(){},reviewRows:()=>[],catalog:{keys:[],apps:[]},document:{querySelectorAll:()=>[control]},$:id=>{if(!elements.has(id))elements.set(id,{disabled:false,replaceChildren(){},showModal(){}});return elements.get(id)},request:async op=>op==='preview'?pending:{}};
 vm.createContext(c);vm.runInContext(slice('async function preview(', 'async function apply('),c);const task=c.preview();await tick();assert.equal(control.disabled,true);assert.equal(c.writing,true);complete({changes:[]});await task;assert.equal(control.disabled,false);assert.deepEqual(c.reviewedDraft,draft);assert.equal(c.writing,false);
});

test('apply refuses a changed draft after the review without any keyboard writes',async()=>{
 const draft=createDraft(snapshot()),reviewedDraft=structuredClone(draft);setControl(draft,0,'key:0:0','KC_C');let writes=0,notice='';
 const c={draft,reviewedDraft,writing:false,recordingMacro:false,stopChord:null,structuredClone,message:text=>notice=text,$:()=>({close(){}}),request:async()=>writes++};
 vm.createContext(c);vm.runInContext(slice('async function apply(', 'for(const name of tabs)'),c);await c.apply();assert.equal(writes,0);assert.match(notice,/review them again/);
});
