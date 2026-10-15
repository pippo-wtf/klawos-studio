const modifiers=new Set(['KC_LGUI','KC_RGUI','KC_LCTL','KC_RCTL','KC_LALT','KC_RALT','KC_LSFT','KC_RSFT']);

export function recordingComplete(events){
 const held=new Set();let sawBaseKey=false;
 for(const [kind,code] of events){
  if(kind==='down'){held.add(code);if(!modifiers.has(code))sawBaseKey=true}
  if(kind==='up')held.delete(code);
 }
 return sawBaseKey&&held.size===0;
}

export function recordedChord(events,maxKeys=4){
 const keys=[];
 for(const [kind,code] of events){
  if(kind==='up'&&!modifiers.has(code))break;
  if(kind==='down'&&!keys.includes(code))keys.push(code);
 }
 if(!keys.length)throw new Error('No keys were recorded. Try again or choose them by name.');
 if(keys.length>maxKeys)throw new Error(`Record at most ${maxKeys===4?'four':maxKeys} keys together.`);
 return keys;
}

export function keyboardShortcutCode(keys){
 const bases=keys.filter(code=>!modifiers.has(code));
 if(bases.length!==1)throw new Error('Include one letter or key with any modifiers.');
 return keys.filter(code=>modifiers.has(code)).reverse().reduce((code,mod)=>`${mod.slice(3)}(${code})`,bases[0]);
}

export function directChord(event){
 const modifiers=[];
 if(event.ctrlKey)modifiers.push('KC_LCTL');
 if(event.altKey)modifiers.push('KC_LALT');
 if(event.metaKey)modifiers.push('KC_LGUI');
 if(event.shiftKey)modifiers.push('KC_LSFT');
 const code=event.code??'';
 if(/^(Control|Alt|Shift|Meta)(Left|Right)$/.test(code))return [];
 let base;
 if(/^Key[A-Z]$/.test(code))base='KC_'+code.slice(3);
 else if(/^Digit[0-9]$/.test(code))base='KC_'+code.slice(5);
 else if(/^F([1-9]|1[0-9]|2[0-4])$/.test(code))base='KC_'+code;
 else base=({Space:'KC_SPACE',Enter:'KC_ENTER',Tab:'KC_TAB',Backspace:'KC_BSPACE',Escape:'KC_ESCAPE',Minus:'KC_MINUS',Equal:'KC_EQUAL',BracketLeft:'KC_LBRACKET',BracketRight:'KC_RBRACKET',Semicolon:'KC_SEMICOLON',Quote:'KC_QUOTE',Backslash:'KC_BSLASH',Comma:'KC_COMMA',Period:'KC_DOT',Slash:'KC_SLASH',Backquote:'KC_GRAVE',ArrowLeft:'KC_LEFT',ArrowRight:'KC_RIGHT',ArrowUp:'KC_UP',ArrowDown:'KC_DOWN',Home:'KC_HOME',End:'KC_END',PageUp:'KC_PGUP',PageDown:'KC_PGDN',Delete:'KC_DELETE'})[code];
 return base?[...modifiers,base]:null;
}
