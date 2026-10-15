import test from 'node:test';
import assert from 'node:assert/strict';
import {createShortcutRecording} from '../../ui/recording-session.mjs';

function session(options={}){
 const calls=[],notices=[],captured=[];
 const recorder=createShortcutRecording({
  send:async(...args)=>{calls.push(args);return args[0]==='recordingStatus'?{active:true,events:[['down','KC_ESC'],['up','KC_ESC']]}:{}},
  capture:keys=>captured.push(keys),notice:text=>notices.push(text),...options,
 });
 return {recorder,calls,notices,captured};
}

test('button testing requests Escape capture and receives Escape without assignment claims',async()=>{
 const {recorder,calls,notices,captured}=session({captureEscape:true});
 await recorder.start();
 assert.deepEqual(calls[0],['recordingStart',{captureEscape:true}]);
 assert.deepEqual(captured,[['KC_ESC']]);
 assert.equal(calls.filter(([op])=>op==='recordingStop').length,1);
 assert.match(notices[0],/Escape.*input|Escape.*received|Escape.*key/i);
 assert.doesNotMatch(notices.join(' '),/assign|save to keyboard/i);
});

test('normal recording keeps the existing start contract and explains Escape cancellation',async()=>{
 const {recorder,calls,notices}=session();
 await recorder.start();
 assert.deepEqual(calls[0],['recordingStart']);
 assert.match(notices[0],/Escape.*cancel/i);
});

test('a stopped button test reports a retry without claiming an assignment',async()=>{
 const {recorder,notices,captured}=session({captureEscape:true,send:async()=>({active:false,events:[]})});
 await recorder.start();
 assert.deepEqual(captured,[]);
 assert.match(notices.at(-1),/test.*stopped|stopped.*test/i);
 assert.match(notices.at(-1),/try again/i);
 assert.doesNotMatch(notices.join(' '),/assign|record shortcut|save to keyboard/i);
});

test('cancelling a button test during start cleans up without capturing input',async()=>{
 let complete;const pending=new Promise(resolve=>complete=resolve),calls=[];
 const {recorder,notices,captured}=session({captureEscape:true,send:async op=>{calls.push(op);return op==='recordingStart'?pending:{}}});
 const task=recorder.start();recorder.cancel();complete({});await task;
 assert.deepEqual(captured,[]);
 assert.equal(calls.filter(op=>op==='recordingStop').length,1);
 assert.match(notices.at(-1),/test cancelled/i);
 assert.doesNotMatch(notices.join(' '),/assign|record shortcut|save to keyboard/i);
});

test('button test timeout offers a test retry without assigning anything',async()=>{
 const {recorder,notices,captured}=session({captureEscape:true,timeout:0,send:async()=>({active:true,events:[]})});
 await recorder.start();
 assert.deepEqual(captured,[]);
 assert.match(notices.at(-1),/Test this button.*try again/i);
 assert.doesNotMatch(notices.join(' '),/assign|record shortcut|save to keyboard/i);
});

test('a held button test key times out with test-specific recovery',async()=>{
 const {recorder,notices,captured}=session({captureEscape:true,timeout:0,send:async()=>({active:true,events:[['down','KC_ESC']]})});
 await recorder.start();
 assert.deepEqual(captured,[]);
 assert.match(notices.at(-1),/release.*test.*try again/i);
 assert.doesNotMatch(notices.at(-1),/recording/i);
});
