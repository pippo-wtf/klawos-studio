import test from 'node:test';
import assert from 'node:assert/strict';
import {liveLighting} from '../../ui/live-lighting.mjs';
const wait=ms=>new Promise(r=>setTimeout(r,ms));
test('rapid slider changes coalesce, serialize, and save only final lighting',async()=>{
 const calls=[],saved=[],errors=[];let active=0,maxActive=0;const base={lighting:{color:0},hardware:{key:'A'}};
 const live=liveLighting({base:()=>base,delay:20,status:()=>{},error:e=>errors.push(e),saved:b=>saved.push(b),send:async p=>{active++;maxActive=Math.max(active,maxActive);calls.push(p);await wait(8);active--;return {base:{...base,lighting:p.lighting}};}});
 live.update({color:1});live.update({color:2});live.update({color:3});await wait(90);
 assert.equal(maxActive,1);assert.deepEqual(calls.map(c=>c.lighting.color),[1,3,3]);assert.deepEqual(calls.map(c=>c.persist),[false,false,true]);assert.equal(saved.length,1);assert.equal(saved[0].lighting.color,3);assert.equal(base.hardware.key,'A');assert.equal(errors.length,0);
 assert.deepEqual(calls[1].expected,{color:1});assert.deepEqual(calls[2].expected,{color:3});
});
test('failed preview stops automatic saves and reports failure',async()=>{
 let calls=0,saves=0;const errors=[],states=[];
 const live=liveLighting({base:()=>({lighting:{}}),delay:10,status:b=>states.push(b),error:e=>errors.push(e),saved:()=>saves++,send:async()=>{calls++;throw Error('Disconnected')}});
 live.update({color:1});await wait(50);assert.equal(calls,1);assert.equal(saves,0);assert.equal(errors.length,1);assert.equal(states.at(-1),false);
});
