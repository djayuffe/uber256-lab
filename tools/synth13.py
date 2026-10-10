#!/usr/bin/env python3
"""Usage (needs unicorn; the repo venv has it):  .venv/bin/python tools/synth13.py N_SEEDS FIRST_SEED   (40 programs per seed)
Random synthesis of tiny mode-13h kernels. Program = mode13 setup (8 bytes) + random body + backward jmp.
Run in Unicorn, score the framebuffer at three moments, keep the most structured, animated, novel ones."""
import sys, random, zlib, hashlib, json, struct
from multiprocessing import Pool
from unicorn import *
from unicorn.x86_const import *

SETUP = bytes([0xB0,0x13,0xCD,0x10,0x68,0x00,0xA0,0x07])   # mov al,13h / int 10h / push A000h / pop es
ONE = [0x37,0x3F,0x27,0x2F,0x98,0x99,0x93,0x91,0x92,0x96,0x97,0x95,0xAA,0xAB,0xAC,0xAD,0xAE,0xA4,0xA5,0xD7,0xF9,0xF8,0xF5,
       0x40,0x41,0x42,0x43,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4D,0x4E,0x4F,0x9E,0x9F,0xFC,0xFD]
def two():
    r=random.random()
    mod=0xC0|random.randrange(64)
    if r<0.35: return bytes([random.choice([0x00,0x08,0x10,0x18,0x20,0x28,0x30,0x02,0x0A,0x12,0x1A,0x22,0x2A,0x32]),mod])   # alu r8,r8
    if r<0.5:  return bytes([random.choice([0x01,0x09,0x11,0x19,0x21,0x29,0x31,0x03,0x0B,0x13,0x1B,0x2B,0x33]),mod])        # alu r16
    if r<0.7:  return bytes([random.choice([0xD0,0xD1]),0xC0|(random.randrange(8)<<3)|random.randrange(8)])               # rotate/shift by 1
    if r<0.85: return bytes([random.choice([0xF6,0xF7]),0xC0|(random.choice([4,5,6,7])<<3)|random.randrange(8)])         # mul/imul/div/idiv
    if r<0.92: return bytes([random.choice([0xD4,0xD5]),random.choice([0x0A,0x0A,0x10,0x07,0x03])])                      # aam/aad
    return bytes([random.choice([0x04,0x14,0x2C,0x34,0x0C,0x24,0x80]),random.randrange(256)])[:2]
def body(n):
    b=b''
    while len(b)<n:
        if random.random()<0.55: b+=bytes([random.choice(ONE)])
        else: b+=two()
    return b[:n] if len(b)>=n else b
def build(bd):
    if not any(x in bd for x in (0xAA,0xAB,0xA4,0xA5)): return None
    jmp=bytes([0xEB,(256-(len(bd)+2))&255])
    return SETUP+bd+jmp

def run(code, instr=450_000):
    SEG=0x1000;LIN=SEG<<4
    uc=Uc(UC_ARCH_X86,UC_MODE_16)
    uc.mem_map(0,0x10000);uc.mem_map(LIN,0x10000);uc.mem_map(0xA0000,0x10000)
    uc.mem_write(LIN+0x100,code);uc.mem_write(LIN,b"\xCD\x20")
    for r in (UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_ES,UC_X86_REG_SS): uc.reg_write(r,SEG)
    uc.reg_write(UC_X86_REG_SP,0xFFFE);uc.reg_write(UC_X86_REG_FLAGS,0x7202&0xFFFF)
    for r,v in ((UC_X86_REG_CX,0xFF),(UC_X86_REG_SI,0x100),(UC_X86_REG_DI,0xFFFE),(UC_X86_REG_DX,0x192),(UC_X86_REG_BP,0x91C)): uc.reg_write(r,v)
    bad=[]
    uc.hook_add(UC_HOOK_INTR,lambda u,n,d:(u.emu_stop() if n==0x20 else None))
    uc.hook_add(UC_HOOK_MEM_UNMAPPED,lambda u,a,ad,sz,v,d:bad.append(ad) or False)
    shots=[]
    try:
        uc.emu_start(0x100,0xFFFF0,count=instr//3)
        shots.append(bytes(uc.mem_read(0xA0000,64000)))
        uc.emu_start(uc.reg_read(UC_X86_REG_IP),0xFFFF0,count=instr//3)
        shots.append(bytes(uc.mem_read(0xA0000,64000)))
        uc.emu_start(uc.reg_read(UC_X86_REG_IP),0xFFFF0,count=instr//3)
        shots.append(bytes(uc.mem_read(0xA0000,64000)))
    except UcError:
        return None
    if bad: return None
    return shots

def score(shots):
    a,b,c=shots
    n=64000
    nz=sum(1 for x in c if x)/n
    if nz<0.08 or nz>0.995: return 0,{}
    vals=len(set(c))
    if vals<3: return 0,{}
    ratio=len(zlib.compress(c,6))/n
    if ratio>0.6 or ratio<0.003: return 0,{}
    ch=sum(1 for x,y in zip(b,c) if x!=y)/n
    if ch<0.01 or ch>0.97: return 0,{}
    left=sum(1 for i in range(1,n) if c[i]==c[i-1])/n          # horizontal coherence
    up=sum(1 for i in range(320,n) if c[i]==c[i-320])/n        # vertical coherence
    coh=(left+up)/2
    if coh<0.12 or coh>0.97: return 0,{}
    if max(left,up)>0.88 and min(left,up)<0.35: return 0,{}
    rows=len({c[r*320:(r+1)*320] for r in range(200)})
    cols=len({c[x:64000:320] for x in range(320)})
    if rows<60 or cols<60: return 0,{}
    s=min(rows,200)/200+min(cols,320)/320+(1-abs(ratio-0.18)*2)+(1-abs(ch-0.5))+coh*1.5+min(vals,64)/64
    return s,dict(rows=rows,cols=cols,nz=round(nz,3),vals=vals,ratio=round(ratio,3),ch=round(ch,3),coh=round(coh,3))

def work(seed):
    random.seed(seed); out=[]
    for _ in range(40):
        bd=body(random.choice([4,5,6,6,7,8]))
        code=build(bd)
        if not code: continue
        sh=run(code)
        if not sh: continue
        s,info=score(sh)
        if s>0:
            sig=hashlib.md5(bytes(x>>5 for x in sh[2][::97])).hexdigest()[:8]
            out.append((s,code.hex(),sig,info))
    return out

if __name__=='__main__':
    N=int(sys.argv[1]); base=int(sys.argv[2])
    res=[]
    with Pool() as p:
        for r in p.imap_unordered(work,range(base,base+N)): res+=r
    seen=set(); top=[]
    for s,h,sig,info in sorted(res,reverse=True):
        if sig in seen: continue
        seen.add(sig); top.append((s,h,info))
    json.dump(top[:200],open(f'/tmp/lab/syn_{base}.json','w'))
    print(len(res),'scored,',len(top),'distinct')
    for s,h,info in top[:15]: print(round(s,2),h[16:],info)
