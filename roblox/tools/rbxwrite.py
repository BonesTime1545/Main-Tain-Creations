"""Put edited scripts back into a .rbxl: only the "Source" chunks of the named scripts are
   rewritten, every other byte of the file stays as it was.
   python3 -s rbxwrite.py in.rbxl out.rbxl <dir with Name.lua files> Name1,Name2,...
   (needs: pip install lz4 zstandard)"""
import os, struct, sys, lz4.block, zstandard
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tree import parse
IN, OUT, NEWDIR = sys.argv[1], sys.argv[2], sys.argv[3]
if not NEWDIR.endswith("/"):
    NEWDIR += "/"
CHANGED = sys.argv[4].split(',')
classes,inst,props,parent = parse(IN)
byc={}
for r,c in inst.items(): byc.setdefault(c,[]).append(r)
# (class id) -> { index: new source }
want={}
for c,l in byc.items():
    if classes[c] in ('ModuleScript','LocalScript','Script'):
        for i,name in enumerate(props[(c,'Name')]):
            if name in CHANGED:
                want.setdefault(c,{})[i]=open(NEWDIR+name+'.lua',encoding='utf8',newline='').read().encode('utf8')
assert sum(len(v) for v in want.values())==len(CHANGED), (want.keys(), CHANGED)

d=open(IN,'rb').read()
out=bytearray(d[:32]); p=32; done=0
while p<len(d):
    name=d[p:p+4]; cl,ul,res=struct.unpack('<III',d[p+4:p+16]); hdr=d[p:p+16]; p+=16
    n=cl if cl else ul
    body=d[p:p+n]; p+=n
    rebuilt=None
    if name==b'PROP\0'[:4] or name.startswith(b'PROP'):
        raw=body
        if cl:
            raw = zstandard.ZstdDecompressor().decompress(body,max_output_size=ul) if body[:4]==b'\x28\xb5\x2f\xfd' else lz4.block.decompress(body,uncompressed_size=ul)
        cid,=struct.unpack_from('<I',raw,0)
        if cid in want:
            l,=struct.unpack_from('<I',raw,4); pn=raw[8:8+l].decode()
            if pn=='Source':
                q=8+l; t=raw[q]; assert t==1; q+=1
                vals=[]
                for _ in range(len(byc[cid])):
                    ln,=struct.unpack_from('<I',raw,q); q+=4; vals.append(raw[q:q+ln]); q+=ln
                assert q==len(raw)
                for i,src in want[cid].items(): vals[i]=src
                new=bytearray(raw[:8+l+1])
                for v in vals: new+=struct.pack('<I',len(v))+v
                new=bytes(new)
                comp=lz4.block.compress(new,store_size=False,mode='high_compression')
                if len(comp)<len(new):
                    rebuilt=name+struct.pack('<III',len(comp),len(new),0)+comp
                else:
                    rebuilt=name+struct.pack('<III',0,len(new),0)+new
                done+=len(want[cid])
    out+= rebuilt if rebuilt else hdr+body
    if name.startswith(b'END'): break
assert done==len(CHANGED),(done,len(CHANGED))
open(OUT,'wb').write(out)
print('written',len(out),'bytes; scripts replaced:',done)
