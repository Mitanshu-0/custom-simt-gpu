# Custom SIMT GPU — V2 Control-Flow Architecture

A compact, parameterized SIMT-style GPU implemented in SystemVerilog RTL.
V2 extends the working V1 pipeline with **per-lane branch divergence,
IPDOM-based reconvergence metadata, and a per-warp SIMT control-flow stack**.

## V2 architecture

```text
                         ┌──────────────────────┐
                         │     Warp Manager     │
                         │ PC + Active Mask     │
                         │ Round-Robin Scheduler│
                         └──────────┬───────────┘
                                    │
                                    ▼
                              IF → ID → EX
                                    │
                                    ▼
                          Per-lane branch compare
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
              taken_mask                    fallthrough_mask
                    │                               │
                    └───────────────┬───────────────┘
                                    │
                              divergence?
                                    │
                                    ▼
                           IPDOM metadata lookup
                                    │
                                    ▼
                              SIMT Stack
                         ┌──────────┴──────────┐
                         │ alternate path     │
                         │ barrier/reconverge  │
                         └──────────┬──────────┘
                                    │
                                    ▼
                             MEM → WB → Warp
                                    │
                                    ▼
                              Reconvergence
```

### Reconvergence policy

The GPU does **not** enlarge the 32-bit branch instruction. A small Python
program-generation tool performs CFG/post-dominator analysis and emits a
separate `ipdom.mem` table plus `ipdom_valid.mem` metadata.

For a divergent branch:

1. EX evaluates the condition independently for every active lane.
2. `taken_mask` and `fallthrough_mask` are generated.
3. If both masks are non-zero, the branch is divergent.
4. The IPDOM PC is obtained from the static IPDOM table.
5. The SIMT stack saves the alternate path and the reconvergence point.
6. The taken path executes first.
7. When the warp PC reaches the IPDOM, the alternate path is restored.
8. When the alternate path reaches the IPDOM, the original active mask is restored.
9. The IPDOM instruction is then issued once with the reconverged mask.

This stack organization supports nested structured divergence.

## Processor configuration

Defined in `rtl/top/cu_defs.svh`:

| Parameter | Default |
|---|---:|
| Warp size | 4 lanes |
| Number of warps | 4 |
| Registers/lane | 32 |
| Lane width | 32 bits |
| Instruction width | 32 bits |
| PC width | 16 bits |
| Immediate width | 16 bits |
| Instruction memory | 256 words |
| Data memory | 1024 words |
| SIMT stack depth | 8 entries/warp |
| Pipeline | IF → ID → EX → MEM → WB |

## ISA

| Instruction | Meaning |
|---|---|
| `ADD rd, rs, rt` | Integer add |
| `SUB rd, rs, rt` | Integer subtract |
| `AND rd, rs, rt` | Bitwise AND |
| `OR rd, rs, rt` | Bitwise OR |
| `XOR rd, rs, rt` | Bitwise XOR |
| `SLT rd, rs, rt` | Signed less-than |
| `ADDI rt, rs, imm` | Add signed immediate |
| `LOAD` | Per-lane load |
| `STORE` | Per-lane store |
| `BEQ rs, rt, offset` | Per-lane equal branch |
| `BNE rs, rt, offset` | Per-lane not-equal branch |
| `EXIT` | Warp termination |

Branch target semantics remain compatible with V1:

```text
branch_target = branch_PC + sign_extended(immediate)
fallthrough   = branch_PC + 4
```

There is **no implicit immediate << 2**.

## RTL structure

```text
rtl/top/
├── cu_defs.svh
├── top.sv
├── memory/
│   ├── instruction_memory.sv
│   ├── data_memory.sv
│   └── ipdom_table.sv
└── compute_unit/
    ├── compute_unit.sv
    ├── alu/
    │   ├── lane_alu.sv
    │   └── vector_alu.sv
    ├── register_file/
    │   └── vector_register_file.sv
    ├── pipeline/
    │   ├── IFU.sv
    │   ├── decode_unit.sv
    │   ├── execute_stage.sv
    │   ├── mem_stage.sv
    │   └── writeback_stage.sv
    └── warp/
        ├── warp_manager.sv
        ├── simt_stack.sv
        └── scoreboard.sv
```

## IPDOM metadata

`ipdom.mem` is indexed by byte-addressed branch PC converted to a word
index. `ipdom_valid.mem` identifies entries that contain valid reconvergence
metadata.

Example:

```text
Branch PC    IPDOM PC
---------------------
0x0004       0x0010
```

The 32-bit instruction remains unchanged.

## Program generation

Use:

```bash
python tools/simt_asm.py tests/divergence.asm --out-dir generated
```

The tool emits:

```text
program.mem
ipdom.mem
ipdom_valid.mem
```

The assembler currently supports the arithmetic instructions, `ADDI`,
`BEQ`, `BNE`, and `EXIT` needed by the control-flow tests. The CFG analysis
uses iterative post-dominator sets and derives the immediate post-dominator
for each reachable instruction.

## Verification included

`tests/verify_v2.py` is a simulator-independent behavioral model of the V2
control-flow mechanism. It checks:

- Per-lane branch mask generation
- Divergence detection
- IPDOM lookup
- Alternate-path stack handling
- Reconvergence at the IPDOM
- Nested divergence
- Uniform backward loop branches
- Final register results

Run:

```bash
python tests/verify_v2.py
python tests/static_check.py
```

Expected:

```text
PASS: divergence, nested divergence/reconvergence, and loop control-flow model checks
PASS: static V2 connectivity/artifact checks across ... RTL files
```

For RTL simulation, install Icarus Verilog and run:

```bash
./sim/run_iverilog.sh
```

or on Windows:

```bat
sim\run_iverilog.bat
```

The default `program.mem` is the divergence test. `tb/tb_v2.sv` checks that
all four warps finish, all four lanes receive the expected join result, and
all SIMT stacks return to depth zero.

## Included control-flow tests

```text
tests/
├── divergence.asm
├── divergence.mem
├── divergence_ipdom.mem
├── divergence_ipdom_valid.mem
├── nested_divergence.asm
├── nested_divergence.mem
├── nested_divergence_ipdom.mem
├── nested_divergence_ipdom_valid.mem
├── loop.asm
├── loop.mem
├── loop_ipdom.mem
├── loop_ipdom_valid.mem
├── verify_v2.py
└── static_check.py
```

## Important V2 design choices

- No per-warp instruction buffers.
- No out-of-order execution.
- No register renaming.
- No branch prediction.
- One scheduler and one vector execution unit.
- One PC and active mask per warp.
- One SIMT stack per warp.
- Nested divergence is handled by stack nesting.
- The existing 32-bit ISA is preserved.
- Reconvergence metadata is external to the instruction encoding.

## Known scope limitation

`EXIT` is still a warp-level termination instruction and is intended to be
placed after reconvergence in structured programs. Lane-level early-exit
semantics are a separate control-flow extension.

The current loop test demonstrates uniform backward branches. Fully divergent
loops with per-lane changing loop-exit masks require an additional loop-exit
control-flow policy and should be treated as the next V2.x extension rather
than silently assumed to work like an `if/else`.
