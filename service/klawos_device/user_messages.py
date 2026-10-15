"""Plain-language messages at the app boundary; validation stays unchanged."""
def user_message(error):
    text=str(error)
    if not isinstance(error,ValueError):
        return 'Could not reach KLAWOS. Close Vial, reconnect your keyboard, then try again.'
    if text.startswith('Conflicting device edits:'):
        return 'The keyboard changed in another app. Export your changes, then refresh the keyboard before saving.'
    if 'Macro buffer exceeds' in text:
        return 'Your macros need more space than the keyboard has. Shorten or remove a macro, then try again.'
    if 'Unlock the keyboard' in text:
        return 'Open Keyboard lock and unlock the settings, then save your macros again.'
    if any(word in text for word in ['Different keyboard','Different device','another device','another keyboard','UID mismatch']):
        return 'This file belongs to a different keyboard. Choose a file made for this KLAWOS.'
    if any(word in text for word in ['revision','Reload the draft']):
        return 'These saved changes could not be checked. Export a copy, then refresh the keyboard before trying again.'
    if any(word in text for word in ['capacity differs','count differs','layers differ','Layer count','Matrix differs']):
        return 'This file does not match your keyboard’s keys or available settings. Choose a compatible file.'
    if any(word in text for word in ['keycode','key code']):
        return 'That key or shortcut is not recognized. Choose one from the list or check its Vial key code.'
    if 'QMK setting' in text:
        return 'A keyboard setting is outside its allowed range. Check the value in Keyboard settings.'
    if any(word in text for word in ['Unsupported project version','Unsupported Vial']):
        return 'This version is not supported yet. Use a compatible project or a Vial export.'
    if 'size' in text or 'Oversized' in text:
        return 'This file is too large. Choose a keyboard project smaller than 4 MB.'
    if any(word in text for word in ['JSON','Missing','Invalid keyboard','Invalid lossless','object payload']):
        return 'This file could not be read. Choose a valid KLAWOS project or Vial file.'
    if any(word in text for word in ['Executable','Unsupported action','Local secrets']):
        return 'This file contains actions or private settings the app cannot import. Choose another file.'
    if 'printable ASCII' in text:
        return 'Macro text supports printable ASCII only. Use key steps for Tab, Enter, or shortcuts.'
    if 'cannot be stored' in text:
        return 'This key or macro cannot be stored safely. Choose another key step.'
    if 'macro delay' in text:
        return 'A wait time in this macro is not valid. Enter a supported number of milliseconds.'
    if 'macro' in text.lower():
        return 'A macro step could not be read. Check its action and value, then try again.'
    if any(word in text.lower() for word in ['lighting','brightness']):
        return 'These lighting settings are not supported. Choose an available effect and check the slider values.'
    if 'tap dance' in text:
        return 'Check the keys and hold time in Tap & hold, then try again.'
    if 'combo' in text:
        return 'Check the keys in Key combinations, then try again.'
    if 'key override' in text:
        return 'Check the keys and numeric options in Key replacements, then try again.'
    if 'recovery' in text.lower():
        return 'This backup could not be opened. Return to Restore and choose it again.'
    if 'read-only' in text or 'Unknown hardware' in text or 'Unsupported write region' in text:
        return 'This setting can be viewed but cannot be changed in this version.'
    if any(word in text for word in ['connection','response','Select one connected']):
        return 'Could not read KLAWOS. Connect one keyboard, close Vial, then click Refresh.'
    return 'These settings could not be used. Check your changes and try again.'
