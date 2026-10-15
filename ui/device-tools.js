import {request} from './bridge.js';
export function securityPanel(parent,notice){
 let cancelled=false,timer,pending=false,unlocking=false,current=null;
 const card=document.createElement('div');card.className='card security-card';parent.append(card);
 const state=document.createElement('p');state.className='status';state.setAttribute('role','status');state.setAttribute('aria-live','polite');card.append(state);
 const instructions=document.createElement('p');card.append(instructions);
 const error=document.createElement('p');error.className='status error';error.setAttribute('role','alert');error.hidden=true;card.append(error);
 const controls=document.createElement('div');controls.className='action-row';card.append(controls);
 const actionButton=document.createElement('button');actionButton.className='primary';controls.append(actionButton);
 function render(){
  state.textContent=!current?(error.hidden?'Checking keyboard lock…':'Could not read keyboard lock status'):current.unlocked?'Settings unlocked':current.inProgress?'Waiting for keyboard confirmation…':'Some settings are locked';
  const keys=current?.keys?.map(([r,c])=>`row ${r+1}, column ${c+1}`).join(' + ');
  instructions.textContent=!current?'Checking does not change your keyboard settings.':current.unlocked?'You can save changes to locked settings. Lock settings when you have finished.':current.inProgress?`Hold ${keys||'the unlock keys on your keyboard'} until the keyboard confirms. ${unlocking?'Keep this page open while unlocking.':'Then choose Check lock status.'}`:`To unlock, choose Unlock settings, then hold ${keys||'the unlock keys on your keyboard'}.`;
  actionButton.textContent=!current?'Check lock status':current.unlocked?'Lock settings':unlocking?'Waiting for keyboard…':current.inProgress?'Check lock status':'Unlock settings';
  actionButton.disabled=pending||unlocking;
  card.setAttribute('aria-busy',String(pending||unlocking));
 }
 async function run(action){
  if(cancelled||pending||(unlocking&&action!=='poll'))return;
  pending=true;error.hidden=true;render();
  try{
   const result=await request('security',{action});
   if(cancelled)return;
   current=result;
   unlocking=(action==='start'||action==='poll')&&!result.unlocked&&result.inProgress;
   if(unlocking)timer=setTimeout(()=>run('poll'),600);
  }catch(e){
   if(cancelled)return;
   unlocking=false;error.textContent=e.message;error.hidden=false;
   notice(e.message,true);
  }finally{if(!cancelled){pending=false;render();}}
 }
 actionButton.onclick=()=>run(!current||(!current.unlocked&&current.inProgress)?'status':current.unlocked?'lock':'start');
 run('status');
 return()=>{cancelled=true;clearTimeout(timer)};
}
export function matrixPanel(parent,notice){
 let active=false,timer;const label=document.createElement('p');label.textContent='Click Start test, then press keys on your keyboard. The test stops when you leave this page.';parent.append(label);
 const grid=document.createElement('div');grid.className='controls';parent.append(grid);const cells=Array.from({length:16},(_,i)=>{const cell=document.createElement('div');cell.className='control';cell.textContent=i===3?'Knob':String(i+1);grid.append(cell);return cell});
 const button=document.createElement('button');button.textContent='Start test';parent.append(button);
 async function poll(){if(!active)return;try{const state=await request('security',{action:'matrix'});if(!active)return;cells.forEach((cell,i)=>{const pressed=!!(state.rows[Math.floor(i/4)]&(1<<(i%4)));cell.classList.toggle('selected',pressed);cell.textContent=(i===3?'Knob':String(i+1))+(pressed?' · pressed':'')});timer=setTimeout(poll,150)}catch(e){active=false;button.textContent='Start test';notice(e.message,true)}}
 button.onclick=()=>{active=!active;button.textContent=active?'Stop test':'Start test';if(active)poll();else clearTimeout(timer)};return()=>{active=false;clearTimeout(timer)};
}
