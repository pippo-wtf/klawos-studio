import {parseKeyChoice} from './copy.mjs';
const actions=[['TO','Switch to'],['MO','Hold'],['TG','Toggle'],['DF','Set default layer to']];
export function layerActionOptions(names,catalog,encoder=false){
 return actions.filter(([action])=>!encoder||action!=='MO').flatMap(([action,title])=>names.flatMap((name,layer)=>{
  const code=`${action}(${layer})`;return catalog.some(key=>key.code===code)?[{code,label:`${title} ${name}`}]:[];
 }));
}
export function selectedLayerAction(value,options,catalog){
 const numeric=typeof value==='number'?value:typeof value==='string'&&/^0x[0-9a-f]{1,4}$/i.test(value)?Number(value):null;
 return options.find(option=>option.code===value||numeric!==null&&catalog.some(key=>key.code===option.code&&key.value===numeric))?.code??'';
}
export function parseLayerAction(code,current,names,catalog,encoder=false){
 if(!layerActionOptions(names,catalog,encoder).some(option=>option.code===code))throw Error('Choose a supported layer action.');
 return parseKeyChoice(code,current,names,catalog);
}
