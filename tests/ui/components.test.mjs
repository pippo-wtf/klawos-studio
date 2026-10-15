import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('../../ui/device-tools.js',import.meta.url),'utf8').replace(/^import .*;\n/,'').replaceAll('export function ','function ');
const tick=async()=>{for(let i=0;i<20;i++)await Promise.resolve()};
function element(tag){
 return {tag,children:[],textContent:'',hidden:false,disabled:false,attributes:{},className:'',append(...children){this.children.push(...children)},setAttribute(name,value){this.attributes[name]=value},classList:{toggle(){}}};
}
function panel(send){
 const parent=element('section'),calls=[],notices=[],timers=new Map();let timerID=0;
 const context={document:{createElement:element},request:async(op,payload)=>{calls.push({op,...payload});return send(payload.action)},setTimeout:fn=>{timers.set(++timerID,fn);return timerID},clearTimeout:id=>timers.delete(id)};
 vm.createContext(context);vm.runInContext(source,context);
 const stop=context.securityPanel(parent,(...args)=>notices.push(args));
 const all=()=>{const nodes=[];const walk=n=>{nodes.push(n);n.children.forEach(walk)};walk(parent);return nodes};
 return {parent,calls,notices,timers,stop,all,buttons:()=>all().filter(n=>n.tag==='button'&&!n.hidden),text:()=>all().map(n=>n.textContent).join('\n'),poll:async()=>{const [id,fn]=timers.entries().next().value;timers.delete(id);await fn();await tick()}};
}
const locked={unlocked:false,inProgress:false,keys:[[0,1],[1,2]]};

test('keyboard lock render only reads status and shows the relevant action',async()=>{
 const p=panel(async()=>locked);await tick();
 assert.deepEqual(p.calls,[{op:'security',action:'status'}]);
 assert.deepEqual(p.buttons().map(b=>b.textContent),['Unlock settings']);
 assert.match(p.text(),/row 1, column 2/);
 assert.equal(p.timers.size,0);p.stop();
});
test('an unlocked keyboard offers only Lock settings',async()=>{
 const p=panel(async()=>({...locked,unlocked:true}));await tick();
 assert.deepEqual(p.buttons().map(b=>b.textContent),['Lock settings']);p.stop();
});
test('unlock stays pending through hardware confirmation and prevents duplicate operations',async()=>{
 let release;const pending=new Promise(resolve=>release=resolve);
 const p=panel(async action=>action==='status'?locked:action==='start'?pending:{...locked,unlocked:true});await tick();
 const button=p.buttons()[0];const first=button.onclick();const second=button.onclick();await tick();
 assert.equal(button.disabled,true);assert.deepEqual(p.calls.map(c=>c.action),['status','start']);
 release({...locked,inProgress:true});await first;await second;await tick();
 assert.equal(button.disabled,true);assert.match(p.text(),/hold/i);assert.equal(p.timers.size,1);
 await p.poll();assert.deepEqual(p.buttons().map(b=>b.textContent),['Lock settings']);assert.equal(button.disabled,false);assert.equal(p.timers.size,0);p.stop();
});
test('failed lock reports an inline error and permits retry without guessing a new state',async()=>{
 let fail=true;
 const p=panel(async action=>{if(action==='lock'&&fail)throw Error('Keyboard disconnected');return action==='status'?{...locked,unlocked:true}:locked});await tick();
 await p.buttons()[0].onclick();await tick();
 assert.match(p.text(),/Keyboard disconnected/);assert.equal(p.buttons()[0].textContent,'Lock settings');assert.equal(p.buttons()[0].disabled,false);
 fail=false;await p.buttons()[0].onclick();await tick();assert.equal(p.buttons()[0].textContent,'Unlock settings');p.stop();
});
test('leaving keyboard lock during an unlock ignores late completion and polling',async()=>{
 let release;const pending=new Promise(resolve=>release=resolve);
 const p=panel(async action=>action==='status'?locked:pending);await tick();
 const action=p.buttons()[0].onclick();p.stop();release({...locked,inProgress:true});await action;await tick();
 assert.equal(p.timers.size,0);assert.deepEqual(p.calls.map(c=>c.action),['status','start']);
});
test('a failed status read offers a read-only retry',async()=>{
 let fail=true;const p=panel(async()=>{if(fail)throw Error('Connect your keyboard');return locked});await tick();
 assert.match(p.text(),/Connect your keyboard/);assert.equal(p.buttons()[0].textContent,'Check lock status');
 fail=false;await p.buttons()[0].onclick();await tick();assert.equal(p.buttons()[0].textContent,'Unlock settings');assert.deepEqual(p.calls.map(c=>c.action),['status','status']);p.stop();
});
test('an unlock already in progress offers a read-only status check on arrival',async()=>{
 const p=panel(async()=>({...locked,inProgress:true}));await tick();
 assert.equal(p.buttons()[0].textContent,'Check lock status');assert.equal(p.buttons()[0].disabled,false);assert.equal(p.timers.size,0);
 await p.buttons()[0].onclick();await tick();assert.deepEqual(p.calls.map(c=>c.action),['status','status']);p.stop();
});
