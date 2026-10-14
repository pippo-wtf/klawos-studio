"""Compare one ignored native readback with a fresh official Vial .vil export."""
import argparse,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'service'))
from klawos_device.model import parse_snapshot
parser=argparse.ArgumentParser();parser.add_argument('vial',type=Path);parser.add_argument('native',type=Path)
args=parser.parse_args()
vial=parse_snapshot(args.vial.read_bytes())
native=json.loads(args.native.read_text())
hardware=native['hardware']; hardware['uid']=int(hardware['uid'])
fields=sorted(set(vial.hardware)|set(hardware))
differences=[field for field in fields if vial.hardware.get(field)!=hardware.get(field)]
if vial.identity.uid != native['identity']['uid'] or differences:
    print('G1 comparison failed: '+','.join(differences));raise SystemExit(1)
print(f'G1 comparison passed: {len(fields)} exact Vial fields; UID exact; unreadable fields {len(native["unreadableFields"])}')
