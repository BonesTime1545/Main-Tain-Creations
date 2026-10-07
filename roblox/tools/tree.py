import struct, sys, pickle
from rbx import chunks
def u32(b,p): return struct.unpack_from('<I',b,p)[0]
def ids(b,n,p):
    # interleaved big-endian int32 w/ zigzag, delta
    vals=[]
    for i in range(n):
        v=(b[p+i]<<24)|(b[p+n+i]<<16)|(b[p+2*n+i]<<8)|b[p+3*n+i]
        v=(v>>1)^-(v&1); vals.append(v)
    return vals
def parse(path):
    _,_,cs=chunks(path)
    classes={}; inst={}; props={}; parent={}
    for name,d in cs:
        if name=='INST':
            cid=u32(d,0); l=u32(d,4); cn=d[8:8+l].decode(); p=8+l
            has=d[p]; p+=1; n=u32(d,p); p+=4
            ii=ids(d,n,p); acc=0; lst=[]
            for x in ii: acc+=x; lst.append(acc)
            classes[cid]=cn
            for r in lst: inst[r]=cid
        elif name=='PROP':
            cid=u32(d,0); l=u32(d,4); pn=d[8:8+l].decode(); p=8+l; t=d[p]; p+=1
            n=len([r for r,c in inst.items() if c==cid])
            if t==1:
                vals=[]
                for _ in range(n):
                    l2=u32(d,p); p+=4; vals.append(d[p:p+l2].decode('utf8','replace')); p+=l2
                props[(cid,pn)]=vals
            else:
                props[(cid,pn)]=(t,d[p:])
        elif name=='PRNT':
            n=u32(d,5); p=9
            ch=ids(d,n,p); pa=ids(d,n,p+4*n)
            a=b=0
            for x,y in zip(ch,pa):
                a+=x;b+=y; parent[a]=b
    return classes,inst,props,parent
if __name__=='__main__':
    r=parse(sys.argv[1]); pickle.dump(r,open('tree.pkl','wb'))
    classes,inst,props,parent=r
    from collections import Counter
    print(Counter(classes[c] for c in inst.values()).most_common())
