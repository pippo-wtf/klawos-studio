import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createDraft,changes,layerNames,layerName,getControl} from '../../ui/state.mjs';
import {keyName,buttonLabel,controlName} from '../../ui/copy.mjs';

const snapshot=()=>({identity:{uid:'names'},capabilities:{layers:6},hardware:{layout:Array.from({length:6},()=>Array.from({length:4},()=>['KC_A','KC_A','KC_A','TO(0)'])),encoder_layout:Array.from({length:6},()=>[['TO(0)','TO(1)']]),settings:{}},lighting:{}});
const source=fs.readFileSync(new URL('../../ui/app.js',import.meta.url),'utf8');
const section=(start,end)=>source.slice(source.indexOf(start),source.indexOf(end));
const tick=async()=>{for(let i=0;i<20;i++)await Promise.resolve()};
function element(tag){return {tag,children:[],dataset:{},textContent:'',value:'',disabled:false,classList:{toggle(){}},setAttribute(name,value){if(name.startsWith('data-'))this.dataset[name.slice(5).replace(/-([a-z])/g,(_,c)=>c.toUpperCase())]=value;else this[name]=value},append(...children){this.children.push(...children)},replaceChildren(...children){this.children=children}};}
function descendants(root){return [root,...root.children.flatMap(descendants)];}
function editor(send=async()=>({})){const elements=new Map(),timers=new Map(),requests=[];let timer=0,content;
 const document={activeElement:null,createElement:element,createDocumentFragment:()=>element('fragment'),querySelectorAll:selector=>selector==='[data-control]'?[knob]:[]};
 const get=id=>{const match=content&&descendants(content).find(n=>n.id===id);if(match)return match;if(!elements.has(id))elements.set(id,element('div'));return elements.get(id)};
 get('layer').options=Array.from({length:6},(_,i)=>({value:String(i),textContent:''}));
 const knob=element('button');knob.dataset.control='key:0:3';
 const c={draft:createDraft(snapshot()),layer:0,tab:'QMK settings',selected:'key:0:3',catalog:{keys:[{code:'TO(0)'},{code:'TO(1)'}],settings:{tabs:[]}},layerNames,layerName,changes,getControl,keyName,buttonLabel,controlName,editGeneration:0,draftSavePending:false,draftSaveFailed:false,writing:false,stopChord:null,recordingMacro:false,autosave:null,structuredClone,document,$:get,message(){},render(){},renderInspector(){},setTimeout:fn=>{timers.set(++timer,fn);return timer},clearTimeout:id=>timers.delete(id),request:async(op,value)=>{requests.push({op,value});return send(op,value)}};
 vm.createContext(c);
 vm.runInContext(section('function node(', 'function keyInput(')+section('function changed(', 'function select(')+section('function controlLabel(', 'function renderInspector(')+section('function updateControlLabels(', 'function render(')+section('function renderSettings(', 'async function connect('),c);
 content=element('section');c.renderSettings(content);
 return {c,content,knob,get,requests,fields:()=>descendants(content).filter(n=>n.tag==='input'),async save(){const [id,fn]=timers.entries().next().value;timers.delete(id);await fn();await tick();}};
}

test('unnamed and invalid metadata entries display neutral names on every layer',()=>{
 const d=createDraft(snapshot());assert.deepEqual(d.hardware.layout.map((_,i)=>layerName(d,i)),['Layer 1','Layer 2','Layer 3','Layer 4','Layer 5','Layer 6']);
 d.projectDocument={metadata:{layerNames:[null,'',23,'   ']}};assert.deepEqual(d.hardware.layout.map((_,i)=>layerName(d,i)),['Layer 1','Layer 2','Layer 3','Layer 4','Layer 5','Layer 6']);
});
test('explicit names apply at every index and are trimmed and bounded without changing assignments',()=>{
 const d=createDraft(snapshot()),before=structuredClone(d.hardware);d.projectDocument={metadata:{layerNames:[' Editing ','Games','Drawing','Other','x'.repeat(81),' Last ']}};
 assert.deepEqual(d.hardware.layout.map((_,i)=>layerName(d,i)),['Editing','Games','Drawing','Other','x'.repeat(80),'Last']);assert.deepEqual(d.hardware,before);
});
test('keyboard settings expose six named fields and renaming immediately updates shared labels without replacing the input',async()=>{
 const e=editor(),fields=e.fields(),before=structuredClone(e.c.draft.hardware);
 assert.equal(fields.length,6);assert.deepEqual(descendants(e.content).filter(n=>n.tag==='label').map(n=>n.children[0].textContent),['Layer 1','Layer 2','Layer 3','Layer 4','Layer 5','Layer 6']);
 const first=fields[0];first.value=' Editing ';first.onchange();
 assert.equal(first.value,'Editing');assert.equal(e.fields()[0],first);assert.equal(e.get('layer').options[0].textContent,'Editing');assert.equal(e.get('layer-names').textContent,'Editing · Layer 2 · Layer 3 · Layer 4 · Layer 5 · Layer 6');
 assert.match(e.knob.textContent,/Switch to Editing/);assert.equal(e.c.displayKey('TO(0)'),'Switch to Editing');assert.ok(descendants(e.get('keycodes')).some(n=>n.value==='Switch to Editing'));
 assert.equal(changes(e.c.draft).length,0);assert.deepEqual(e.c.draft.hardware,before);assert.equal(e.get('apply').disabled,true);
 await e.save();assert.equal(e.requests[0].op,'saveDraft');assert.equal(e.requests[0].value.projectDocument.metadata.layerNames[0],'Editing');assert.equal(e.get('draft-status').textContent,'Saved on this Mac');
});
test('every layer rename normalizes blank and oversized input before saving',()=>{
 const e=editor(),fields=e.fields();assert.equal(fields.length,6);
 for(let i=0;i<fields.length;i++){fields[i].value=' Name '+i+' ';fields[i].onchange();assert.equal(layerName(e.c.draft,i),'Name '+i)}
 fields[1].value='Design\0';fields[1].onchange();assert.equal(e.c.draft.projectDocument.metadata.layerNames[1],'Design');
 fields[0].value=' ';fields[0].onchange();fields[5].value='x'.repeat(81);fields[5].onchange();
 assert.equal(e.c.draft.projectDocument.metadata.layerNames[0],'Layer 1');assert.equal(fields[0].value,'Layer 1');assert.equal(e.c.draft.projectDocument.metadata.layerNames[5].length,80);
});
const remote=async op=>op==='syncStatus'?{status:'Settings are synced with iCloud.',layerNames:['Remote','Two','Three','Four','Five','Six']}:op==='helperConfiguration'?{}:{};
test('background sync leaves a pending name save intact before autosave starts',async()=>{
 const e=editor(remote);e.c.draft.projectDocument={metadata:{layerNames:['Local']}};e.c.changed();await e.c.refreshSyncedSettings();assert.equal(e.c.draft.projectDocument.metadata.layerNames[0],'Local');
});
test('failed name saves remain protected from background sync and a successful retry permits sync',async()=>{
 let failed=true;const e=editor(async(op,value)=>{if(op==='saveDraft'&&failed&&value.projectDocument?.metadata?.layerNames[0]==='Local')throw Error('disk full');return remote(op)});
 e.c.draft.projectDocument={metadata:{layerNames:['Local']}};e.c.changed();await e.save();await e.c.refreshSyncedSettings();assert.equal(e.c.draft.projectDocument.metadata.layerNames[0],'Local');
 failed=false;e.c.changed();await e.save();await e.c.refreshSyncedSettings();assert.equal(e.c.draft.projectDocument.metadata.layerNames[0],'Remote');
});
test('sync leaves a focused layer name field and its uncommitted text intact',async()=>{
 const e=editor(remote),field=element('input');field.dataset.layerName='0';field.value='Still typing';e.c.document.activeElement=field;
 await e.c.refreshSyncedSettings();assert.equal(e.c.draft.projectDocument,undefined);assert.equal(field.value,'Still typing');
});
test('a stale autosave success does not release protection for a newer unsaved rename',async()=>{
 let finish;const pending=new Promise(resolve=>finish=resolve);const e=editor(async op=>op==='saveDraft'?pending:remote(op));
 e.c.draft.projectDocument={metadata:{layerNames:['First']}};e.c.changed();const saving=e.save();await tick();e.c.draft.projectDocument.metadata.layerNames[0]='Second';e.c.changed();finish({});await saving;
 await e.c.refreshSyncedSettings();assert.equal(e.c.draft.projectDocument.metadata.layerNames[0],'Second');assert.match(e.get('draft-status').textContent,/Saving/);
});
test('renaming a later layer fills partial saved metadata with valid default names',async()=>{
 const e=editor();e.c.draft.projectDocument={metadata:{layerNames:['Personal']}};const last=e.fields()[5];last.value='Final';last.onchange();await e.save();
 assert.deepEqual(Array.from(e.requests[0].value.projectDocument.metadata.layerNames),['Personal','Layer 2','Layer 3','Layer 4','Layer 5','Final']);
});

test('failed name autosave offers an explicit retry without changing names or keyboard assignments',async()=>{
 let failed=true;const e=editor(async op=>{if(op==='saveDraft'&&failed)throw Error('disk full');return {}});
 const field=e.fields()[0];field.value='Editing';field.onchange();await e.save();
 const retry=descendants(e.content).find(n=>n.tag==='button'&&n.textContent==='Retry save');assert.ok(retry,'The name card offers a retry action');assert.equal(retry.hidden,false);
 const before=structuredClone(e.c.draft);failed=false;await retry.onclick();await e.save();
 assert.deepEqual(structuredClone(e.c.draft),before);assert.equal(retry.hidden,true);assert.equal(e.get('draft-status').textContent,'Saved on this Mac');assert.equal(e.requests.filter(r=>r.op==='saveDraft').length,2);assert.equal(e.requests.some(r=>r.op==='apply'),false);
});
