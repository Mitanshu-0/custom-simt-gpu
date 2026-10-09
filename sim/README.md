# Simulation

The repository is simulator-neutral. If Icarus Verilog is installed:

Linux/macOS:

```bash
./sim/run_iverilog.sh
```

Windows:

```bat
sim\run_iverilog.bat
```

The default `program.mem` is the divergence/reconvergence test. The testbench
checks all four warps, all four lanes, the final R4 value, warp completion, and
an empty SIMT stack.

For the nested-divergence and loop images, copy the matching files from
`tests/` to the project root as `program.mem`, `ipdom.mem`, and
`ipdom_valid.mem`, then run the same testbench after adjusting its expected
register if needed.
