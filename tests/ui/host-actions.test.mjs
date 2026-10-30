import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as bindings from '../../ui/binding-actions.mjs';
import {appShortcuts,presetAction,presetForAction} from '../../ui/app-shortcuts.mjs';
import {appName,keyName} from '../../ui/copy.mjs';
const source=fs.readFileSync(new URL('../../ui/host-actions.js',import.meta.url),'utf8').replace(/^import .*;\n/gm,'').replace(/export /g,'');
function element(tag,text=''){
 let value,ownText=text;const node={tag,children:[],className:'',style:{},hidden:false,disabled:false,
  append(...nodes){this.children.push(...nodes)},prepend(...nodes){this.children.unshift(...nodes)},replaceChildren(...nodes){this.children=nodes},setAttribute(name,value){this[name]=value},
  get textContent(){return ownText+this.children.map(n=>n.textContent).join('')},set textContent(text){ownText=text;this.children=[]},
  get value(){return value??this.children.find(n=>n.tag==='option')?.value??''},set value(next){value=String(next)}};return node;
}
const walk=node=>[node,...node.children.flatMap(walk)];
const field=(node,title)=>walk(node).find(n=>n.tag==='label'&&(n.children.some(c=>c.tag==='span'&&c.textContent===title)||n.textContent.startsWith(title)))?.children.find(n=>['select','input'].includes(n.tag));
const tick=async()=>{for(let i=0;i<50;i++)await Promise.resolve()};
async function setup(status={state:'paused',reason:'Studio is in front',configuredInputs:2,permissions:{accessibility:true,inputMonitoring:true}},code='KC_B',setLoginError=null){
 const requests=[],notices=[],keyEditors=[];let changed=0;const timers=[];
 const catalog={apps:[{bundleID:'com.apple.TextEdit',name:'TextEdit'}],keys:[{keyCode:0,name:'A'},{keyCode:11,name:'B'},{keyCode:105,name:'F13'}]};
 const c={...bindings,appShortcuts,presetAction,presetForAction,appName,keyName,structuredClone,document:{createElement:element},window:{dispatchEvent(){}},Event,
  request:async(operation,payload)=>{requests.push({operation,payload});if(operation==='helperSetStartAtLogin'&&setLoginError)throw new Error(setLoginError);return operation==='actionCatalog'?catalog:operation==='helperStatus'?status:{status:'Settings are synced with iCloud.'}},
  setTimeout(fn){timers.push(fn);return timers.length},clearTimeout(){}};
 vm.createContext(c);vm.runInContext(source,c);await tick();
 const parent=element('div'),draft={hardware:{layout:[[[code]]]},base:{hardware:{layout:[[[code]]]}},profiles:{}};
 const options={draft,layer:0,inputID:'key:0:0',keyCatalog:[{code:'KC_B',value:5},{code:'KC_F13',value:104}],changed:()=>changed++,notice:(...args)=>notices.push(args),keyboardEditor(parent,value,commit,options){keyEditors.push({parent,value,commit,options});parent.append(element('input','Keyboard entry'))}};
 return {c,parent,draft,options,requests,notices,keyEditors,timers,changed:()=>changed};
}
async function choose(node,title,value){const control=field(node,title);assert.ok(control,`missing ${title}`);control.value=value;await control.onchange();await tick()}
test('one action model begins with Keyboard, Open app and Other Mac action',async()=>{
 const r=await setup();r.c.actionEditor(r.parent,r.options);await tick();const action=field(r.parent,'Action');
 assert.deepEqual(Array.from(action.children,n=>n.textContent),['Keyboard','Open app','Other Mac action']);assert.equal(r.keyEditors.length,1);assert.equal(r.keyEditors[0].value,'KC_B');
 assert.doesNotMatch(r.parent.textContent,/Do nothing/);for(const label of walk(r.parent).filter(n=>n.tag==='label')){assert.equal(label.className,'field');assert.equal(label.children[0].tag,'span')}
});
test('app exception shows and preserves its keyboard fallback',async()=>{
 const r=await setup();r.c.actionEditor(r.parent,r.options);await tick();await choose(r.parent,'When using','com.anthropic.claudefordesktop');await choose(r.parent,'Action','openApp');
 assert.equal(r.draft.profiles['key:0:0'].default.kind,'shortcut');assert.equal(r.draft.profiles['key:0:0'].default.parameters.keyCode,11);assert.match(r.parent.textContent,/All other apps.*B/);
});
test('return to keyboard requests a choice before touching installed profile and keeps exceptions',async()=>{
 const r=await setup(undefined,'KC_F13');const open={kind:'openApp',parameters:{bundleID:'com.apple.TextEdit'}};r.draft.profiles['key:0:0']={default:open,overrides:{'com.anthropic.claudefordesktop':open}};
 r.c.actionEditor(r.parent,r.options);await tick();await choose(r.parent,'Action','keyboard');assert.equal(r.draft.profiles['key:0:0'].default.kind,'openApp');
 const editor=r.keyEditors.at(-1);assert.equal(editor.value,null);assert.equal(editor.options.pending,true);editor.commit('KC_B');await tick();
 assert.equal(r.draft.profiles['key:0:0'].default.kind,'shortcut');assert.equal(r.draft.profiles['key:0:0'].overrides['com.anthropic.claudefordesktop'].kind,'openApp');assert.equal(r.changed(),1);
});
test('unsupported fallback requires visible explicit choice before any profile mutation',async()=>{
 const r=await setup(undefined,'MO(1)');r.c.actionEditor(r.parent,r.options);await tick();await choose(r.parent,'When using','com.anthropic.claudefordesktop');await choose(r.parent,'Action','openApp');
 assert.deepEqual(r.draft.profiles,{});assert.match(r.parent.textContent,/Choose.*fallback/i);assert.equal(r.changed(),0);
 r.keyEditors.at(-1).commit('KC_B');await tick();assert.equal(r.draft.profiles['key:0:0'].default.parameters.keyCode,11);assert.equal(r.draft.profiles['key:0:0'].overrides['com.anthropic.claudefordesktop'].kind,'openApp');
});
test('paused helper offers one state-aware action and hides completed permission setup',async()=>{
 const r=await setup();const stop=r.c.helperPanel(r.parent,r.options.notice);await tick();
 const buttons=walk(r.parent).filter(n=>n.tag==='button');assert.ok(buttons.find(n=>n.textContent==='Turn off Mac actions'));assert.ok(!buttons.find(n=>/Turn on|Allow Mac access/.test(n.textContent)));
 const troubleshooting=walk(r.parent).find(n=>n.tag==='details'&&n.textContent.includes('Restart Mac actions'));assert.ok(troubleshooting);assert.ok(!troubleshooting.open);assert.match(r.parent.textContent,/switch to another app/i);stop();
});
test('missing permissions show setup and prevent an ineffective start',async()=>{
 const r=await setup({state:'stopped',reason:'Stopped',configuredInputs:2,permissions:{accessibility:false,inputMonitoring:true}});const stop=r.c.helperPanel(r.parent,r.options.notice);await tick();
 const buttons=walk(r.parent).filter(n=>n.tag==='button');assert.ok(buttons.find(n=>n.textContent==='Allow Mac access'));assert.equal(buttons.find(n=>n.textContent==='Turn on Mac actions').disabled,true);stop();
});
test('app-specific keyboard choice also requires and preserves an explicit fallback',async()=>{
 const r=await setup(undefined,'MO(1)');r.c.actionEditor(r.parent,r.options);await tick();await choose(r.parent,'When using','com.anthropic.claudefordesktop');await choose(r.parent,'Action','keyboard');
 r.keyEditors.at(-1).commit('KC_A');await tick();assert.deepEqual(r.draft.profiles,{});assert.match(r.parent.textContent,/This app action has not been added yet/);
 r.keyEditors.at(-1).commit('KC_B');await tick();assert.equal(r.draft.profiles['key:0:0'].default.parameters.keyCode,11);assert.equal(r.draft.profiles['key:0:0'].overrides['com.anthropic.claudefordesktop'].parameters.keyCode,0);
});
test('inheriting after an unresolved action cancels it without changing assignments',async()=>{
 const r=await setup(undefined,'MO(1)');r.c.actionEditor(r.parent,r.options);await tick();await choose(r.parent,'When using','com.anthropic.claudefordesktop');await choose(r.parent,'Action','openApp');await choose(r.parent,'Action','inherit');
 assert.deepEqual(r.draft.profiles,{});assert.ok(!r.parent.textContent.includes('has not been added yet'));
});
test('changing app context or action cancels the pending recording target',async()=>{
 const r=await setup();let cancelled=0;r.options.cancelRecording=()=>cancelled++;r.c.actionEditor(r.parent,r.options);await tick();await choose(r.parent,'When using','com.anthropic.claudefordesktop');assert.equal(cancelled,1);await choose(r.parent,'Action','openApp');assert.equal(cancelled,2);
});
test('Start at login reflects helper preference and sends a per-Mac toggle',async()=>{
 const r=await setup({state:'stopped',reason:'Stopped',configuredInputs:0,startAtLogin:true,permissions:{accessibility:true,inputMonitoring:true}});
 const stop=r.c.helperPanel(r.parent,r.options.notice);await tick();
 const checkbox=field(r.parent,'Start at login');assert.ok(checkbox);assert.equal(checkbox.type,'checkbox');assert.equal(checkbox.checked,true);
 checkbox.checked=false;await checkbox.onchange();await tick();
 const sent=r.requests.find(n=>n.operation==='helperSetStartAtLogin');assert.ok(sent);assert.equal(sent.payload.enabled,false);
 assert.match(r.parent.textContent,/Start KLAWOS Helper when you log in/);stop();
});

test('failed login toggle restores the saved value and shows the error',async()=>{
 const r=await setup({state:'stopped',reason:'Stopped',configuredInputs:0,startAtLogin:false,permissions:{accessibility:true,inputMonitoring:true}},'KC_B','Could not save setting');
 const stop=r.c.helperPanel(r.parent,r.options.notice);await tick();const checkbox=field(r.parent,'Start at login');
 assert.equal(checkbox.checked,false);checkbox.checked=true;await checkbox.onchange();await tick();
 assert.equal(checkbox.checked,false);assert.equal(checkbox.disabled,false);assert.equal(r.notices[0][0],'Could not save setting');stop();
});
