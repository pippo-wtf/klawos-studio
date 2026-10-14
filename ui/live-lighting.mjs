// One request at a time; replace queued slider positions with the newest one.
export function liveLighting({send,base,saved,status,error,delay=400}){
 let pending=null,running=null,timer=null,expected=null;
 const copy=structuredClone;
 async function drain(){
  if(running)return running;
  running=(async()=>{while(pending){const item=pending;pending=null;
   try{const snapshot=base();expected??=copy(snapshot.lighting);const result=await send({base:snapshot,lighting:item.value,expected,persist:item.persist});expected=copy(item.value);if(item.persist)saved(result.base);}
   catch(e){pending=null;clearTimeout(timer);timer=null;error(e);break;}
  }})().finally(()=>{running=null;if(!timer&&!pending)status(false)});
  return running;
 }
 function update(value){clearTimeout(timer);status(true);const next=copy(value);pending={value:next,persist:false};drain();timer=setTimeout(()=>{timer=null;pending={value:next,persist:true};drain()},delay);}
 return {update};
}
