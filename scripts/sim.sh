#!/usr/bin/env bash
# usage: scripts/sim.sh [HALF_PERIOD_CYCLES]
# no argument = testbench default (7)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build

override=()
if [ $# -ge 1 ]; then
    override=(-Ptb_top.HALF_PERIOD_CYCLES="$1")
fi

iverilog -g2012 -Wall -s tb_top "${override[@]}" -o build/tb_top rtl/top.sv sim/tb_top.sv
vvp build/tb_top
