# V2 Verification Report

## Implemented

- Per-lane BEQ/BNE condition evaluation.
- `taken_mask` and `fallthrough_mask` generation.
- Divergence detection when both masks are non-zero.
- Static IPDOM metadata table separate from the 32-bit ISA.
- Per-warp SIMT stack.
- Two-entry push per divergent branch: barrier + alternate path.
- Reconvergence before issuing the IPDOM instruction.
- Restoration of the original pre-branch active mask.
- Nested divergence support through stack nesting.
- Uniform backward branch support for loop control flow.
- IFU squash on decode-time branch/EXIT/dependency stalls to prevent stale instruction leakage.
- Fixed invalid macro-as-parameter syntax in the original ALU/register-file RTL.

## Automated checks run in this environment

### 1. Behavioral control-flow model

Command:

```bash
python tests/verify_v2.py
```

Result:

```text
PASS: divergence, nested divergence/reconvergence, and loop control-flow model checks
```

Covered:

- One divergent branch with four lanes.
- Nested divergence.
- Two-level stack behavior.
- Reconvergence at the IPDOM.
- Uniform backward loop branch.
- Final register results.

### 2. Static RTL connectivity check

Command:

```bash
python tests/static_check.py
```

Result:

```text
PASS: static V2 connectivity/artifact checks across 17 RTL files
```

Checks include:

- Named-port connectivity.
- Required V2 modules and metadata files.
- No stale scalar branch interface.
- Required V2 branch-control signals.
- No legacy `SETRPC` mechanism.
- No invalid macro-as-parameter syntax.
- IPDOM metadata dimensions.

### 3. Include-path check

Result:

```text
PASS: all RTL include paths resolve
```

### 4. Reproducible program generation

The default `program.mem`, `ipdom.mem`, and `ipdom_valid.mem` were regenerated
from `tests/divergence.asm` and compared against the checked-in images.

Result:

```text
PASS: default images reproducible from divergence.asm
```

## RTL simulator status

No SystemVerilog simulator (`iverilog`, Verilator, Questa, VCS, etc.) is
installed in the execution environment used to prepare this archive. Therefore
an actual RTL compile/elaboration and waveform run could not be honestly
claimed here.

A ready-to-run Icarus testbench is included in `tb/tb_v2.sv`, with launch
scripts in `sim/`. Run it after installing Icarus Verilog.

## Important scope note

`EXIT` remains a warp-level termination instruction and should be placed after
reconvergence. The included loop test is a uniform loop. Fully divergent loops
with independently changing loop-exit masks require an additional loop-control
policy beyond ordinary if/else IPDOM reconvergence.
