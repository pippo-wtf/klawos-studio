import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {layerActionOptions,selectedLayerAction,parseLayerAction} from '../../ui/layer-actions.mjs';
import {createDraft,setControl,getControl,changes,controlIDs,layerNames,layerName} from '../../ui/state.mjs';
import {setKeyboardBinding} from '../../ui/binding-actions.mjs';
import {keyName,buttonBinding} from '../../ui/copy.mjs';
const names=['Work','Dota','Wardogs','Drawing','Layer 5','Layer 6'];
const catalog=['TO','MO','TG','DF'].flatMap((action,i)=>names.map((_,layer)=>({code:`${action}(${layer})`,value:0x5000+i*256+layer})));

test('layer choices use named layers and only catalog-supported codes',()=>{
 const options=layerActionOptions(names,catalog);
 assert.equal(options.length,24);
 for(const [action,title] of [['TO','Switch to'],['MO','Hold'],['TG','Toggle'],['DF','Set default layer to']])for(let layer=0;layer<names.length;layer++)assert.deepEqual(options.find(o=>o.code===`${action}(${layer})`),{code:`${action}(${layer})`,label:`${title} ${names[layer]}`});
 assert.deepEqual(layerActionOptions(names,[]),[]);
 assert.equal(layerActionOptions(names,catalog.filter(k=>!k.code.startsWith('DF'))).length,18);
 assert.equal(layerActionOptions(names.slice(0,2),catalog).length,8);
});
test('encoder choices omit hold while retaining switch, toggle and default',()=>{
 const options=layerActionOptions(names,catalog,true);
 assert.equal(options.length,18);assert.ok(options.every(o=>!o.code.startsWith('MO')));
});
test('existing manual cycle and numeric readback preselect the exact assignment',()=>{
 const options=layerActionOptions(names,catalog),before=structuredClone(options);
 for(const code of ['TO(1)','TO(2)','TO(0)']){
  const entry=catalog.find(k=>k.code===code);
  for(const value of [code,entry.value,'0x'+entry.value.toString(16)])assert.equal(selectedLayerAction(value,options,catalog),code);
 }
 for(const value of ['KC_A',null,65535])assert.equal(selectedLayerAction(value,options,catalog),'');
 assert.deepEqual(options,before);
});
test('choices parse through the catalog and reject unsupported actions and layers',()=>{
 for(const entry of catalog)assert.equal(parseLayerAction(entry.code,'KC_A',names,catalog),entry.code);
 for(const code of ['','TO(6)','TO(-1)','PDF(1)','KC_A'])assert.throws(()=>parseLayerAction(code,'KC_A',names,catalog),/layer action/i);
 assert.throws(()=>parseLayerAction('DF(1)','KC_A',names,catalog.filter(k=>!k.code.startsWith('DF'))),/layer action/i);
 assert.throws(()=>parseLayerAction('MO(1)','KC_A',names,catalog,true),/layer action/i);
});
test('toggle and default actions have readable summaries including numeric readback',()=>{
 for(const [code,title] of [['TG(3)','Toggle Drawing'],['DF(3)','Set default layer to Drawing']]){
  assert.equal(keyName(code,names,catalog),title);
  assert.equal(keyName(catalog.find(k=>k.code===code).value,names,catalog),title);
 }
});

const source=fs.readFileSync(new URL('../../ui/app.js',import.meta.url),'utf8');
function inspector(layer,id,value){
 const draft=createDraft({hardware:{layout:Array.from({length:6},()=>Array.from({length:4},()=>Array(4).fill('KC_A'))),encoder_layout:Array.from({length:6},()=>[['KC_WH_U','KC_WH_D']])},lighting:{}});
 draft.projectDocument={metadata:{layerNames:names}};setControl(draft,layer,id,value);
 const element=(tag,textContent='')=>({tag,textContent,children:[],append(...items){this.children.push(...items)},replaceChildren(...items){this.children=items},setAttribute(){}});
 const aside=element('aside'),notices=[];
 const c={draft,layer,selected:id,tab:'Keymap',catalog:{keys:catalog},layerNames,layerName,layerActionOptions,selectedLayerAction,parseLayerAction,keyName,buttonBinding,getControl,setControl,
  node:element,$:()=>aside,document:{querySelector:()=>({classList:{toggle(){}}})},controlLabel:x=>x,displayControl:()=>keyName(getControl(draft,layer,id),names,catalog),displayKey:x=>keyName(x,names,catalog),
  actionEditor:(parent,options)=>options.keyboardEditor(parent,getControl(draft,layer,id),code=>{setControl(draft,layer,id,code);options.changed()}),
  label:(title,field,parent)=>{parent.append(element('span',title),field);return field},keyInput:value=>element('input',value),recordShortcut(){},actionRow:parent=>parent,button(){},changed(){},updateControlLabels(){},message:text=>notices.push(text),stopChord:null};
 vm.createContext(c);vm.runInContext(source.slice(source.indexOf('function renderInspector('),source.indexOf('function recordShortcut(')),c);c.renderInspector();
 const all=()=>{const nodes=[];function walk(n){nodes.push(n);n.children.forEach(walk)}walk(aside);return nodes};
 return {draft,all,notices,picker:()=>all().find(n=>n.tag==='select')};
}
test('every key and encoder on every layer gets a draft-only layer picker',()=>{
 for(let layer=0;layer<6;layer++)for(const id of controlIDs()){
  const p=inspector(layer,id,'KC_A'),before=structuredClone(p.draft);
  assert.deepEqual(p.draft,before);assert.equal(p.picker().value,'');
  p.picker().value='TG(3)';p.picker().onchange();
  assert.equal(getControl(p.draft,layer,id),'TG(3)');assert.deepEqual(p.draft.base,before.base);assert.equal(changes(p.draft).length,1);
  assert.ok(p.all().some(n=>n.textContent===`Editing layer: ${names[layer]}. The keyboard stays on its own active layer.`));
 }
});
test('knob cycle is preselected without edits and its warning stays visible in the disclosure',()=>{
 for(const [layer,code] of ['TO(1)','TO(2)','TO(0)'].entries()){
  const p=inspector(layer,'key:0:3',code),before=structuredClone(p.draft);
  assert.equal(p.picker().value,code);assert.deepEqual(p.draft,before);
  assert.ok(p.all().some(n=>n.textContent==='Changing this assignment replaces the mode switch on this layer.'));
  assert.equal(buttonBinding(p.draft,layer,'key:0:3'),undefined);
 }
});
test('invalid picker choices report an error and leave the draft unchanged',()=>{
 const p=inspector(2,'key:1:0','KC_A'),before=structuredClone(p.draft);
 p.picker().value='TO(99)';p.picker().onchange();assert.deepEqual(p.draft,before);assert.match(p.notices[0],/layer action/i);
});
test('layer actions replace a Work Mac action only through the existing keyboard binding guards',()=>{
 const {draft}=inspector(0,'key:0:0','KC_A'),action={kind:'openApp',parameters:{bundleID:'com.openai.codex'}};
 draft.profiles['key:0:0']={default:action,overrides:{'example.app':action}};const before=structuredClone(draft);
 assert.throws(()=>setKeyboardBinding(draft,'key:0:0','default','TO(1)',[],catalog),/supported key or shortcut/);assert.deepEqual(draft,before);
 draft.profiles['key:0:0'].overrides={};
 setKeyboardBinding(draft,'key:0:0','default',parseLayerAction('TO(1)','KC_A',names,catalog),[],catalog);
 assert.equal(getControl(draft,0,'key:0:0'),'TO(1)');assert.equal(draft.profiles['key:0:0'],undefined);assert.deepEqual(draft.base,before.base);
});
