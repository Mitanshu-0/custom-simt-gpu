#!/usr/bin/env python3
"""Behavioral verification of the V2 SIMT control-flow algorithm.

This is independent of the RTL simulator and checks the same architectural
rules: per-lane branch masks, IPDOM lookup, two-entry SIMT stack, nested
reconvergence, and uniform backward loop branches.
"""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parents[1] / 'tools'))
import simt_asm

ROOT=Path(__file__).parents[1]

def load_words(path):
    vals=[int(x,16) for x in Path(path).read_text().split()]
    return {i*4:v for i,v in enumerate(vals) if v != 0}

def load_meta(path):
    vals=[int(x,16) for x in Path(path).read_text().split()]
    return {i*4:v for i,v in enumerate(vals) if v != 0}

def run(program, ipdom, max_steps=500):
    regs=[[0]*32 for _ in range(4)]
    for lane in range(4): regs[lane][1]=lane
    pc=0; mask=0b1111
    # Stack top is the last tuple: (target, mask, rpc, barrier)
    stack=[]
    trace=[]
    exited=False
    for step in range(max_steps):
        # Reconverge before issuing the instruction at the IPDOM.
        if stack and pc == stack[-1][2]:
            target, newmask, rpc, barrier=stack.pop()
            trace.append(('POP', pc, newmask, barrier))
            pc=target; mask=newmask
            continue
        inst=program.get(pc,0)
        op=(inst>>26)&0x3f
        rs=(inst>>21)&31; rt=(inst>>16)&31; rd=(inst>>11)&31
        imm=inst&0xffff
        if imm&0x8000: imm-=0x10000
        trace.append(('ISSUE',pc,mask,op))
        if op==simt_asm.OP_EXIT:
            exited=True
            break
        if op==simt_asm.OP_I:
            for lane in range(4):
                if mask>>lane & 1: regs[lane][rt]=(regs[lane][rs]+imm)&0xffffffff
            pc+=4; continue
        if op==simt_asm.OP_R:
            fn=inst&0x3f
            for lane in range(4):
                if not(mask>>lane&1): continue
                a,b=regs[lane][rs],regs[lane][rt]
                regs[lane][rd]={'0':a+b,'1':a-b,'2':a&b,'3':a|b,'4':a^b,'5':int(a<b)}.get(str(fn),0)&0xffffffff
            pc+=4; continue
        if op in (simt_asm.OP_BEQ,simt_asm.OP_BNE):
            taken=0
            for lane in range(4):
                if mask>>lane & 1:
                    cond=(regs[lane][rs]==regs[lane][rt])
                    if op==simt_asm.OP_BNE: cond=not cond
                    if cond: taken |= 1<<lane
            fall=mask & ~taken & 0xf
            target=pc+imm; fallpc=pc+4
            divergent=(taken != 0 and fall != 0)
            if divergent:
                assert pc in ipdom, f'missing IPDOM for divergent branch PC {pc}'
                rpc=ipdom[pc]
                stack.append((rpc,mask,rpc,True))
                stack.append((fallpc,fall,rpc,False))
                trace.append(('DIVERGE',pc,taken,fall,rpc,len(stack)))
                pc=target; mask=taken
            elif taken:
                pc=target
            else:
                pc=fallpc
            continue
        raise AssertionError(f'Unsupported opcode {op} at PC {pc}')
    assert exited, 'program did not reach EXIT'
    assert step < max_steps-1, 'control flow exceeded step budget'
    return regs, trace

def check(name, expected):
    d=ROOT/'tests'/name
    p=load_words(d.with_suffix('.mem'))
    meta=load_meta(ROOT/'tests'/(name+'_ipdom.mem'))
    regs,trace=run(p,meta)
    for lane, exp in expected.items():
        for r,v in exp.items(): assert regs[lane][r]==v, f'{name}: lane {lane} R{r}={regs[lane][r]}, expected {v}'
    return trace

# Single divergent branch: all lanes execute the join instruction after reconvergence.
t=check('divergence', {0:{4:99},1:{4:99},2:{4:99},3:{4:99}})
assert sum(1 for x in t if x[0]=='DIVERGE')==1, 'expected one divergence event in single-warp model'
assert any(x[0]=='POP' for x in t), 'expected SIMT stack pops'

# Nested divergence: outer branch and inner branch must both reconverge.
t=check('nested_divergence', {0:{8:14},1:{8:14},2:{8:14},3:{8:14}})
assert sum(1 for x in t if x[0]=='DIVERGE')==2, 'expected two nested divergence events'
assert sum(1 for x in t if x[0]=='POP')>=4, 'expected alternate+barrier pops for nested divergence'

# Uniform backward branch: no divergence stack activity, but the loop must terminate.
t=check('loop', {0:{3:3,4:7},1:{3:3,4:7},2:{3:3,4:7},3:{3:3,4:7}})
assert not any(x[0]=='DIVERGE' for x in t), 'uniform loop should not diverge'

print('PASS: divergence, nested divergence/reconvergence, and loop control-flow model checks')
