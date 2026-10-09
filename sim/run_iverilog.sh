#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
iverilog -g2012 -I rtl/top -o sim/v2.out \
  rtl/top/top.sv \
  rtl/top/memory/*.sv \
  rtl/top/compute_unit/alu/*.sv \
  rtl/top/compute_unit/register_file/*.sv \
  rtl/top/compute_unit/warp/*.sv \
  rtl/top/compute_unit/pipeline/*.sv \
  rtl/top/compute_unit/*.sv \
  tb/tb_v2.sv
vvp sim/v2.out
