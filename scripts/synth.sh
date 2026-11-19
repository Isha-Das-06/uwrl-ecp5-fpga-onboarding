#!/usr/bin/env bash
# synthesize top for ECP5 with the real (1 s blink) default
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
yosys -q -l build/synth.log -p 'read_verilog -sv rtl/top.sv; synth_ecp5 -top top -json build/top.json; check -assert; stat'
echo "log: build/synth.log  netlist: build/top.json"
