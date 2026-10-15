const aliases={ENTER:'ENT',ESCAPE:'ESC',SPACE:'SPC',BSPACE:'BSPC',MINUS:'MINS',EQUAL:'EQL',LBRACKET:'LBRC',RBRACKET:'RBRC',SEMICOLON:'SCLN',QUOTE:'QUOT',BSLASH:'BSLS',COMMA:'COMM',SLASH:'SLSH',GRAVE:'GRV',RIGHT:'RGHT'};
const modifiers={LCTL:'control',LSFT:'shift',LALT:'option',LGUI:'command'};
const groups={LCA:['control','option'],LCG:['control','command'],LCAG:['control','option','command'],LCS:['control','shift'],C_S:['control','shift'],SGUI:['shift','command'],HYPR:['control','shift','option','command'],MEH:['control','shift','option'],LSA:['shift','option']};
const normalize=value=>{const name=String(value).replace(/^KC_/,'');return 'KC_'+(aliases[name]??name)};
const reserved=code=>/^KC_F(1[3-9]|20)$/.test(code);
const hardwareCode=(draft,id)=>{const [,row,col]=id.split(':').map(Number);return draft.hardware.layout[0][row][col]};
function parts(value,firmwareKeys){
 if(typeof value==='string'&&/^(0x[0-9a-f]+|\d+)$/i.test(value))value=Number(value);
 const mods=[];
 if(typeof value==='number'){
  if(!Number.isInteger(value)||value<0||value>0xfff)return null;
  for(const [bit,mod] of [[1,'control'],[2,'shift'],[4,'option'],[8,'command']])if((value>>8)&bit)mods.push(mod);
  value=firmwareKeys.find(key=>key.value===(value&255))?.code;
 }
 let match;
 while(typeof value==='string'&&(match=/^([A-Z_]+)\((.*)\)$/.exec(value))){
  const names=modifiers[match[1]]?[modifiers[match[1]]]:groups[match[1]];
  if(!names)return null;mods.push(...names);value=match[2];
 }
 if(typeof value!=='string'||!/^KC_[A-Z0-9_]+$/.test(value))return null;
 return {code:normalize(value),modifiers:[...new Set(mods)]};
}
export function keyboardAction(value,nativeKeys,firmwareKeys=[]){
 const parsed=parts(value,firmwareKeys);if(!parsed||reserved(parsed.code)||/^KC_[LR](CTL|SFT|ALT|GUI)$/.test(parsed.code))return null;
 const key=nativeKeys.find(key=>normalize(key.name)===parsed.code);
 if(!key||!Number.isInteger(key.keyCode)||key.keyCode<0||key.keyCode>127)return null;
 return {kind:'shortcut',parameters:{keyCode:key.keyCode,modifiers:parsed.modifiers}};
}
export function shortcutCode(action,nativeKeys){
 if(action?.kind!=='shortcut')return null;
 const key=nativeKeys.find(key=>key.keyCode===action.parameters?.keyCode),mods=action.parameters?.modifiers;
 if(!key||!Array.isArray(mods)||mods.some(mod=>!Object.values(modifiers).includes(mod))||reserved(normalize(key.name)))return null;
 return mods.reduceRight((code,mod)=>`${Object.keys(modifiers).find(name=>modifiers[name]===mod)}(${code})`,normalize(key.name));
}
export function keyboardCode(draft,id,nativeKeys,firmwareKeys=[]){
 return shortcutCode(draft.profiles[id]?.default,nativeKeys)??(keyboardAction(hardwareCode(draft,id),nativeKeys,firmwareKeys)?hardwareCode(draft,id):null);
}
export function setBindingAction(draft,id,context,action,nativeKeys,firmwareKeys=[],fallbackCode){
 if(action===null){if(context==='default')throw Error('Choose a keyboard assignment before removing this action.');if(draft.profiles[id]?.overrides)delete draft.profiles[id].overrides[context];return;}
 let profile=draft.profiles[id];
 if(!profile?.default){
  const fallback=context==='default'?action:keyboardAction(fallbackCode??hardwareCode(draft,id),nativeKeys,firmwareKeys);
  if(!fallback)throw Error('Choose a keyboard fallback for All other apps before adding this app action.');
  profile={default:structuredClone(fallback),overrides:structuredClone(profile?.overrides??{})};
 }
 if(context==='default')profile.default=structuredClone(action);else (profile.overrides??={})[context]=structuredClone(action);
 draft.profiles[id]=profile;
}
export function setKeyboardBinding(draft,id,context,code,nativeKeys,firmwareKeys=[]){
 if(code==null||code==='')throw Error('Choose a real key or shortcut before changing to Keyboard.');
 const parsed=parts(code,firmwareKeys);if(parsed&&reserved(parsed.code))throw Error('This key is reserved for Mac actions. Choose another key or shortcut.');
 const profile=draft.profiles[id],overrides=profile?.overrides??{};
 if(context!=='default'||Object.keys(overrides).length){
  const action=keyboardAction(code,nativeKeys,firmwareKeys);if(!action)throw Error('Choose a supported key or shortcut for the keyboard fallback.');
  setBindingAction(draft,id,context,action,nativeKeys,firmwareKeys);return;
 }
 if(profile&&!keyboardAction(code,nativeKeys,firmwareKeys)&&!firmwareKeys.some(key=>(key.code===code||key.value===code)&&!['KC_NO','KC_TRNS','KC_TRANSPARENT'].includes(key.code)))throw Error('Choose a real key or shortcut before changing to Keyboard.');
 const [,row,col]=id.split(':').map(Number);draft.hardware.layout[0][row][col]=code;delete draft.profiles[id];
}
