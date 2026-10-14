// These presets use the installed apps' documented Mac shortcuts. Saved actions
// retain their native descriptors, so they also work on the user's other Mac.
const chatgpt='com.openai.codex',claude='com.anthropic.claudefordesktop';
const appKey=(bundleID,keyCode,modifiers)=>({kind:'appShortcut',parameters:{bundleID,keyCode,modifiers}});
export const appShortcuts=[
 {id:'chatgpt.quick-chat',app:'ChatGPT',name:'Quick Chat',keys:'Option + Space',global:true,action:{kind:'shortcut',parameters:{keyCode:49,modifiers:['option']}},hint:'Uses ChatGPT’s default Quick Chat shortcut. If you changed it in ChatGPT, use Custom keyboard shortcut.'},
 {id:'chatgpt.new-chat',app:'ChatGPT',name:'New conversation',keys:'Command + N',action:appKey(chatgpt,45,['command']),hint:'Creates a conversation in the ChatGPT view currently open (Chat, Work or Codex).'},
 {id:'chatgpt.sidebar',app:'ChatGPT',name:'Show or hide sidebar',keys:'Command + B',action:appKey(chatgpt,11,['command'])},
 {id:'chatgpt.browser',app:'ChatGPT',name:'Open browser',keys:'Command + Shift + B',action:appKey(chatgpt,11,['command','shift'])},
 {id:'claude.new-chat',app:'Claude',name:'New chat',keys:'',action:{kind:'openURL',parameters:{url:'claude://claude.ai/new'}},hint:'Opens a new Claude chat from any app.'},
 {id:'claude.new-session',app:'Claude',name:'New Code session',keys:'Command + N',action:appKey(claude,45,['command']),hint:'Available in Claude’s Code view.'},
 {id:'claude.next-session',app:'Claude',name:'Next Code session',keys:'Control + Tab',action:appKey(claude,48,['control']),hint:'Available in Claude’s Code view.'},
 {id:'claude.previous-session',app:'Claude',name:'Previous Code session',keys:'Control + Shift + Tab',action:appKey(claude,48,['control','shift']),hint:'Available in Claude’s Code view.'},
 {id:'claude.diff',app:'Claude',name:'Show or hide changes',keys:'Command + Shift + D',action:appKey(claude,2,['command','shift']),hint:'Available in Claude’s Code view.'},
 {id:'claude.browser',app:'Claude',name:'Show or hide browser',keys:'Command + Shift + B',action:appKey(claude,11,['command','shift']),hint:'Available in Claude’s Code view.'},
];
export function presetAction(id){const preset=appShortcuts.find(p=>p.id===id);return preset?{id:`preset.${id}`,...structuredClone(preset.action)}:null;}
export function presetForAction(action){return appShortcuts.find(p=>action?.id===`preset.${p.id}`&&action.kind===p.action.kind&&Object.keys(p.action.parameters).length===Object.keys(action.parameters??{}).length&&Object.entries(p.action.parameters).every(([key,value])=>JSON.stringify(action.parameters[key])===JSON.stringify(value)));}
export function presetName(action){const p=presetForAction(action);return p?`${p.app}: ${p.name}`:null;}
