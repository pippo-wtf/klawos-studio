let sequence=Promise.resolve();
export function request(operation,payload={}){
 const task=sequence.then(async()=>{if(!window.webkit?.messageHandlers?.klawos)throw Error('Open this editor in KLAWOS Studio.');const response=await window.webkit.messageHandlers.klawos.postMessage({operation,payload});if(!response.ok)throw Error(response.error||'Could not finish. Try again in a moment.');return response.result;});sequence=task.catch(()=>{});return task;
}
