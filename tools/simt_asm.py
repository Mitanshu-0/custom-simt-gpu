#!/usr/bin/env python3
"""Small educational assembler + CFG/IPDOM generator for the custom SIMT GPU.

The branch instruction remains 32 bits. Reconvergence PCs are emitted into a
separate ipdom.mem file, so the RTL ISA does not need a second branch address.
"""
from pathlib import Path
import argparse

OP_R=0b000000; OP_I=0b000001; OP_BEQ=0b010000; OP_BNE=0b010001; OP_EXIT=0b011000
FUNC={'ADD':0,'SUB':1,'AND':2,'OR':3,'XOR':4,'SLT':5}


def imm16(x):
    x=int(x,0)
    if not -(1<<15) <= x < (1<<16): raise ValueError(f"immediate out of range: {x}")
    return x & 0xffff

def reg(s):
    s=s.strip().upper()
    if not s.startswith('R'): raise ValueError(f"expected register, got {s}")
    n=int(s[1:],0)
    if not 0 <= n < 32: raise ValueError(f"register out of range: {s}")
    return n

def encode(line, pc, labels):
    t=line.replace(',',' ').split()
    op=t[0].upper()
    if op in FUNC:
        rd,rs,rt=map(reg,t[1:4]); return (OP_R<<26)|(rs<<21)|(rt<<16)|(rd<<11)|FUNC[op]
    if op in ('ADDI','LOAD','STORE'):
        if op=='ADDI':
            rt,rs=reg(t[1]),reg(t[2]); return (OP_I<<26)|(rs<<21)|(rt<<16)|imm16(t[3])
        raise ValueError('LOAD/STORE assembly is intentionally omitted; use existing hex images for memory tests')
    if op in ('BEQ','BNE'):
        rs,rt=reg(t[1]),reg(t[2]); label=t[3]
        if label not in labels: raise ValueError(f"unknown label {label}")
        offset=labels[label]-pc
        if offset % 4: raise ValueError('branch target must be word aligned')
        if not -(1<<15) <= offset < (1<<15): raise ValueError('branch offset out of range')
        opcode=OP_BEQ if op=='BEQ' else OP_BNE
        return (opcode<<26)|(rs<<21)|(rt<<16)|(offset & 0xffff)
    if op=='EXIT': return OP_EXIT<<26
    raise ValueError(f"unsupported instruction: {op}")

def successors(inst, pc, labels, words):
    op=(inst>>26)&0x3f
    nxt=pc+4
    if op==OP_EXIT: return []
    if op in (OP_BEQ,OP_BNE):
        target=pc+(inst&0xffff if inst&0x8000==0 else (inst&0xffff)-0x10000)
        return [target,nxt] if target != nxt else [target]
    return [nxt] if nxt in words else []

def ipdom_analysis(words, succ):
    nodes=sorted(words)
    post={n:set(nodes) for n in nodes}
    exits=[n for n in nodes if not succ[n]]
    for n in exits: post[n]={n}
    changed=True
    while changed:
        changed=False
        for n in reversed(nodes):
            if not succ[n]: continue
            inter=set(nodes)
            for s in succ[n]: inter &= post[s]
            new={n}|inter
            if new != post[n]: post[n]=new; changed=True
    ipdom={}
    for n in nodes:
        strict=post[n]-{n}
        if not strict: continue
        for c in strict:
            if all((d==c or d in post[c]) for d in strict):
                ipdom[n]=c; break
    return ipdom

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('asm')
    ap.add_argument('--out-dir',default='.')
    a=ap.parse_args()
    src=Path(a.asm).read_text().splitlines()
    labels={}; ins=[]; pc=0
    for raw in src:
        line=raw.split('#',1)[0].strip()
        if not line: continue
        while ':' in line:
            lab,rest=line.split(':',1); labels[lab.strip()]=pc; line=rest.strip()
            if not line: break
        if line: ins.append((pc,line)); pc+=4
    words={pc:encode(line,pc,labels) for pc,line in ins}
    succ={pc:successors(inst,pc,labels,words) for pc,inst in words.items()}
    ipdom=ipdom_analysis(words,succ)
    out=Path(a.out_dir); out.mkdir(parents=True,exist_ok=True)
    depth=max(256,max((p//4+1 for p in words),default=1))
    prog=['00000000']*depth; meta=['0000']*depth; valid=['0']*depth
    for pc,w in words.items(): prog[pc//4]=f'{w:08X}'
    for pc,rpc in ipdom.items():
        if ((words[pc]>>26)&0x3f) in (OP_BEQ, OP_BNE):
            meta[pc//4]=f'{rpc:04X}'; valid[pc//4]='1'
    (out/'program.mem').write_text('\n'.join(prog)+'\n')
    (out/'ipdom.mem').write_text('\n'.join(meta)+'\n')
    (out/'ipdom_valid.mem').write_text('\n'.join(valid)+'\n')
    print('Generated program.mem, ipdom.mem, ipdom_valid.mem')
    for pc,rpc in sorted(ipdom.items()):
        if ((words[pc]>>26)&0x3f) in (OP_BEQ, OP_BNE):
            print(f'  branch PC {pc:04d} -> IPDOM {rpc:04d}')

if __name__=='__main__': main()
