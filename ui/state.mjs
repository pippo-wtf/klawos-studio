export const layerNames=['Work','Dota','Wardogs','Layer 4','Layer 5','Layer 6'];
export function createDraft(snapshot){return {base:structuredClone(snapshot),hardware:structuredClone(snapshot.hardware),lighting:structuredClone(snapshot.lighting),profiles:{},baseProfiles:{}};}
export function setControl(draft,layer,id,value){
  if(!Number.isInteger(layer)||layer<0||layer>=draft.hardware.layout.length)throw Error('Choose a valid layer');
  if(id.startsWith('key:')){const [,r,c]=id.split(':').map(Number);if(!draft.hardware.layout[layer]?.[r]||c<0||c>=draft.hardware.layout[layer][r].length)throw Error('Unknown control');draft.hardware.layout[layer][r][c]=value;}
  else if(/^encoder:0:(ccw|cw)$/.test(id))draft.hardware.encoder_layout[layer][0][id.endsWith(':ccw')?0:1]=value;
  else throw Error('Unknown control');
}
export function getControl(draft,layer,id){if(id.startsWith('key:')){const [,r,c]=id.split(':').map(Number);return draft.hardware.layout[layer][r][c];}return draft.hardware.encoder_layout[layer][0][id.endsWith(':ccw')?0:1];}
export function changes(draft){const out=[];function walk(a,b,path){if(JSON.stringify(a)===JSON.stringify(b))return;if(a&&b&&typeof a==='object'&&typeof b==='object'&&Array.isArray(a)===Array.isArray(b)){for(const k of new Set([...Object.keys(a),...Object.keys(b)]))walk(a[k],b[k],path+'.'+k);}else out.push({path,before:a,after:b});}walk(draft.base.hardware,draft.hardware,'hardware');walk(draft.base.lighting,draft.lighting,'lighting');walk(draft.baseProfiles??{},draft.profiles??{},'profiles');return out;}
export function controlIDs(){return Array.from({length:16},(_,i)=>`key:${Math.floor(i/4)}:${i%4}`).concat(['encoder:0:ccw','encoder:0:cw']);}

export function discardDraft(draft){const clean=createDraft(draft.base);clean.profiles=structuredClone(draft.baseProfiles??{});clean.baseProfiles=structuredClone(clean.profiles);if(draft.projectDocument)clean.projectDocument=structuredClone(draft.projectDocument);return clean;}
export function restoreDraft(snapshot,profiles,saved){const fresh=createDraft(snapshot);fresh.profiles=structuredClone(profiles);fresh.baseProfiles=structuredClone(profiles);if(saved?.base?.identity?.uid!==snapshot.identity.uid)return fresh;if(!changes(saved).length){if(saved.projectDocument)fresh.projectDocument=structuredClone(saved.projectDocument);return fresh;}const restored=structuredClone(saved);restored.base.metadata=structuredClone(snapshot.metadata);return restored;}

export function layerName(draft,index){const value=draft?.projectDocument?.metadata?.layerNames?.[index];return index>=3&&typeof value==='string'&&value.trim()?value.slice(0,80):layerNames[index];}
