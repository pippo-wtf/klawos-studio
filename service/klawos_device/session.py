"""Selected native transport with request correlation and no mutation retries."""
import json,select,subprocess,uuid
from .features import select_descriptor,read_snapshot

class DeviceSession:
    def __init__(self,binary,path=None,writable=False,security=False):
        listing=subprocess.run([str(binary),'--list'],capture_output=True,text=True,timeout=10,check=True)
        self.descriptor=select_descriptor(json.loads(listing.stdout),path)
        self.process=subprocess.Popen([str(binary),'--security' if security else '--configure' if writable else '--exchange',self.descriptor['pathToken']],
            stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,bufsize=0)
        try:
            if self.line()!=self.descriptor:raise ValueError('Device connection changed')
        except Exception:self.close();raise
    def line(self):
        # Unbuffered reads avoid select() losing data already in a Python read-ahead buffer.
        result=bytearray()
        while len(result)<8192:
            if not select.select([self.process.stdout],[],[],4)[0]:raise TimeoutError('Keyboard did not respond')
            char=self.process.stdout.read(1)
            if not char:raise ConnectionError('Keyboard connection ended')
            if char==b'\n':return json.loads(result)
            result+=char
        raise ValueError('Oversized transport response')
    def exchange(self,report):
        request=str(uuid.uuid4())
        self.process.stdin.write(json.dumps({'requestID':request,'report':report.hex()}).encode()+b'\n')
        response=self.line()
        if response.get('requestID')!=request or response.get('error'):raise ConnectionError('Keyboard exchange failed')
        raw=bytes.fromhex(response['report'])
        if len(raw)!=32:raise ValueError('Incomplete keyboard response')
        return raw
    def read(self):return read_snapshot(self.exchange,self.descriptor)
    def close(self):
        if self.process.poll() is None:self.process.terminate()
        try:self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:self.process.kill();self.process.wait()
    def __enter__(self):return self
    def __exit__(self,*args):self.close()
