"""One-use native HID readback bridge. No Vial UI or global Python installation."""
import argparse,json,subprocess,uuid,sys,os,select
from pathlib import Path
from .features import read_snapshot,select_descriptor

def probe(binary: Path, path_token: str | None, output: Path):
    listing=subprocess.run([str(binary),'--list'],capture_output=True,text=True,timeout=10,check=True)
    devices=json.loads(listing.stdout)
    descriptor=select_descriptor(devices,path_token)
    process=subprocess.Popen([str(binary),'--exchange',descriptor['pathToken']],stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
    try:
        if not select.select([process.stdout],[],[],4)[0]: raise TimeoutError('Raw HID interface open timed out')
        ready=process.stdout.readline()
        if not ready: raise RuntimeError('Raw HID interface could not be opened')
        opened=json.loads(ready)
        if opened!=descriptor: raise RuntimeError('Selected device generation changed before opening')
        def exchange(report):
            if process.poll() is not None: raise RuntimeError('Native HID probe exited')
            request_id=str(uuid.uuid4())
            process.stdin.write(json.dumps({'requestID':request_id,'report':report.hex()},separators=(',',':'))+'\n')
            process.stdin.flush()
            if not select.select([process.stdout],[],[],4)[0]: raise TimeoutError('HID exchange timed out')
            line=process.stdout.readline()
            if not line: raise RuntimeError('HID response stream ended')
            response=json.loads(line)
            if response.get('requestID')!=request_id or response.get('error'):
                raise RuntimeError('HID exchange failed or correlation changed')
            result=bytes.fromhex(response['report'])
            if len(result)!=32: raise ValueError('Short HID response')
            return result
        snapshot=read_snapshot(exchange,descriptor)
        # Only a user-specified project-local ignored readback path is accepted.
        output=output.resolve(); project=Path(__file__).resolve().parents[2]
        if not output.is_relative_to(project/'configs'): raise ValueError('Readback output must be inside project configs')
        output.parent.mkdir(parents=True,exist_ok=True)
        raw=json.dumps(snapshot.to_wire(),sort_keys=True,indent=2).encode()
        temp=output.with_name(output.name+'.tmp')
        with open(temp,'xb') as file:
            os.fchmod(file.fileno(),0o600);file.write(raw);file.flush();os.fsync(file.fileno())
        os.replace(temp,output)
        return {'uid':snapshot.identity.uid,'revision':snapshot.to_wire()['revision'],'capabilities':{
            key:value for key,value in snapshot.capabilities.items() if key!='definition'},
            'readPackets':snapshot.metadata['readPackets'],'pathToken':descriptor['pathToken']}
    finally:
        if process.poll() is None: process.terminate()
        try: process.wait(timeout=3)
        except subprocess.TimeoutExpired: process.kill();process.wait()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--probe-binary',type=Path,required=True)
    parser.add_argument('--path');parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    try: print(json.dumps(probe(args.probe_binary,args.path,args.output),sort_keys=True))
    except Exception as error: print(f'KLAWOS readback failed: {error}',file=sys.stderr);return 1
    return 0
if __name__=='__main__': sys.exit(main())
