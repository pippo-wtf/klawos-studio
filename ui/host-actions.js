import {request} from './bridge.js';
const catalogPromise=request('actionCatalog').catch(()=>({apps:[],keys:[]}));
function picker(parent,title,current,list,valueKey,labelKey,change){const select=el('select');for(const item of list){const option=el('option',item[labelKey]);option.value=item[valueKey];select.append(option)}if(!list.some(item=>String(item[valueKey])===String(current))){const option=el('option',String(current||'Choose…'));option.value=current??'';select.append(option)}select.value=current??'';select.onchange=()=>change(select.value);field(parent,title,select);return select;}
function el(tag,text=''){const n=document.createElement(tag);n.textContent=text;return n}
function field(parent,title,input){const label=el('label',title);label.append(input);parent.append(label);return input}
function text(parent,title,value,change){const input=el('input');input.value=value??'';input.onchange=()=>change(input.value);return field(parent,title,input)}
export function actionEditor(parent,{draft,layer,inputID,changed,notice}){
 parent.append(el('h3','Mac action'));
 if(layer!==0||inputID==='key:0:3'||inputID.startsWith('encoder:')){parent.append(el('p','Mac actions are assigned to ordinary keys on the Work layer.'));return;}
 const context=el('select');for(const [value,label] of [['default','Default Work'],['com.openai.codex','Codex'],['com.anthropic.claudefordesktop','Claude']]){const option=el('option',label);option.value=value;context.append(option)}field(parent,'When using',context);
 const editor=el('div');parent.append(editor);
 async function draw(){const catalog=await catalogPromise;editor.replaceChildren();const profile=draft.profiles[inputID],key=context.value;const action=key==='default'?profile?.default:profile?.overrides?.[key];
 const type=el('select');for(const [value,label] of [['hardware','Keyboard assignment'],['inherit','Use Default Work'],['none','No action'],['shortcut','Keyboard shortcut'],['openApp','Open app'],['namedShortcut','Run macOS Shortcut'],['menuCommand','App menu command']]){if(key==='default'&&value==='inherit')continue;if(key!=='default'&&value==='hardware')continue;const option=el('option',label);option.value=value;type.append(option)}type.value=action?.kind??(key==='default'?'hardware':'inherit');field(editor,'Action',type);
 function save(value){if(value===null){if(key==='default')delete draft.profiles[inputID];else if(draft.profiles[inputID])delete draft.profiles[inputID].overrides[key];}else{const profile=draft.profiles[inputID]??={default:{kind:'none',parameters:{}},overrides:{}};if(key==='default')profile.default=value;else profile.overrides[key]=value;}changed();}
 type.onchange=()=>{const kind=type.value;if(['hardware','inherit'].includes(kind)){save(null);draw();return;}const parameters=kind==='shortcut'?{keyCode:0,modifiers:['command']}:kind==='openApp'?{bundleID:'com.apple.TextEdit'}:kind==='namedShortcut'?{name:''}:kind==='menuCommand'?{bundleID:context.value==='default'?'':context.value,menuPath:['File','New']}:{};save({kind,parameters});draw()};
 if(action){const p=action.parameters;const update=()=>{save(action)};
 if(action.kind==='openApp')picker(editor,'App to open',p.bundleID,catalog.apps,'bundleID','name',v=>{p.bundleID=v;update()});
 if(action.kind==='namedShortcut')text(editor,'Exact Shortcut name',p.name,v=>{p.name=v;update()});
 if(action.kind==='shortcut'){picker(editor,'Key',p.keyCode,catalog.keys,'keyCode','name',v=>{p.keyCode=Number(v);update()});for(const modifier of ['command','shift','option','control']){const row=el('label',modifier[0].toUpperCase()+modifier.slice(1));const box=el('input');box.type='checkbox';box.style.width='auto';box.checked=p.modifiers.includes(modifier);box.onchange=()=>{p.modifiers=box.checked?[...p.modifiers,modifier]:p.modifiers.filter(m=>m!==modifier);update()};row.prepend(box);editor.append(row);}}

 if(action.kind==='menuCommand'){picker(editor,'App',p.bundleID,catalog.apps,'bundleID','name',v=>{p.bundleID=v;update()});text(editor,'Exact menu path, separated by /',p.menuPath.join(' / '),v=>{p.menuPath=v.split('/').map(s=>s.trim());update()});}
 }
 if(action){const [,row,column]=inputID.split(':').map(Number);const inherited=draft.hardware.layout.slice(1).map((map,i)=>({index:i+1,code:map[row][column]})).filter(x=>x.code==='KC_TRNS'||x.code===1);if(inherited.length){const code=draft.base.hardware.layout[0][row][column];const copy=el('button',`Use ${code} on inherited layers`);copy.onclick=()=>{for(const cell of inherited)draft.hardware.layout[cell.index][row][column]=code;changed();draw();notice(`Copied ${code} to this key on ${inherited.length} other layers. Review these explicit mappings before Apply.`);};editor.append(copy);}}
 const hint=el('p','Helper required. Apply reserves a global F13–F20 shortcut. The same shortcut on another keyboard also triggers this action. Other layers must have explicit assignments for this key.');hint.className='hint';editor.append(hint);
 }
 context.onchange=draw;draw();
}
export function helperPanel(parent,notice){let stopped=false,timer;const status=el('h2','Checking helper…'),details=el('p'),permissions=el('p');parent.append(status,details,permissions);
 const warning=el('p','Development build: physical input and app-action acceptance are still pending. Starting enables the configured global shortcuts. Work/Dota/Wardogs hardware layers are never switched automatically.');warning.className='disabled-note';parent.append(warning);
 async function refresh(){if(stopped)return;clearTimeout(timer);try{const result=await request('helperStatus');if(stopped)return;status.textContent=result.state==='running'?'Mac actions running':'Mac actions stopped';details.textContent=result.reason+' · '+result.configuredInputs+' configured controls';permissions.textContent=`Accessibility: ${result.permissions.accessibility?'allowed':'needed'} · Input Monitoring: ${result.permissions.inputMonitoring?'allowed':'needed'}`;}catch(e){notice(e.message,true)}if(!stopped)timer=setTimeout(refresh,2000)}
 for(const [title,operation] of [['Set up permissions','helperPermissions'],['Start Mac actions','helperStart'],['Stop Mac actions','helperStop'],['Restart helper','repairHelper']]){const button=el('button',title);button.onclick=()=>request(operation).then(refresh).catch(e=>notice(e.message,true));parent.append(button)}
 parent.append(el('p','Enable the required permissions in System Settings → Privacy & Security. Closing the editor leaves a started helper running; Stop disables its reserved-key capture.'));refresh();return()=>{stopped=true;clearTimeout(timer)};
}
