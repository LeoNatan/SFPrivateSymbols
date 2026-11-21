import sys,struct,subprocess
f=sys.argv[1]; data=open(f,'rb').read()
out=subprocess.run(['otool','-l',f],capture_output=True,text=True).stdout.split('\n')
secs={}; segs=[]
for i,l in enumerate(out):
    if l.strip().startswith('sectname'):
        name=l.split()[1]; addr=int(out[i+2].split()[1],16); size=int(out[i+3].split()[1],16); off=int(out[i+4].split()[1]); secs[name]=(addr,size,off)
    if l.strip().startswith('segname') and out[i-2].strip().startswith('cmd LC_SEGMENT_64'):
        vm=int(out[i+1].split()[1],16); fo=int(out[i+3].split()[1]); segs.append((vm,fo,int(out[i+2].split()[1],16)))
def a2o(a):
    for vm,fo,sz in segs:
        if vm<=a<vm+sz: return a-vm+fo
    return None
def rel(a):
    o=a2o(a); v=struct.unpack('<i',data[o:o+4])[0]; return a+v if v else None
def cstr(a):
    o=a2o(a); e=data.index(b'\0',o); return data[o:e]
def ctxname(a):
    # context descriptor: flags(4) parent(rel4) name(rel4)
    n=rel(a+8); return cstr(n).decode(errors='replace') if n else '?'
def typename(a):
    if a is None: return ''
    o=a2o(a); b=data[o]
    if b in (1,2):
        t=rel(a+1)
        if b==2:  # indirect
            return '<ind>'
        return ctxname(t)
    return cstr(a).decode(errors='replace')
addr,size,off=secs['__swift5_fieldmd']
p=addr; kinds={0:'struct',1:'class',2:'enum',3:'multiPayloadEnum',4:'protocol',5:'classProtocol',6:'objcProtocol',7:'objcClass'}
while p<addr+size:
    tn=rel(p); k,rs,nf=struct.unpack('<HHI',data[a2o(p+8):a2o(p+8)+8])
    name=typename(tn) if tn else '?'
    fields=[]
    for i in range(nf):
        r=p+16+i*rs
        fn=rel(r+8); fields.append(cstr(fn).decode(errors='replace') if fn else '')
    if kinds.get(k,'?') in ('enum','multiPayloadEnum'):
        print('%s %s: %s'%(kinds.get(k), name, ', '.join(fields)))
    p+=16+nf*rs
