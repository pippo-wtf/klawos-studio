import {recordingComplete,recordedChord} from './shortcut-recording.mjs';

// The session owns late native replies, timers, and cleanup even before Start replies.
export function createShortcutRecording({send,capture,isCurrent=()=>true,onState=()=>{},notice=()=>{},success=()=> 'Shortcut recorded. Save to keyboard when you are ready.',prompt='Other shortcuts are paused. Press your shortcut and release the main key to finish.',maxKeys=5,timeout=30000,pollInterval=100}){
 let cancelled=false,settled=false,started=false,stopped=false,wake,timer;
 const current=()=>!cancelled&&isCurrent();
 async function stop(){if(started&&!stopped){stopped=true;await send('recordingStop');}}
 function cancel(){if(settled||cancelled)return;cancelled=true;clearTimeout(timer);wake?.();notice('Recording cancelled. Your keys are unchanged.');}
 function idle(){if(!settled){settled=true;onState('idle');}}
 async function start(){
  onState('starting');
  try{
   started=true;await send('recordingStart');
   if(!current())return;
   onState('recording');notice(prompt);
   const deadline=Date.now()+timeout;let heard=0;
   while(current()){
    const result=await send('recordingStatus');
    if(!current())return;
    if(!result.active){notice('Recording stopped. No shortcut was assigned. Click Record shortcut to try again.',true);return;}
    const count=result.events.filter(([kind])=>kind==='down').length;
    if(count>heard){heard=count;notice('Keys detected. Release the main key to finish.');}
    if(recordingComplete(result.events)){
     const keys=recordedChord(result.events,maxKeys);
     await stop();if(!current())return;
     idle();capture(keys);notice(success(keys));return;
    }
    if(Date.now()>=deadline)throw Error(heard?'Release the main key to finish recording, then try again.':'No keys were received. Keep Studio in front, click Record shortcut, and try again.');
    await new Promise(resolve=>{wake=resolve;timer=setTimeout(resolve,pollInterval);});wake=null;
   }
  }catch(error){if(!cancelled)notice(error.message,true);}
  finally{clearTimeout(timer);try{await stop();}catch(error){notice(error.message,true);}idle();}
 }
 return {start,cancel};
}
