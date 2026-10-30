"""Single-request app worker. Native host supplies paths; UI supplies only bounded data."""
import argparse,copy,json,os,sys,uuid
from pathlib import Path
from .model import load_document,parse_snapshot,DeviceIdentity,canonical_revision,_safe_wire
from .user_messages import user_message
from .validation import validate_project,validate_metadata,_macro_bytes,_action_tree
from .writes import packets_for,validate_lighting
from .diff import plan_changes,merge_snapshot,_persistent,_value,_set
from .apply import ApplyCoordinator,RecoveryRequired,durable_json,sync_directory
from .session import DeviceSession
from .recovery import list_recoveries,directory_for,recovery_draft,resolve,prune_verified
from .vial.settings import QmkSettings
from .keycodes import _select,encode_keycode
from .vial.keycodes.keycodes import KEYCODES_MAP


def decode_wire(value):
    if isinstance(value,dict):
        if set(value)=={'$integer'}:
            import re
            text=value['$integer']
            if not isinstance(text,str) or not re.fullmatch(r'-?[0-9]{1,128}',text):raise ValueError('Invalid lossless integer')
            return int(text)
        return {k:decode_wire(v) for k,v in value.items()}
    if isinstance(value,list):return [decode_wire(v) for v in value]
    return value

def from_wire(wire):
    wire=decode_wire(wire)
    s=parse_snapshot(json.dumps(wire['hardware']).encode())
    i=wire['identity'];s.identity=DeviceIdentity(i['uid'],i['viaProtocol'],i['vialProtocol'],i.get('definitionHash',''))
    s.hardware['uid']=s.identity.uid
    s.lighting=wire.get('lighting',{});s.capabilities=wire.get('capabilities',{})
    s.metadata=wire.get('metadata',{});s.unreadable_fields=wire.get('unreadableFields',[])
    if wire.get('revision')!=canonical_revision(s):raise ValueError('Snapshot revision is stale or invalid')
    return s

def validate(base,desired):
    base=copy.deepcopy(base);desired=copy.deepcopy(desired)
    base.hardware['uid']=base.identity.uid
    if desired.identity!=base.identity or str(desired.hardware.get('uid'))!=base.identity.uid:raise ValueError('Different keyboard definition')
    desired.hardware['uid']=base.identity.uid
    data={'format_version':1,'identity':desired.identity.to_wire(),'hardware':desired.to_vil(),'lighting':desired.lighting,'profiles':{}}
    caps={**base.capabilities,'uid':base.identity.uid}
    validate_project(json.dumps(data).encode(),caps)
    validate_lighting(base.lighting,desired.lighting)
    # Precompile every operation before opening a writable transport.
    plan=plan_changes(base,desired,base)
    for op in plan.operations:packets_for(op,base.identity.vial_protocol)
    return plan

def handle(request,binary,store):
    op=request.get('operation');payload=decode_wire(request.get('payload',{}))
    if op=='catalog':
        _select(5)
        keys=[]
        for name,item in KEYCODES_MAP.items():
            entry={'code':name,'label':item.label,'description':item.tooltip or ''}
            try:entry['value']=encode_keycode(name,5)
            except ValueError:pass
            keys.append(entry)
        return {'keys':keys,'settings':QmkSettings.settings_defs}
    if op=='read':
        with DeviceSession(binary) as session:result=session.read().to_wire()
        return result
    if op=='liveLighting':
        from .live_lighting import update_lighting
        base=from_wire(payload['base'])
        with DeviceSession(binary,base.metadata['descriptor']['pathToken'],writable=True) as session:
            if session.descriptor.get('generation')!=base.metadata['descriptor'].get('generation'):raise ValueError('Device connection changed')
            update_lighting(base,payload['lighting'],payload['expected'],payload['persist'],session.exchange)
        base.lighting=copy.deepcopy(payload['lighting'])
        return {'base':base.to_wire()}
    if op in {'preview','apply'}:
        _action_tree(payload.get('profiles',{}))
        base=from_wire(payload['base']);desired=copy.deepcopy(base)
        desired.hardware=payload['hardware'];desired.lighting=payload['lighting']
        validate(base,desired)
        if op=='preview':
            with DeviceSession(binary,base.metadata['descriptor']['pathToken']) as session:actual=session.read()
            plan=plan_changes(actual,desired,base)
            validate(base,merge_snapshot(base,actual,desired).snapshot)
            return {'changes':[{'region':p.region_id,'before':p.expected_old,'after':p.desired_new} for p in plan.operations]}
        with DeviceSession(binary,base.metadata['descriptor']['pathToken'],writable=True) as session:
            def write(operation):
                # Macro memory requires explicit physical unlock; never unlock silently.
                if operation.region_id=='macro' and session.exchange(bytes([254,5]))[0]!=1:
                    raise ValueError('Unlock the keyboard in Security before saving macros')
                for packet in packets_for(operation,base.identity.vial_protocol):session.exchange(packet)
            result=ApplyCoordinator(store/'backups',session.read,write,lambda s:validate(base,s),context={'previousHelper':payload.get('previousHelper'),'intendedProfiles':payload.get('profiles',{})}).apply(base,desired)
            prune_verified(store)
            return result
    if op=='security':
        commands={'status':bytes([254,5]),'start':bytes([254,6]),'poll':bytes([254,7]),'lock':bytes([254,8]),'matrix':bytes([2,3])}
        action=payload.get('action')
        if action not in commands:raise ValueError('Unknown security action')
        with DeviceSession(binary,security=True) as session:
            response=session.exchange(commands[action])
            if action=='matrix':
                if response[:2]!=bytes([2,3]):raise ValueError('Invalid matrix response')
                # VIA matrix rows are big-endian bitfields, one byte for four columns.
                return {'rows':[response[2+r] for r in range(4)]}
            state=session.exchange(bytes([254,5]))
            return {'unlocked':state[0]==1,'inProgress':state[1]==1,'keys':[[state[i],state[i+1]] for i in range(2,32,2) if state[i]!=255 and state[i+1]!=255]}
    if op=='recoveries':return list_recoveries(store)
    if op=='recover':
        directory=directory_for(store,payload['id'])
        before=from_wire(load_document((directory/'before.json').read_bytes()))
        intended=from_wire(load_document((directory/'desired.json').read_bytes()))
        with DeviceSession(binary) as session:current=session.read()
        proposed=recovery_draft(before,intended,current,payload['choice'])
        profiles=copy.deepcopy(payload.get('currentProfiles',{}));baseline_profiles=copy.deepcopy(profiles)
        old=(before.metadata.get('previousHelper') or {}).get('configuration',{}).get('bindings',{})
        new=intended.metadata.get('intendedProfiles',{})
        if payload['choice']!='keepCurrent':
            target=new if payload['choice']=='completeIntended' else old
            for key in old.keys()|new.keys():
                if old.get(key)!=new.get(key):
                    if key in target:profiles[key]=copy.deepcopy(target[key])
                    else:profiles.pop(key,None)
        return {'base':current.to_wire(),'hardware':proposed.to_wire()['hardware'],'lighting':proposed.lighting,'profiles':profiles,'baseProfiles':baseline_profiles,'recoveryID':payload['id']}
    if op=='resolveRecovery':
        resolve(store,payload['id']);return {'resolved':True}
    if op=='macroUsage':
        base=from_wire(payload['base']);used=_macro_bytes(payload['hardware']['macro'],base.identity.vial_protocol)
        return {'used':used,'available':base.capabilities.get('macroBytes',0)}
    if op=='saveDraft':
        project=payload.get('projectDocument',{})
        if not isinstance(project,dict):raise ValueError('Invalid project metadata')
        validate_metadata(project.get('metadata',{}))
        base=from_wire(payload['base']);desired=copy.deepcopy(base)
        desired.hardware=payload['hardware'];desired.lighting=payload['lighting'];validate(base,desired)
        _action_tree(payload.get('profiles',{}))
        store.mkdir(parents=True,exist_ok=True,mode=0o700)
        temp=store/(str(uuid.uuid4())+'.tmp');durable_json(temp,_safe_wire(payload))
        os.replace(temp,store/'draft.json');sync_directory(store)
        return {'saved':True}
    if op=='loadDraft':
        path=store/'draft.json'
        return load_document(path.read_bytes()) if path.exists() else None
    if op=='import':
        base=from_wire(payload['base']);data=load_document(payload['document'].encode())
        if 'format_version' not in data:
            data={'format_version':1,'identity':base.identity.to_wire(),'hardware':data,'lighting':base.lighting,'profiles':{}}
        parsed=validate_project(json.dumps(data).encode(),{**base.capabilities,'uid':base.identity.uid})
        desired=copy.deepcopy(base);desired.hardware=parsed.snapshot.hardware;desired.hardware['uid']=base.identity.uid
        desired.lighting=parsed.snapshot.lighting;validate(base,desired)
        return _safe_wire({'hardware':desired.hardware,'lighting':desired.lighting,'profiles':data.get('profiles',{}),'projectDocument':parsed.document})
    if op=='export':
        base=from_wire(payload['base']);desired=copy.deepcopy(base)
        desired.hardware=payload['hardware'];desired.lighting=payload['lighting'];validate(base,desired)
        data=copy.deepcopy(payload.get('projectDocument',{}))
        data.update({'format_version':1,'identity':base.identity.to_wire(),'hardware':desired.to_vil(),'lighting':desired.lighting,'profiles':payload.get('profiles',{})})
        validate_project(json.dumps(data).encode(),{**base.capabilities,'uid':base.identity.uid})
        if payload.get('format')=='vil':data=desired.to_vil()
        return {'document':json.dumps(data,indent=2,ensure_ascii=False)}
    raise ValueError('Unsupported app operation')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--probe',required=True);parser.add_argument('--store',type=Path,required=True)
    args=parser.parse_args()
    try:
        request=load_document(sys.stdin.buffer.read(4*1024*1024+1))
        result=handle(request,args.probe,args.store)
        print(json.dumps({'ok':True,'result':result},allow_nan=False))
    except RecoveryRequired as error:
        print(json.dumps({'ok':False,'error':str(error),'recovery':error.transaction}))
    except Exception as error:
        # Only known validation text is shown; never forward a traceback or environment.
        message=user_message(error)
        print(json.dumps({'ok':False,'error':message}))
if __name__=='__main__':main()
