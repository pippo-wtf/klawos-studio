import {appName,keyName} from './copy.mjs';
import {appShortcuts,presetAction,presetForAction} from './app-shortcuts.mjs';
import {keyboardAction,keyboardCode,shortcutCode,setBindingAction,setKeyboardBinding} from './binding-actions.mjs';
import {request} from './bridge.js';
export const appCatalog=request('actionCatalog').then(data=>({...data,apps:data.apps.map(app=>({...app,name:appName(app.bundleID,data.apps)}))})).catch(()=>({apps:[],keys:[]}));
function el(tag,text=''){const node=document.createElement(tag);node.textContent=text;return node}
function field(parent,title,input){const label=el('label');label.className='field';label.append(el('span',title),input);parent.append(label);return input}
function picker(parent,title,current,list,valueKey,labelKey,change){const select=el('select');for(const item of list){const option=el('option',item[labelKey]);option.value=item[valueKey];select.append(option)}if(!list.some(item=>String(item[valueKey])===String(current))){const option=el('option',String(current||'Choose…'));option.value=current??'';select.append(option)}select.value=current??'';select.onchange=()=>change(select.value);return field(parent,title,select)}
function text(parent,title,value,change){const input=el('input');input.value=value??'';input.onchange=()=>change(input.value);return field(parent,title,input)}
function actions(parent){const row=el('div');row.className='action-row';parent.append(row);return row}
function hint(parent,text){const node=el('p',text);node.className='hint';parent.append(node)}
function actionSummary(action,catalog){if(!action)return 'No fallback set. Choose Keyboard for All other apps.';const code=shortcutCode(action,catalog.keys);return code?keyName(code):action?.kind==='openApp'?'Open '+appName(action.parameters.bundleID,catalog.apps):presetForAction(action)?.name??(action?.kind==='none'?'Do nothing':action?.kind==='namedShortcut'?'Run '+action.parameters.name:action?.kind==='menuCommand'?action.parameters.menuPath.join(' → '):'Keyboard action')}
export function actionEditor(parent,{draft,layer,inputID,changed,notice,keyCatalog=[],keyboardEditor,cancelRecording=()=>{}}){
 if(layer!==0||inputID==='key:0:3'||inputID.startsWith('encoder:'))return;
 parent.append(el('h3','Button action'));
 const context=picker(parent,'When using','default',[{value:'default',name:'All other apps'},{value:'com.openai.codex',name:'ChatGPT'},{value:'com.anthropic.claudefordesktop',name:'Claude'}],'value','name',()=>{cancelRecording();pendingAction=null;pendingKeyboard=false;draw()});
 const editor=el('div');parent.append(editor);let pendingAction=null,pendingKeyboard=false;
 function editKeyboard(container,value,commit,pending=false){
  const submit=code=>{try{commit(code)}catch(error){notice(error.message,true)}};
  if(keyboardEditor)keyboardEditor(container,value,submit,{pending});else text(container,'Key or shortcut',value??'',submit);
 }
 async function draw(){
  const catalog=await appCatalog;editor.replaceChildren();const profile=draft.profiles[inputID],key=context.value;
  const installed=key==='default'?profile?.default:profile?.overrides?.[key],action=pendingAction??(installed?structuredClone(installed):null);
  let choice=pendingKeyboard?'keyboard':!action?(key==='default'?'keyboard':'inherit'):action.kind==='openApp'?'openApp':action.kind==='shortcut'&&!presetForAction(action)?'keyboard':'other';
  const choices=[{value:'keyboard',name:'Keyboard'},{value:'openApp',name:'Open app'},{value:'other',name:'Other Mac action'}];if(key!=='default')choices.push({value:'inherit',name:'Use All other apps'});
  picker(editor,'Action',choice,choices,'value','name',selectAction);
  if(key!=='default')hint(editor,'All other apps → '+(profile?actionSummary(profile.default,catalog):keyName(draft.hardware.layout[0][Number(inputID.split(':')[1])][Number(inputID.split(':')[2])])));
  function save(value){
   try{setBindingAction(draft,inputID,key,value,catalog.keys,keyCatalog);pendingAction=null;pendingKeyboard=false;changed();draw();return true}
   catch(error){pendingAction=value;notice(error.message,true);draw();return false}
  }
  function commitKeyboard(code){
   const action=keyboardAction(code,catalog.keys,keyCatalog);
   if(key!=='default'&&!draft.profiles[inputID]?.default&&action&&keyboardCode(draft,inputID,catalog.keys,keyCatalog)==null){pendingAction=action;pendingKeyboard=false;notice('Choose a keyboard fallback for All other apps before adding this app action.',true);draw();return}
   setKeyboardBinding(draft,inputID,key,code,catalog.keys,keyCatalog);pendingAction=null;pendingKeyboard=false;changed();draw();
  }
  function selectAction(value){
   cancelRecording();pendingAction=null;pendingKeyboard=false;
   if(value==='inherit'){save(null);return}
   if(value==='keyboard'){
    const known=key==='default'?keyboardCode(draft,inputID,catalog.keys,keyCatalog):shortcutCode(action,catalog.keys)??keyboardCode(draft,inputID,catalog.keys,keyCatalog);
    if(known!=null){try{commitKeyboard(known);return}catch(error){notice(error.message,true)}}
    pendingKeyboard=true;draw();return;
   }
   if(value==='openApp'){save({kind:'openApp',parameters:{bundleID:catalog.apps[0]?.bundleID??'com.apple.TextEdit'}});return}
   save(presetAction(key==='com.anthropic.claudefordesktop'?'claude.new-chat':'chatgpt.quick-chat'));
  }
  if(choice==='keyboard'){
   const code=pendingKeyboard?null:action?shortcutCode(action,catalog.keys):draft.hardware.layout[0][Number(inputID.split(':')[1])][Number(inputID.split(':')[2])];
   if(pendingKeyboard)hint(editor,'Choose a real key or shortcut to finish changing to Keyboard. App exceptions stay in place.');
   editKeyboard(editor,code,commitKeyboard,pendingKeyboard);
   if(profile&&Object.keys(profile.overrides??{}).length)hint(editor,'App exceptions stay active. Mac actions must be on to send this keyboard fallback.');
  }else if(choice==='other'){
   const kind=presetForAction(action)?'preset':action?.kind??'preset';
   picker(editor,'Mac action',kind,[{value:'preset',name:'ChatGPT or Claude shortcut'},{value:'namedShortcut',name:'Run macOS Shortcut'},{value:'menuCommand',name:'Choose a menu item'},{value:'none',name:'Do nothing'}],'value','name',kind=>save(kind==='preset'?presetAction(key==='com.anthropic.claudefordesktop'?'claude.new-chat':'chatgpt.quick-chat'):{kind,parameters:kind==='namedShortcut'?{name:''}:kind==='menuCommand'?{bundleID:key==='default'?'com.apple.TextEdit':key,menuPath:['File','New']}:{}}));
  }
  if(action&&!pendingKeyboard){const parameters=action.parameters,update=()=>save(action);
   const preset=presetForAction(action);
   if(preset){
    const select=el('select');for(const app of ['ChatGPT','Claude']){const group=el('optgroup');group.label=app;for(const entry of appShortcuts.filter(item=>item.app===app)){const option=el('option',entry.name+(entry.keys?' · '+entry.keys:''));option.value=entry.id;group.append(option)}select.append(group)}select.value=preset.id;select.onchange=()=>save(presetAction(select.value));field(editor,'Shortcut',select);hint(editor,preset.hint??'Opens the app before using its shortcut.');
   }
   if(action.kind==='openApp')picker(editor,'App to open',parameters.bundleID,catalog.apps,'bundleID','name',value=>{parameters.bundleID=value;update()});
   if(action.kind==='namedShortcut')text(editor,'Shortcut name',parameters.name,value=>{parameters.name=value;update()});
   if(action.kind==='menuCommand'){picker(editor,'App',parameters.bundleID,catalog.apps,'bundleID','name',value=>{parameters.bundleID=value;update()});text(editor,'Menu items, separated by / (for example, File / New)',parameters.menuPath.join(' / '),value=>{parameters.menuPath=value.split('/').map(part=>part.trim());update()})}
  }
  if(pendingAction){
   hint(editor,'Choose a keyboard fallback for All other apps. This app action has not been added yet.');
   editKeyboard(editor,null,code=>{setBindingAction(draft,inputID,key,pendingAction,catalog.keys,keyCatalog,code);pendingAction=null;changed();draw()},true);
  }
  if(action&&!pendingKeyboard&&!pendingAction){
   const [,row,column]=inputID.split(':').map(Number),original=draft.base.hardware.layout[0][row][column];
   const inherited=draft.hardware.layout.slice(1).map((map,index)=>({index:index+1,code:map[row][column]})).filter(cell=>cell.code==='KC_TRNS'||cell.code===1);
   if(inherited.length&&keyboardAction(original,catalog.keys,keyCatalog)){const copy=el('button',`Use ${keyName(original)} on the other layers`);copy.onclick=()=>{for(const cell of inherited)draft.hardware.layout[cell.index][row][column]=original;changed();draw();notice(`This key will use ${keyName(original)} on ${inherited.length} other layers. Review the changes before saving.`)};actions(editor).append(copy)}
  }
  if(profile||action){hint(editor,'Save to keyboard, then switch to another app to test. Mac actions pause while Studio is in front.');const details=el('details');details.append(el('summary','How app actions work'),el('p','Mac actions must be on. They use reserved shortcuts; the same shortcut from another keyboard can also run an action.'));editor.append(details)}
  else if(choice==='inherit')hint(editor,'Uses the action set for All other apps.');
 }
 draw();
}
export function helperPanel(parent,notice){
 let stopped=false,timer;const status=el('h2','Checking Mac actions…'),details=el('p'),permissions=el('p'),sync=el('p'),resolution=el('div'),controls=el('div');resolution.className='action-row';controls.className='action-row';parent.append(status,details,permissions,sync,resolution,controls);
 const warning=el('p','Mac actions pause while KLAWOS Studio is in front. To test an action, save it and switch to another app, then press its KLAWOS button. Actions resume automatically. They do not switch keyboard layers.');warning.className='disabled-note';parent.append(warning);
 function control(container,title,operation){const button=el('button',title);button.onclick=async()=>{button.disabled=true;try{await request(operation);await refresh()}catch(error){notice(error.message,true);button.disabled=false}};container.append(button);return button}
 const login=el('input');login.type='checkbox';field(parent,'Start at login',login);hint(parent,'Start KLAWOS Helper when you log in. This setting applies only to this Mac.');
 let changingLogin=false;
 login.onchange=async()=>{const enabled=login.checked;changingLogin=true;login.disabled=true;try{await request('helperSetStartAtLogin',{enabled})}catch(error){login.checked=!enabled;notice(error.message,true)}finally{changingLogin=false;login.disabled=false;await refresh()}};
 const troubleshooting=el('details');troubleshooting.append(el('summary','Troubleshooting'));control(actions(troubleshooting),'Restart Mac actions','repairHelper');parent.append(troubleshooting);
 async function refresh(){
  if(stopped)return;clearTimeout(timer);
  try{
   const [result,shared]=await Promise.all([request('helperStatus'),request('syncStatus')]);if(stopped)return;
   if(!changingLogin)login.checked=result.startAtLogin??true;
   const active=['running','paused'].includes(result.state),allowed=result.permissions.accessibility&&result.permissions.inputMonitoring;
   status.textContent=result.state==='paused'?'Mac actions are paused':result.state==='running'?'Mac actions are on':'Mac actions are off';details.textContent=(!['Running','Stopped'].includes(result.reason)?result.reason+' · ':'')+result.configuredInputs+(result.configuredInputs===1?' key set up':' keys set up')+(result.lastResult?' · '+result.lastResult:'');permissions.textContent=`Accessibility: ${result.permissions.accessibility?'on':'off'} · Input Monitoring: ${result.permissions.inputMonitoring?'on':'off'}`;
   controls.replaceChildren();const toggle=control(controls,active?'Turn off Mac actions':'Turn on Mac actions',active?'helperStop':'helperStart');toggle.disabled=!active&&(!allowed||!result.configuredInputs);
   if(!allowed){control(controls,'Allow Mac access','helperPermissions');hint(controls,'Allow KLAWOS Helper in System Settings → Privacy & Security → Accessibility and Input Monitoring, then turn on Mac actions.');}
   else if(!active&&!result.configuredInputs)hint(controls,'Assign a Mac action to a key on the first layer and save to keyboard first.');
   sync.textContent=shared.status;resolution.replaceChildren();if(shared.status.includes('Settings changed on both Macs'))for(const [title,choice] of [['Keep this Mac’s settings','thisMac'],['Use the other Mac’s settings','otherMac']]){const button=el('button',title);button.onclick=()=>request('syncResolve',{choice}).then(()=>{window.dispatchEvent(new Event('klawos-sync-resolved'));refresh()}).catch(error=>notice(error.message,true));resolution.append(button)}
  }catch(error){notice(error.message,true)}
  if(!stopped)timer=setTimeout(refresh,2000);
 }
 hint(parent,'Mac actions stay on when you close this window. Turn them off here or from the menu bar.');refresh();return()=>{stopped=true;clearTimeout(timer)};
}
