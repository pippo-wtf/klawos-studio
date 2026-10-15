"""Durable, sequential device saves. A failed exchange is never retried blindly."""
import copy,json,os,uuid
from pathlib import Path
from .diff import plan_changes,merge_snapshot,_value,_semantic_persistent
from .model import canonical_revision

class RecoveryRequired(RuntimeError):
    def __init__(self,transaction):
        super().__init__('The save was interrupted. Open Restore to check what changed and finish or undo the save.')
        self.transaction=transaction

def durable_json(path,value):
    path=Path(path)
    with open(path,'xb') as f:
        os.fchmod(f.fileno(),0o600)
        f.write(json.dumps(value,sort_keys=True,allow_nan=False).encode())
        f.flush();os.fsync(f.fileno())
    sync_directory(path.parent)

def sync_directory(path):
    fd=os.open(path,os.O_RDONLY)
    try:os.fsync(fd)
    finally:os.close(fd)

class ApplyCoordinator:
    def __init__(self,store,read,write,validate=None,context=None):
        self.store=Path(store);self.read=read;self.write=write;self.validate=validate;self.context=copy.deepcopy(context or {})
    def apply(self,base,desired):
        if self.validate:self.validate(desired)
        actual=self.read()
        actual.metadata.update(self.context)
        plan=plan_changes(actual,desired,base)
        wanted=merge_snapshot(base,actual,desired).snapshot
        if self.validate:self.validate(wanted)
        expected_values=_semantic_persistent(actual);wanted_values=_semantic_persistent(wanted)
        if not plan.operations:return {'status':'verified','snapshot':actual.to_wire(),'transaction':None}
        self.store.mkdir(parents=True,exist_ok=True,mode=0o700)
        directory=self.store/str(uuid.uuid4());directory.mkdir(mode=0o700)
        sync_directory(self.store)
        durable_json(directory/'before.json',actual.to_wire())
        durable_json(directory/'desired.json',wanted.to_wire())
        with open(directory/'journal.jsonl','xb') as journal:
            os.fchmod(journal.fileno(),0o600)
            def record(state,**fields):
                journal.write(json.dumps({'state':state,**fields},sort_keys=True).encode()+b'\n')
                journal.flush();os.fsync(journal.fileno())
            record('prepared',sourceRevision=plan.source_revision)
            sync_directory(directory)
            try:
                for op in plan.operations:
                    path='hardware.macro' if op.region_id=='macro' else op.region_id
                    fresh=self.read()
                    if fresh.identity!=actual.identity or fresh.metadata.get('descriptor')!=actual.metadata.get('descriptor'):
                        raise ValueError('Device identity or connection changed')
                    observed=_value(_semantic_persistent(fresh),path)
                    if observed==_value(wanted_values,path):
                        record('verified',operationID=op.operation_id,region=path);continue
                    if observed!=_value(expected_values,path):raise ValueError('Device changed before writing')
                    record('writeIntent',operationID=op.operation_id,region=path)
                    try:self.write(op)
                    except Exception:
                        # The command may have reached the keyboard. Read; never resend.
                        record('ambiguousWrite',operationID=op.operation_id)
                    verified=self.read()
                    if verified.identity!=actual.identity or verified.metadata.get('descriptor')!=actual.metadata.get('descriptor'):
                        raise ValueError('Device connection changed during write')
                    if _value(_semantic_persistent(verified),path)!=_value(wanted_values,path):raise ValueError('Readback mismatch')
                    record('verified',operationID=op.operation_id,region=path)
                final=self.read()
                if final.identity!=actual.identity or final.metadata.get('descriptor')!=actual.metadata.get('descriptor'):
                    raise ValueError('Device connection changed at final verification')
                if _semantic_persistent(final)!=wanted_values:raise ValueError('Final device state changed')
                record('complete',revision=canonical_revision(final))
                return {'status':'verified','snapshot':final.to_wire(),'transaction':directory.name}
            except Exception as error:
                record('recoveryRequired')
                raise RecoveryRequired(directory.name) from error
