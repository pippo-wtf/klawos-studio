import {macroStep,assignSlot,slotUses} from './editor-actions.mjs';
import {liveLighting} from './live-lighting.mjs';
import {lightingEffectName,lightingHint} from './lighting-effects.mjs';
import {buttonBinding,buttonLabel,tabLabel,combinationName,controlName,keyName,macroLabels,replacementLabels,settingLabel,settingGroup,changeTitle,reviewRows,parseKeyChoice} from './copy.mjs';
import {request} from './bridge.js';
import {createDraft,discardDraft,restoreDraft,setControl,getControl,changes,controlIDs,layerNames,layerName} from './state.mjs';
import {actionEditor,helperPanel,appCatalog} from './host-actions.js';
import {securityPanel,matrixPanel} from './device-tools.js';
import {mountBoard} from './board-viewer.js';
import {keyboardShortcutCode} from './shortcut-recording.mjs';
import {createShortcutRecording} from './recording-session.mjs';
const $=id=>document.getElementById(id);let draft=null,layer=0,tab='Keymap',selected='key:0:0',catalog={keys:[],settings:{tabs:[]}},viewer=null,autosave,writing=false,stopTools=null,stopChord=null,editGeneration=0,editingLock=null,recordingMacro=false,topView=false,reviewedDraft=null;
const tabs=['Keymap','Macros','Lighting','Tap dance','Combos','Key overrides','QMK settings','Mac helper','Security','Matrix tester','Recovery','Device'];
function node(tag,text='',attrs={}){const n=document.createElement(tag);n.textContent=text;for(const [k,v] of Object.entries(attrs)){if(k==='class')n.className=v;else n.setAttribute(k,v)}return n;}
function message(text,error=false){$('notice').textContent=text;$('notice').classList.toggle('error',error)}
function label(text,control,parent){const l=node('label','',{class:control.type==='checkbox'?'checkbox-field':'field'});l.append(node('span',text),control);parent.append(l);return control;}
function actionRow(parent){const row=node('div','',{class:'action-row'});parent.append(row);return row;}
function button(text,action,parent,cls=''){const b=node('button',text,{class:cls});b.onclick=()=>Promise.resolve(action()).catch(e=>message(e.message,true));parent.append(b);return b;}
function input(value,type='text',change){const e=node('input','',{type});if(type==='range'){e.min=0;e.max=255;}e.value=value;e.onchange=()=>{try{change?.(type==='number'?Number(e.value):e.value)}catch(err){message(err.message,true)}};return e;}
function keyInput(value,change){let current=value;const e=input(displayKey(value),'text',v=>{current=parseKeyChoice(v,current,layerNames.map((_,i)=>layerName(draft,i)),catalog.keys);change(current)});e.setAttribute('list','keycodes');e.spellcheck=false;return e;}
function changed(){editGeneration++;const count=changes(draft).length;$('count').textContent=count;$('apply').disabled=!count||writing;$('draft-status').textContent=count?'Saving your changes…':'No changes to save';clearTimeout(autosave);const value=structuredClone(draft);autosave=setTimeout(()=>request('saveDraft',value).then(()=>{$('draft-status').textContent=changes(draft).length+(changes(draft).length===1?' change · Saved on this Mac':' changes · Saved on this Mac')}).catch(e=>{$('draft-status').textContent='Could not save your changes on this Mac';message(e.message,true)}),300);}
function select(id){if(writing)return;stopChord?.();selected=id;viewer?.select(id);document.querySelectorAll('[data-control]').forEach(b=>{b.classList.toggle('selected',b.dataset.control===id);b.setAttribute('aria-pressed',String(b.dataset.control===id))});renderInspector();}
function controlLabel(id){return controlName(id);}
function displayKey(value){return keyName(value,layerNames.map((_,i)=>layerName(draft,i)),catalog.keys);}
function displayControl(id){return buttonLabel(draft,layer,id,layerNames.map((_,i)=>layerName(draft,i)),catalog.keys,catalog.apps??[]);}
function renderInspector(){
 const aside=$('inspector'),visible=tab==='Keymap'&&!!draft;aside.hidden=!visible;document.querySelector('.workspace').classList.toggle('without-inspector',!visible);aside.replaceChildren();if(!visible)return;
 const target=draft,inputID=selected,targetLayer=layer;
 aside.append(node('p','SELECTED BUTTON',{class:'eyebrow'}),node('h2',controlLabel(inputID)));
 const summary=node('p',displayControl(inputID));aside.append(summary);
 const test=node('div','',{class:'button-test'});
 const afterEdit=()=>{stopChord?.();changed();updateControlLabels();summary.textContent=displayControl(inputID);drawTest()};
 function keyboardEditor(parent,value,commit,{pending=false}={}){
  const field=keyInput(value??'',commit);if(pending)field.placeholder='Choose a key or record a shortcut';label('Key or shortcut',field,parent);
  recordShortcut(parent,'Record shortcut',5,keys=>commit(keyboardShortcutCode(keys)));
  parent.append(node('p','Type a key name or record the keys together. Save to keyboard when you are ready.',{class:'hint'}));
 }
 const assign=value=>{setControl(target,targetLayer,inputID,value);afterEdit();renderInspector()};
 if(targetLayer===0&&inputID!=='key:0:3'&&!inputID.startsWith('encoder:')){
  actionEditor(aside,{draft:target,layer:targetLayer,inputID,keyCatalog:catalog.keys,keyboardEditor,cancelRecording:()=>stopChord?.(),changed:afterEdit,notice:message});
 }else if(inputID==='key:0:3'){
  aside.append(node('h3','Switch keyboard modes'),node('p','Press the knob to switch between Work, Dota and Wardogs. Editing a layer here does not change the active keyboard mode.',{class:'hint'}));
  const advanced=node('details');advanced.append(node('summary','Change knob assignment'));
  advanced.append(node('p','Changing this assignment replaces the mode switch on this layer.',{class:'hint'}));
  keyboardEditor(advanced,getControl(target,targetLayer,inputID),assign);aside.append(advanced);
 }else{
  keyboardEditor(aside,getControl(target,targetLayer,inputID),assign);
  const row=actionRow(aside);button('Use lower layer',()=>assign('KC_TRNS'),row);button('Do nothing',()=>assign('KC_NO'),row);
 }
 aside.append(test);drawTest();
 function drawTest(){
  test.replaceChildren(node('h3','Test this button'));
  if(inputID==='key:0:3'&&displayKey(getControl(target,targetLayer,inputID)).startsWith('Switch to ')){test.append(node('p','A mode switch does not send a keyboard key. To check the change, test a button whose assignments differ between your modes.',{class:'hint'}));return;}
  if(buttonBinding(target,targetLayer,inputID)){
   test.append(node('p','Save your changes, then leave Studio and press this button on KLAWOS. Mac actions resume when Studio is hidden.',{class:'hint'}));
   button('Hide Studio to test',async()=>{
    if(changes(target).length)throw Error('Save your changes to keyboard before testing this button.');
    const status=await request('helperStatus');if(!['running','paused'].includes(status.state)){tab='Mac helper';render();message('Turn on Mac actions, then return to your button to test.');return;}
    message('Press '+controlName(inputID)+' on KLAWOS. Open Studio again when you are finished.');await request('hideForTest');
   },actionRow(test));
  }else{
   recordShortcut(test,'Test keyboard output',5,()=>{},{captureEscape:true,success:keys=>`Received: ${displayKey(keyboardShortcutCode(keys))}. Your settings are unchanged.`});
   test.append(node('p','Save first and use the knob to choose the matching keyboard mode. This test reads the keys KLAWOS sends, including Escape.',{class:'hint'}));
  }
 }
}
function recordShortcut(parent,title,maxKeys,onCapture,options={}){
 const row=actionRow(parent),start=button(title,begin,row),cancel=button(options.captureEscape?'Cancel test':'Cancel recording',()=>stopChord?.(),row);cancel.hidden=true;
 function begin(){
  if(stopChord||writing)return;
  const target=draft,targetLayer=layer,inputID=selected,page=tab,generation=editGeneration;
  let session;
  const cancelSession=()=>session.cancel();
  stopChord=cancelSession;
  session=createShortcutRecording({send:request,maxKeys,captureEscape:options.captureEscape,capture:onCapture,
   isCurrent:()=>draft===target&&layer===targetLayer&&selected===inputID&&tab===page&&editGeneration===generation&&!writing,
   onState:phase=>{const idle=phase==='idle';start.disabled=!idle;start.textContent=idle?title:'Press keys together…';cancel.hidden=idle;if(idle&&stopChord===cancelSession)stopChord=null;$('apply').disabled=!idle||writing||!changes(draft).length;},
   notice:message,success:options.success,prompt:options.prompt,
  });
  return session.start();
 }
}
function updateControlLabels(){document.querySelectorAll('[data-control]').forEach(b=>{const id=b.dataset.control;b.textContent=(id==='key:0:3'?'◉ ':id.startsWith('encoder')?'↻ ':'')+displayControl(id);b.title=controlLabel(id);b.setAttribute('aria-label',controlLabel(id)+': '+displayControl(id));});}
function render(){stopChord?.();for(const option of $('layer').options)option.textContent=layerName(draft,Number(option.value));stopTools?.();stopTools=null;viewer?.dispose();viewer=null;$('heading').textContent=tab==='Keymap'?'Your keys':tabLabel(tab);$('layer-control').hidden=tab!=='Keymap';$('content').replaceChildren();$('content').className=tab==='Keymap'?'':'content-page';document.querySelectorAll('#tabs button').forEach(b=>{b.classList.toggle('active',b.dataset.tab===tab);if(b.dataset.tab===tab)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current')});if(!draft){const empty=node('div','',{class:'empty'});empty.append(node('h2','Set up your KLAWOS'),node('p','Plug in KLAWOS, close Vial, then click Connect.'));button('Connect',connect,empty,'primary');$('content').append(empty);renderInspector();return;}
 const content=$('content');if(tab==='Keymap'){
 const stage=node('div','',{class:'board-stage'});content.append(stage);const tools=node('div','',{class:'view-tools'});const views=[];for(const [title,top] of [['3D',false],['Top',true]]){const control=button(title,()=>{topView=top;viewer?.view(top);for(const [button,value] of views)button.setAttribute('aria-pressed',String(value===topView))},tools);control.setAttribute('aria-pressed',String(top===topView));views.push([control,top]);}stage.append(tools,node('span','3D preview · not live lighting',{class:'preview-tag'}));try{viewer=mountBoard(stage,select);viewer.view(topView)}catch(e){stage.append(node('p','The 3D view could not load. You can still use the keys below.'));}
 const grid=node('div','',{class:'controls'}),rotation=node('div','',{class:'encoder-row'});for(const id of controlIDs()){const b=button('',()=>select(id),id.startsWith('encoder')?rotation:grid,'control'+(id==='key:0:3'?' knob':''));b.dataset.control=id;}content.append(grid,rotation,node('p','Drag to rotate · Scroll to zoom · Select a key to edit',{class:'caption'}));updateControlLabels();select(selected);
 }else if(tab==='Macros')renderMacros(content);else if(tab==='Lighting')renderLighting(content);else if(tab==='Tap dance')renderSlots(content,'tap_dance',['Tap once','Hold','Tap twice','Tap, then hold','Time to hold (ms)']);else if(tab==='Combos')renderSlots(content,'combo',['First key','Second key','Third key','Fourth key','Result']);else if(tab==='Key overrides')renderSlots(content,'key_override',null);else if(tab==='QMK settings')renderSettings(content);else if(tab==='Mac helper')stopTools=helperPanel(content,message);else if(tab==='Security')stopTools=securityPanel(content,message);else if(tab==='Matrix tester')stopTools=matrixPanel(content,message);else if(tab==='Recovery')renderRecovery(content);else renderDevice(content);renderInspector();}
function slotPicker(parent,count,change,itemName=i=>'Item '+(i+1)){const row=node('div','',{class:'slot-select'});const sel=node('select');for(let i=0;i<count;i++)sel.append(node('option',itemName(i),{value:i}));label('Editing',sel,row);sel.onchange=()=>change(Number(sel.value));parent.append(row);return sel;}
function renderSlots(content,field,names){const entries=draft.hardware[field];if(!entries?.length){content.append(node('p','This keyboard does not support this feature.'));return}content.append(node('p',field==='tap_dance'?'Give the same key different actions when you tap or hold it.':field==='combo'?'Advanced: press several KLAWOS buttons together to trigger the Result below. To make one button send a shortcut, open Keys, select the button, then click Record shortcut.':'Change a key’s action when particular modifier keys are held. Numeric options are advanced firmware settings.'));if(field==='combo')button('Assign a shortcut to one button',()=>{tab='Keymap';render()},actionRow(content));const editor=node('div','',{class:'card'});const slotName=i=>combinationName(entries[i],i,layerNames.map((_,i)=>layerName(draft,i)),catalog.keys);const picker=slotPicker(content,entries.length,renderEntry,field==='combo'?slotName:field==='tap_dance'?i=>`Tap & hold ${i+1} · ${displayKey(entries[i][0])}`:i=>`Key replacement ${i+1}`);content.append(editor);function renderEntry(index){stopChord?.();const heading=node('h3',field==='combo'?slotName(index):`${tabLabel(tab)} · ${index+1}`);editor.replaceChildren(heading);const entry=entries[index];if(field==='tap_dance')renderAssignment(editor,field,index);const edited=()=>{changed();if(field==='combo'){picker.options[index].textContent=slotName(index);heading.textContent=slotName(index)}else if(field==='tap_dance')picker.options[index].textContent=`Tap & hold ${index+1} · ${displayKey(entry[0])}`};for(const [key,value] of Object.entries(entry)){const numeric=typeof value==='number'&&!(field==='combo')&&(field==='tap_dance'?Number(key)===4:!['trigger','replacement'].includes(key));label(names?names[Number(key)]:replacementLabels[key]??key.replaceAll('_',' '),numeric?input(value,'number',v=>{entry[key]=v;edited()}):keyInput(value,v=>{entry[key]=v;edited()}),editor);}if(field==='combo'){recordShortcut(editor,'Record keys together',4,keys=>{for(let i=0;i<4;i++)entry[String(i)]=keys[i]??'KC_NO';edited();renderEntry(index)});recordShortcut(editor,'Record result shortcut',5,keys=>{entry[4]=keyboardShortcutCode(keys);edited();renderEntry(index)})}editor.append(node('p','Changes reach your keyboard only when you click Save to keyboard.',{class:'hint'}));}renderEntry(0);}
function renderAssignment(parent,field,index){
 const used=slotUses(draft,field,index,catalog.keys);parent.append(node('p',used.length?'Used by: '+used.map(use=>`${layerName(draft,use.layer)} · ${controlName(use.id)}`).join(', '):'Not assigned to a button yet.',{class:'hint'}));
 const details=node('details');details.append(node('summary','Assign to a button'));parent.append(details);
 const mode=node('select');draft.hardware.layout.forEach((_,i)=>mode.append(node('option',layerName(draft,i),{value:i})));mode.value=layer;label('Layer',mode,details);
 const key=node('select');for(const id of controlIDs().filter(id=>id.startsWith('key:')&&id!=='key:0:3'))key.append(node('option',controlName(id),{value:id}));if(selected!=='key:0:3'&&selected.startsWith('key:'))key.value=selected;label('Button',key,details);
 details.append(node('p','Replaces this button’s current action. You can review the change before saving.',{class:'hint'}));
 button('Assign to this button',()=>{assignSlot(draft,field,index,Number(mode.value),key.value);layer=Number(mode.value);$('layer').value=layer;selected=key.value;changed();tab='Keymap';render();message('Assigned. Click Save to keyboard to use it on KLAWOS.');},actionRow(details));
}
function renderMacros(content){const target=draft;let recordTimer,recording=false,disposed=false,finishActiveRecording;stopTools=()=>{disposed=true;clearTimeout(recordTimer);if(recording)request('recordingStop').then(result=>finishActiveRecording?.(result)).catch(e=>{recording=false;recordingMacro=false;message(e.message,true)});};const editor=node('div','',{class:'card'});let slot=0;const picker=slotPicker(content,draft.hardware.macro.length,i=>{if(recording){picker.value=slot;message('Stop recording before choosing another macro.',true);return;}slot=i;draw()},i=>`Macro ${i+1} · ${draft.hardware.macro[i].length} steps`);content.append(editor);function draw(){picker.options[slot].textContent=`Macro ${slot+1} · ${draft.hardware.macro[slot].length} steps`;editor.replaceChildren(node('h3','Macro '+(slot+1)));renderAssignment(editor,'macro',slot);const usage=node('p','Checking space…',{class:'hint'});editor.append(usage);request('macroUsage',draft).then(value=>{usage.textContent=`${value.used} / ${value.available} bytes used by your macros`;}).catch(e=>{usage.textContent=e.message;});const events=draft.hardware.macro[slot];events.forEach((event,index)=>{const row=node('div','',{class:'macro-event'}),type=node('select');for(const name of ['text','tap','down','up','delay'])type.append(node('option',macroLabels[name],{value:name}));type.setAttribute('aria-label','Step type');type.value=event[0];type.onchange=()=>{events[index]=[type.value,type.value==='delay'?100:type.value==='text'?'':'KC_A'];changed();draw()};row.append(type);const shown=event[0]==='delay'||event[0]==='text'?event.slice(1).join(', '):event.slice(1).map(displayKey).join(' + ');const value=input(shown,event[0]==='delay'?'number':'text',v=>{events[index]=macroStep(event[0],v,s=>parseKeyChoice(s,'',layerNames.map((_,i)=>layerName(draft,i)),catalog.keys));changed();picker.options[slot].textContent=`Macro ${slot+1} · ${events.length} steps`});if(event[0]==='delay'){value.min=0;value.max=65024;}value.setAttribute('aria-label','Step value');row.append(value);const up=button('↑',()=>{if(index){[events[index-1],events[index]]=[events[index],events[index-1]];changed();draw()}},row);up.setAttribute('aria-label','Move step up');button('↓',()=>{if(index<events.length-1){[events[index+1],events[index]]=[events[index],events[index+1]];changed();draw()}},row).setAttribute('aria-label','Move step down');button('×',()=>{events.splice(index,1);changed();draw()},row).setAttribute('aria-label','Remove step');editor.append(row)});const macroActions=actionRow(editor);button('+ Add step',()=>{events.push(['tap','KC_A']);changed();draw()},macroActions);
const recordButton=button('Record keys',async()=>{if(recording){const result=await request('recordingStop');finishRecording(result);}else{if(recordingMacro||stopChord)return;recording=true;recordingMacro=true;try{await request('recordingStart')}catch(error){recording=false;recordingMacro=false;throw error}if(disposed)return;recordButton.textContent='Stop recording';recordButton.classList.add('primary');message('Other shortcuts are paused while recording. Press Escape or Stop recording to finish.');pollRecording();}},macroActions);
function finishRecording(result){if(!recording)return;recording=false;recordingMacro=false;clearTimeout(recordTimer);if(draft!==target)return;events.push(...result.events);changed();if(!disposed)draw();message('Recording added. Check the steps before saving to your keyboard.');}
finishActiveRecording=finishRecording;
async function pollRecording(){if(disposed||!recording)return;try{const result=await request('recordingStatus');if(disposed||!recording)return;if(!result.active){finishRecording(result);return;}recordButton.textContent='Stop recording · '+result.eventCount+' steps';recordTimer=setTimeout(pollRecording,400);}catch(e){recording=false;recordingMacro=false;request('recordingStop').catch(()=>{});message(e.message,true);}}
editor.append(node('p',`${draft.base.capabilities.macroBytes} bytes available for all macros. If saving is locked, open Keyboard lock to unlock it.`,{class:'hint'}));editor.append(node('p','Recording stops when you leave this window. Nothing is sent to your keyboard until you save.',{class:'disabled-note'}));}draw();}
function renderLighting(content){const current=draft,rgb=current.lighting.vialrgb;if(!rgb){content.append(node('p','Lighting controls are not available for this keyboard.'));return}
 const original=structuredClone(current.lighting);const card=node('div','',{class:'card'});content.append(card);card.append(node('p','Changes apply to KLAWOS immediately and save automatically.',{class:'autosave-note'}));let busy=false;const fields=[];let restore;
 const live=liveLighting({base:()=>current.base,send:payload=>request('liveLighting',payload),saved:base=>{current.base=base;message('Lighting saved.');},error:e=>{message('Could not update the lights. '+e.message,true)},status:pending=>{busy=pending;if(restore)restore.disabled=busy||JSON.stringify(current.lighting)===JSON.stringify(original);for(const id of ['read','import','export','discard'])$(id).disabled=busy;document.querySelectorAll('#tabs button, #inspector input, #inspector button, #inspector select').forEach(control=>control.disabled=busy);if(!busy)changed();$('apply').disabled=busy||writing||!changes(draft).length;}});
 const hint=node('p','',{class:'hint'});
 const update=()=>{hint.textContent=lightingHint(rgb.mode,rgb.hsv[1],rgb.hsv[2]);clearTimeout(autosave);message('Updating lights…');live.update(current.lighting)};
 const effect=node('select');for(const id of rgb.effects)effect.append(node('option',lightingEffectName(id),{value:id}));effect.value=rgb.mode;effect.onchange=()=>{rgb.mode=Number(effect.value);update()};label('Effect',effect,card);fields.push(()=>effect.value=rgb.mode);
 for(const [name,index] of [['Color',0],['Color intensity',1],['Brightness',2]]){const field=input(rgb.hsv[index],'range');field.min=0;field.max=index===2?rgb.maximumBrightness:255;field.oninput=()=>{rgb.hsv[index]=Number(field.value);update()};label(name,field,card);fields.push(()=>field.value=rgb.hsv[index])}
 const speed=input(rgb.speed,'range');speed.min=0;speed.max=255;speed.oninput=()=>{rgb.speed=Number(speed.value);update()};label('Speed',speed,card);fields.push(()=>speed.value=rgb.speed);
 restore=button('Restore previous lighting',()=>{Object.assign(rgb,structuredClone(original.vialrgb));for(const refresh of fields)refresh();update();},actionRow(card));restore.disabled=true;card.append(node('p','Restore returns to the lighting from when you opened this page.',{class:'hint'}));
 hint.textContent=lightingHint(rgb.mode,rgb.hsv[1],rgb.hsv[2]);card.append(hint,node('p','The 3D preview does not show the current lighting.',{class:'hint'}));
}
function renderSettings(content){for(const tab of catalog.settings.tabs){const supported=tab.fields.filter(f=>Object.hasOwn(draft.hardware.settings,String(f.qsid)));if(!supported.length)continue;const card=node('div','',{class:'card'});card.append(node('h3',settingGroup(tab.name)));for(const f of supported){const row=node('div','',{class:'setting'});const value=draft.hardware.settings[f.qsid];if(f.type==='boolean'){const check=input('','checkbox');check.checked=!!(value&(1<<f.bit));check.onchange=()=>{const old=draft.hardware.settings[f.qsid];draft.hardware.settings[f.qsid]=check.checked?old|(1<<f.bit):old&~(1<<f.bit);changed()};label(settingLabel(f),check,row);}else{const field=input(value,'number',v=>{draft.hardware.settings[f.qsid]=v;changed()});if(f.min!==undefined)field.min=f.min;if(f.max!==undefined)field.max=f.max;label(settingLabel(f),field,row)}card.append(row)}content.append(card)}}
function renderDevice(content){const names=node('div','',{class:'card'});names.append(node('h3','Extra layer names'),node('p','Names are saved on this Mac and included when you export a project.'));for(let i=3;i<draft.hardware.layout.length;i++)label('Layer '+(i+1),input(layerName(draft,i),'text',value=>{draft.projectDocument??={};draft.projectDocument.metadata??={};draft.projectDocument.metadata.layerNames??=[...layerNames];draft.projectDocument.metadata.layerNames[i]=value.slice(0,80);changed();}),names);content.append(names);const exports=actionRow(content);button('Export for Vial',async()=>{await request('export',{...draft,format:'vil'});message('Vial file exported. To include Mac actions and layer names, use Export project.');},exports);button('Export support info',async()=>{const helper=await request('helperStatus');await request('diagnostics',{capabilities:draft.base.capabilities,permissions:helper.permissions,helperState:helper.state});message('Support info exported. It does not include your key assignments, macro text, or file locations.');},exports);const card=node('div','',{class:'card'});content.append(card);const i=draft.base.identity,c=draft.base.capabilities;for(const [k,v] of Object.entries({'Keyboard ID':i.uid,'Vial version':i.vialProtocol,'Layers':c.layers,'Key grid':`${c.rows} × ${c.cols}`,'Macros':c.macroSlots,'Macro storage':`${c.macroBytes} bytes`,'Tap & hold actions':c.tapDanceSlots,'Key combinations':c.comboSlots,'Key replacements':c.keyOverrideSlots,'Alternate repeat':c.altRepeatSlots===0?'Not supported':c.altRepeatSlots})){const row=node('div','',{class:'stat'});row.append(node('span',k),node('code',String(v)));card.append(row)}card.append(node('p','Choosing a layer here only changes what you edit. Use the knob to switch layers on the keyboard.',{class:'hint'}));content.append(node('p','Firmware updates and factory reset are not available in this version.',{class:'disabled-note'}));}
async function refreshSyncedSettings(){
 if(!draft||writing||stopChord||recordingMacro||changes(draft).length)return;
 const target=draft,generation=editGeneration;
 const current=()=>draft===target&&editGeneration===generation&&!writing&&!stopChord&&!recordingMacro&&!changes(target).length;
 const sync=await request('syncStatus');if(!current())return;
 if(sync.status.includes('conflict')||sync.status.includes('could not')){message(sync.status,true);return;}
 if(sync.status!=='Settings are synced with iCloud.')return;
 const profiles=await request('helperConfiguration');if(!current())return;
 const names=sync.layerNames;
 const profileChanged=JSON.stringify(target.profiles)!==JSON.stringify(profiles);
 const nameChanged=names.length&&JSON.stringify(target.projectDocument?.metadata?.layerNames)!==JSON.stringify(names);
 if(!profileChanged&&!nameChanged)return;
 if(profileChanged){target.profiles=structuredClone(profiles);target.baseProfiles=structuredClone(profiles)}
 if(nameChanged){target.projectDocument??={};target.projectDocument.metadata??={};target.projectDocument.metadata.layerNames=structuredClone(names)}
 await request('saveDraft',structuredClone(target));if(!current())return;render();
}
async function connect(){message('Loading your keyboard…');$('read').disabled=true;try{if(draft&&changes(draft).length){message('Save, export, or discard your changes before refreshing the keyboard.',true);return}const snapshot=await request('read');draft=createDraft(snapshot);const profiles=await request('helperConfiguration');draft.profiles=profiles;draft.baseProfiles=structuredClone(profiles);const saved=await request('loadDraft');draft=restoreDraft(snapshot,profiles,saved);if(changes(draft).length)message('Your unsaved keyboard changes are back. Review them before saving.');else message('Connected. Choose a key to edit.');$('connection').textContent='KLAWOS connected · '+snapshot.capabilities.layers+' layers';$('read').textContent='Refresh';render();$('count').textContent=changes(draft).length;$('apply').disabled=changes(draft).length===0;$('draft-status').textContent=changes(draft).length?'Changes restored':'Keyboard loaded';await refreshSyncedSettings()}catch(e){message(e.message,true);$('connection').textContent='Keyboard not connected'}finally{$('read').disabled=false}}
async function preview(){
 if(!draft||writing)return;if(stopChord||recordingMacro)throw Error('Stop recording before saving to your keyboard.');
 clearTimeout(autosave);writing=true;lockEditing(true);reviewedDraft=null;
 try{
  const submitted=structuredClone(draft);await request('saveDraft',submitted);message('Checking your changes…');
  const result=await request('preview',submitted);$('change-list').replaceChildren();
  for(const change of reviewRows(result.changes,submitted,catalog.keys,catalog.apps)){
   const div=node('div','',{class:'change'});div.append(node('strong',change.title),node('small','Before: '+change.before),node('div','After: '+change.after));$('change-list').append(div);
  }
  reviewedDraft=submitted;
 }finally{writing=false;lockEditing(false);}
 $('review').showModal();message('Check the changes below, then save.');
}
function lockEditing(locked){
 if(locked){editingLock=new Map([...document.querySelectorAll('input,select,textarea,button')].map(control=>[control,control.disabled]));for(const control of editingLock.keys())control.disabled=true;}
 else{for(const [control,disabled] of editingLock??[])control.disabled=disabled;editingLock=null;}
}
async function apply(){
 if(writing||stopChord||recordingMacro){if(recordingMacro)message('Stop recording before saving to your keyboard.',true);return;}
 if(reviewedDraft&&JSON.stringify(reviewedDraft)!==JSON.stringify(draft)){$('review').close();reviewedDraft=null;message('Your changes were updated. Click Save to keyboard to review them again.',true);return;}
 writing=true;lockEditing(true);$('review').close();message('Saving and checking your keyboard…');
 const submitted=structuredClone(reviewedDraft??draft);reviewedDraft=null;
 try{
  const projectDocument=submitted.projectDocument,recovering=submitted.recoveryID,profiles=structuredClone(submitted.profiles);
  const result=await request('apply',submitted);
  if(recovering)await request('resolveRecovery',{id:recovering});
  draft=createDraft(result.snapshot);if(projectDocument)draft.projectDocument=projectDocument;draft.profiles=profiles;draft.baseProfiles=structuredClone(profiles);
  await request('saveDraft',structuredClone(draft));
  message(Object.keys(profiles).length&&!['running','paused'].includes(result.helperState)?'Saved to keyboard. Turn on Mac actions to use them.':'Saved to keyboard.');$('draft-status').textContent='Saved to keyboard';$('count').textContent=0;
 }catch(error){message(error.message,true)}
 finally{writing=false;lockEditing(false);$('review').close();render();$('apply').disabled=!changes(draft).length;}
}
for(const name of tabs){const b=button(tabLabel(name),()=>{tab=name;render()},$('tabs'));b.dataset.tab=name;}layerNames.forEach((name,i)=>$('layer').append(node('option',name,{value:i})));$('layer').onchange=()=>{layer=Number($('layer').value);render()};$('read').onclick=connect;$('apply').onclick=()=>preview().catch(e=>message(e.message,true));$('confirm-apply').onclick=apply;for(const id of ['close-review','cancel-apply'])$(id).onclick=()=>$('review').close();$('discard').onclick=async()=>{if(!draft)return;clearTimeout(autosave);draft=discardDraft(draft);await request('saveDraft',draft);render();$('apply').disabled=true;$('count').textContent=0;$('draft-status').textContent='No changes to save';message('Changes discarded. Your keyboard is unchanged.')};$('import').onclick=()=>{if(!draft){message('Connect your keyboard before importing a file.',true);return}request('import',{base:draft.base}).then(data=>{Object.assign(draft,data);changed();render();message('File imported. Review the changes before saving to your keyboard.')}).catch(e=>message(e.message,true))};$('export').onclick=()=>{if(!draft)return;request('export',draft).then(()=>message('Project exported.')).catch(e=>message(e.message,true))};
request('catalog').then(async data=>{catalog=data;catalog.apps=(await appCatalog).apps;updateControlLabels();const fragment=document.createDocumentFragment(),counts=new Map();for(const key of catalog.keys){const name=displayKey(key.code);counts.set(name,(counts.get(name)??0)+1)}for(const key of catalog.keys){const name=displayKey(key.code);if(counts.get(name)===1)fragment.append(node('option','',{value:name}))}$('keycodes').append(fragment)}).catch(e=>message(e.message,true));render();
setInterval(()=>refreshSyncedSettings().catch(e=>message(e.message,true)),10000);
window.addEventListener('klawos-sync-resolved',()=>refreshSyncedSettings().catch(e=>message(e.message,true)));

async function renderRecovery(content){try{const entries=await request('recoveries');if(!entries.length){content.append(node('p','No interrupted saves to restore. Your backups are kept on this Mac.'));return;}for(const entry of entries){const card=node('div','',{class:'card'});card.append(node('h3','Interrupted save'),node('p',entry.regions.map(r=>changeTitle(r,layerNames.map((_,i)=>layerName(draft,i)))).join(', ')||'The save stopped before any keyboard changes were sent.'));const recoveryActions=actionRow(card);for(const [title,choice] of [['Keep keyboard as it is','keepCurrent'],['Finish this save','completeIntended'],['Undo this save','restoreChangedRegions']])button(title,async()=>{const recovered=await request('recover',{id:entry.id,choice});if(choice==='keepCurrent'){await request('resolveRecovery',{id:entry.id});draft=createDraft(recovered.base);draft.profiles=recovered.profiles;draft.baseProfiles=recovered.baseProfiles;message('Kept the settings currently on your keyboard.')}else{draft=recovered;message('Restore options loaded. Review the changes before saving.')}await request('saveDraft',draft);tab='Keymap';render();$('count').textContent=changes(draft).length;$('apply').disabled=!changes(draft).length;},recoveryActions);content.append(card)}}catch(e){message(e.message,true)}}
