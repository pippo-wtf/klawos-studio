import {recordingComplete,recordedChord} from './shortcut-recording.mjs';

// The session owns late native replies, timers, and cleanup even before Start replies.
export function createShortcutRecording({send,capture,isCurrent=()=>true,onState=()=>{},notice=()=>{},captureEscape=false,success=()=>captureEscape?'Button test complete. Your settings are unchanged.':'Shortcut recorded. Save to keyboard when you are ready.',prompt=captureEscape?'Other shortcuts are paused. Press this button on KLAWOS once. Escape is received as a key. Use Cancel to stop the test.':'Other shortcuts are paused. Press your shortcut and release the main key to finish. Press Escape or Cancel to cancel. To assign Escape, choose it in Key or shortcut.',maxKeys=5,timeout=30000,pollInterval=100}){
 let cancelled=false,settled=false,started=false,stopped=false,wake,timer;
 const current=()=>!cancelled&&isCurrent();
 async function stop(){if(started&&!stopped){stopped=true;await send('recordingStop');}}
 function cancel(){if(settled||cancelled)return;cancelled=true;clearTimeout(timer);wake?.();notice(captureEscape?'Button test cancelled. Your settings are unchanged.':'Recording cancelled. Your keys are unchanged.');}
 function idle(){if(!settled){settled=true;onState('idle');}}
 async function start(){
  onState('starting');
  try{
   started=true;if(captureEscape)await send('recordingStart',{captureEscape:true});else await send('recordingStart');
   if(!current())return;
   onState('recording');notice(prompt);
   const deadline=Date.now()+timeout;let heard=0;
   while(current()){
    const result=await send('recordingStatus');
    if(!current())return;
    if(!result.active){notice(captureEscape?'Button test stopped. Keep Studio in front, click Test this button, and try again.':'Recording stopped. No shortcut was assigned. Click Record shortcut to try again.',true);return;}
    const count=result.events.filter(([kind])=>kind==='down').length;
    if(count>heard){heard=count;notice('Keys detected. Release the main key to finish.');}
    if(recordingComplete(result.events)){
     const keys=recordedChord(result.events,maxKeys);
     await stop();if(!current())return;
     idle();capture(keys);notice(success(keys));return;
    }
    if(Date.now()>=deadline)throw Error(heard?(captureEscape?'Release the button to finish the test, then try again.':'Release the main key to finish recording, then try again.'):(captureEscape?'No keys were received. Keep Studio in front, click Test this button, and try again.':'No keys were received. Keep Studio in front, click Record shortcut, and try again.'));
    await new Promise(resolve=>{wake=resolve;timer=setTimeout(resolve,pollInterval);});wake=null;
   }
  }catch(error){if(!cancelled)notice(error.message,true);}
  finally{clearTimeout(timer);try{await stop();}catch(error){notice(error.message,true);}idle();}
 }
 return {start,cancel};
}
