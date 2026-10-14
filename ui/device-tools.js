import {request} from './bridge.js';
export function securityPanel(parent,notice){
 let cancelled=false,timer;const state=document.createElement('p');state.textContent='Checking lock status…';parent.append(state);
 const instructions=document.createElement('p');parent.append(instructions);
 const controls=document.createElement('div');controls.className='row';parent.append(controls);
 function button(text,action){const b=document.createElement('button');b.textContent=text;b.onclick=()=>run(action);controls.append(b);return b;}
 async function run(action){try{const result=await request('security',{action});if(cancelled)return;state.textContent=result.unlocked?'Keyboard unlocked':'Keyboard locked';instructions.textContent=result.unlocked?'Configuration requiring unlock can now be applied.':`To unlock, hold the physical keys: ${result.keys.map(([r,c])=>`row ${r+1}, column ${c+1}`).join(' + ')}.`;if(action==='start'||(action==='poll'&&!result.unlocked))timer=setTimeout(()=>run('poll'),600);}catch(e){notice(e.message,true)}}
 button('Begin physical unlock','start');button('Lock keyboard','lock');run('status');return()=>{cancelled=true;clearTimeout(timer)};
}
export function matrixPanel(parent,notice){
 let active=false,timer;const label=document.createElement('p');label.textContent='Press Start to show physical switch activity. Polling stops when you leave this page.';parent.append(label);
 const grid=document.createElement('div');grid.className='controls';parent.append(grid);const cells=Array.from({length:16},(_,i)=>{const cell=document.createElement('div');cell.className='control';cell.textContent=i===3?'Knob':String(i+1);grid.append(cell);return cell});
 const button=document.createElement('button');button.textContent='Start matrix tester';parent.append(button);
 async function poll(){if(!active)return;try{const state=await request('security',{action:'matrix'});if(!active)return;cells.forEach((cell,i)=>{const pressed=!!(state.rows[Math.floor(i/4)]&(1<<(i%4)));cell.classList.toggle('selected',pressed);cell.textContent=(i===3?'Knob':String(i+1))+(pressed?' · pressed':'')});timer=setTimeout(poll,150)}catch(e){active=false;button.textContent='Start matrix tester';notice(e.message,true)}}
 button.onclick=()=>{active=!active;button.textContent=active?'Stop matrix tester':'Start matrix tester';if(active)poll();else clearTimeout(timer)};return()=>{active=false;clearTimeout(timer)};
}
