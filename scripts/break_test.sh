#!/usr/bin/env bash
# runs the tb on a copy of top.sv that toggles one cycle early (or late if you pass "late")
# doesn't touch rtl/top.sv, the copy goes in build/
cd "$(dirname "$0")/.."
mkdir -p build

if [ "$1" = "late" ]; then
    new="HALF_PERIOD_CYCLES"
else
    new="HALF_PERIOD_CYCLES - 2"
fi

sed "s/(HALF_PERIOD_CYCLES - 1)/($new)/" rtl/top.sv > build/top_broken.sv
grep "CNT_MAX =" build/top_broken.sv
iverilog -g2012 -Wall -s tb_top -o build/tb_broken build/top_broken.sv sim/tb_top.sv && vvp build/tb_broken
