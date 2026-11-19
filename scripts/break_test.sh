#!/usr/bin/env bash
# Builds a copy of top.sv that's off by one cycle and runs the testbench on it.
# The real rtl/top.sv is never touched, the broken copy lives in build/.
# usage: scripts/break_test.sh [early|late]
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p build

mode="${1:-early}"
case "$mode" in
    early) sub='HALF_PERIOD_CYCLES - 2' ;;  # toggles one edge too soon
    late)  sub='HALF_PERIOD_CYCLES'     ;;  # toggles one edge too late
    *) echo "usage: $0 [early|late]"; exit 2 ;;
esac

sed "s/CNT_W'(HALF_PERIOD_CYCLES - 1)/CNT_W'($sub)/" rtl/top.sv > build/top_broken.sv
if cmp -s rtl/top.sv build/top_broken.sv; then
    echo "sed didn't change anything, check the pattern"; exit 2
fi
echo "broken ($mode): $(grep 'CNT_MAX =' build/top_broken.sv | sed 's/^ *//')"

iverilog -g2012 -Wall -s tb_top -o build/tb_broken build/top_broken.sv sim/tb_top.sv || exit 2
vvp build/tb_broken
status=$?
if [ $status -eq 0 ]; then
    echo "testbench passed a broken design!"
    exit 1
fi
echo "testbench caught it (vvp exit $status)"
