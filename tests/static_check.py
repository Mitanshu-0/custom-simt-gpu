#!/usr/bin/env python3
from pathlib import Path
import re,sys
root=Path(__file__).parents[1]
files=list(root.glob('rtl/**/*.sv'))+list(root.glob('rtl/**/*.svh'))
text='\n'.join(p.read_text() for p in files)
errors=[]
# module port extraction (sufficient for this repository's ANSI-style declarations)
mods={}
for p in files:
    s=p.read_text()
    for m in re.finditer(r'module\s+(\w+)\s*\((.*?)\);',s,re.S):
        name,body=m.group(1),m.group(2)
        ports=set(re.findall(r'\b(?:input|output|inout)\s+(?:logic\s+)?(?:\[[^\]]+\]\s*)?(\w+)\b',body))
        mods[name]=ports
# instantiate modules and compare named port connections
for p in files:
    s=p.read_text()
    for mod,inst,body in re.findall(r'\b(\w+)\s+(\w+)\s*\((.*?)\);',s,re.S):
        if mod not in mods or mod in ('if','for','always_ff','always_comb'): continue
        conns=set(re.findall(r'\.(\w+)\s*\(',body))
        missing=mods[mod]-conns
        extra=conns-mods[mod]
        if missing: errors.append(f'{p}: {mod} {inst}: missing ports {sorted(missing)}')
        if extra: errors.append(f'{p}: {mod} {inst}: unknown ports {sorted(extra)}')
# stale scalar branch signals should not remain
for needle in ['branch_taken,','memory_branch_taken,','writeback_branch_taken,']:
    if needle in text: errors.append(f'stale scalar branch signal remains: {needle}')
if 'parameter int `LANE_WIDTH' in text or 'parameter int `WARP_SIZE' in text:
    errors.append('invalid macro-as-parameter syntax remains in RTL')
if 'SETRPC' in text:
    errors.append('legacy SETRPC control-flow mechanism remains in RTL')
for needle in ['branch_taken_mask','branch_fallthrough_mask','branch_divergent','branch_reconvergence_program_counter']:
    if needle not in text:
        errors.append(f'missing V2 control signal: {needle}')

# required V2 files/data
for rel in ['rtl/top/compute_unit/warp/simt_stack.sv','rtl/top/memory/ipdom_table.sv','ipdom.mem','ipdom_valid.mem','tools/simt_asm.py']:
    if not (root/rel).exists(): errors.append(f'missing required V2 artifact: {rel}')
# metadata dimensions
for rel in ['ipdom.mem','ipdom_valid.mem']:
    n=len((root/rel).read_text().split())
    if n != 256: errors.append(f'{rel}: expected 256 entries, found {n}')
if errors:
    print('FAIL')
    print('\n'.join(errors)); sys.exit(1)
print(f'PASS: static V2 connectivity/artifact checks across {len(files)} RTL files')
