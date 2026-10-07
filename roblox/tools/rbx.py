import struct, sys, lz4.block, zstandard
def chunks(path):
    d=open(path,'rb').read()
    assert d[:8]==b'<roblox!'
    nclass,ninst=struct.unpack('<ii',d[16:24])
    p=32; out=[]
    while p<len(d):
        name=d[p:p+4]; cl,ul,_=struct.unpack('<III',d[p+4:p+16]); p+=16
        if cl==0: data=d[p:p+ul]; p+=ul
        else:
            raw=d[p:p+cl]; p+=cl
            if raw[:4]==b'\x28\xb5\x2f\xfd': data=zstandard.ZstdDecompressor().decompress(raw,max_output_size=ul)
            else: data=lz4.block.decompress(raw,uncompressed_size=ul)
        out.append((name.rstrip(b'\0').decode(),data))
        if name.startswith(b'END'): break
    return nclass,ninst,out
if __name__=='__main__':
    n,i,c=chunks(sys.argv[1]); print(n,i)
    from collections import Counter
    print(Counter(x[0] for x in c))
