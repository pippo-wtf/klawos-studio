import {setControl} from './state.mjs';
export function macroStep(type,value,parseKey){
 if(type==='delay'){const wait=Number(value);if(!Number.isInteger(wait)||wait<0||wait>65024)throw Error('Wait must be a whole number from 0 to 65024 milliseconds.');return [type,wait]}
 if(type==='text')return [type,String(value)];
 if(!['tap','down','up'].includes(type))throw Error('Choose a valid step.');
 return [type,...String(value).split(/\s*\+\s*|\s*,\s*/).map(key=>key.trim()).filter(Boolean).map(parseKey)];
}
export function slotCode(field,index){if(!Number.isInteger(index)||index<0)throw Error('Choose a valid action.');if(field==='macro')return 'M'+index;if(field==='tap_dance')return `TD(${index})`;throw Error('This action cannot be assigned to a button.');}
export function assignSlot(draft,field,index,layer,id){if(id==='key:0:3')throw Error('Choose a button, so the knob keeps switching modes.');if(!/^key:[0-3]:[0-3]$/.test(id))throw Error('Choose a button.');setControl(draft,layer,id,slotCode(field,index));}
export function slotUses(draft,field,index,catalog=[]){const code=slotCode(field,index),numeric=catalog.find(key=>key.code===code)?.value,out=[];draft.hardware.layout.forEach((map,layer)=>map.forEach((row,r)=>row.forEach((value,c)=>{if(value===code||(numeric!==undefined&&value===numeric))out.push({layer,id:`key:${r}:${c}`})})));return out;}
