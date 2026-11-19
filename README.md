# uwrl-ecp5-fpga-onboarding

LED blinker for the WRL FPGA onboarding. Simulated with iverilog, waveforms in GTKWave, synthesized for ECP5 with yosys.

- `rtl/top.sv` - design
- `sim/tb_top.sv` - testbench
- `scripts/` - sim, synth and break test scripts
- `evidence/` - saved outputs + waveform screenshot

## Tools

OSS CAD Suite 2026-09-16 on Ubuntu 26.04 (WSL2)

- iverilog 14.0 (devel) s20260301-451-gc9ed76463
- yosys 0.69+62 (0edda7a3a)
- gtkwave v4.0.0-prealpha

## Running it

```bash
source "$HOME/oss-cad-suite/environment"

# sim (default N=7)
iverilog -g2012 -Wall -s tb_top -o build/tb_top rtl/top.sv sim/tb_top.sv
vvp build/tb_top

# other values
iverilog -g2012 -Wall -s tb_top -Ptb_top.HALF_PERIOD_CYCLES=6 -o build/tb_top rtl/top.sv sim/tb_top.sv
vvp build/tb_top

# waves
gtkwave build/blink.vcd sim/blink.gtkw

# synth
yosys -l build/synth.log -p 'read_verilog -sv rtl/top.sv; synth_ecp5 -top top -json build/top.json; check -assert; stat'
```

`scripts/sim.sh [N]` and `scripts/synth.sh` do the same thing.

## Blink count / counter width

25 MHz, 1 s full blink, so 25,000,000 cycles per full blink and 12,500,000 per half. Default `HALF_PERIOD_CYCLES = 12_500_000`.

The counter counts 0 to 12,499,999 so it needs 12.5M values. 2^23 = 8,388,608 is too small, 2^24 = 16,777,216 fits, so 24 bits. In the code it's `$clog2(HALF_PERIOD_CYCLES)` but at least 1 bit, since `$clog2(1)` is 0.

## Simulation

The testbench numbers the rising edges and expects led to flip on edges N, 2N, 3N..., so after edge n it should be `(n / N) % 2`. It checks this 1ps after every edge, checks led starts at 0, fails if led changes anywhere other than on a clock edge or goes X/Z, counts the toggles, and has a timeout.

Passing for 7, 6 and 1 (full output in `evidence/sim_pass.txt`):

```
PASS: HALF_PERIOD_CYCLES = 7, 48 edges checked, 6 toggles
PASS: HALF_PERIOD_CYCLES = 6, 41 edges checked, 6 toggles
PASS: HALF_PERIOD_CYCLES = 1, 6 edges checked, 6 toggles
```

Broke it by changing the wrap value by one (`scripts/break_test.sh`, makes a copy in build/ so the real file stays fine). Output in `evidence/sim_broken.txt`.

One cycle early:
```
FATAL: sim/tb_top.sv:46: led toggled on edge 6 at   220.000 ns, should only toggle on multiples of 7
```

One cycle late:
```
FATAL: sim/tb_top.sv:73: edge 7 (  260.001 ns): led = 0, expected 1
```

Reran 7/6/1 on the normal design after and they pass.

## Waveform

![gtkwave](evidence/gtkwave.png)

N=7. Clock period is 40ns and the first rising edge is at 20ns, so the 7th edge is at 260ns and that's the first time led goes high. Count goes 0-6 then wraps on the same edge led flips. I put the baseline marker on 260ns and the main marker on the next flip at 540ns, the difference shows B+280000ps = 280ns (7 x 40ns). Full on+off is 560ns.

## Synthesis

Full output in `evidence/synth.txt`.

```
Found and reported 0 problems.
       12   CCU2C
       11   LUT4
        2   PFUMX
       25   TRELLIS_FF
```

No latches and check passes. The only warnings are yosys saying `write_xaiger2` is experimental and ABC saying the network is combinational, both just from synth_ecp5 internals.

25 FFs = 24 counter bits + led.

**TRELLIS_FF** is a flip flop. The led one from top.json (`evidence/cells.txt`):

```
TRELLIS_FF  led_q_TRELLIS_FF_Q
    input  CE    -> led_q_TRELLIS_FF_Q_CE
    input  CLK   -> clk_25mhz
    input  DI    -> led_q_LUT4_D_Z
    output Q     -> led
```

DI is a LUT4 that just inverts led, and CE is the "count == max" signal, so it only loads ~led when the counter wraps. The counter FFs use that same signal on LSR (sync reset) to go back to 0.

**CCU2C** is the carry cell, it does 2 bits of addition and chains carry to the next one. 12 of them make the count + 1 adder. This one takes count[14] and count[15] on B0/B1, carry in on CIN, and S0/S1 go to the DI of the count[14] and count[15] FFs:

```
CCU2C  count_TRELLIS_FF_Q_12_DI_CCU2C_S1
    input  B0    -> count[14]
    input  B1    -> count[15]
    input  CIN   -> count_TRELLIS_FF_Q_8_DI_CCU2C_S0_COUT
    output COUT  -> count_TRELLIS_FF_Q_12_DI_CCU2C_S1_COUT
    output S0    -> count_TRELLIS_FF_Q_12_DI_CCU2C_S1_S0
    output S1    -> count_TRELLIS_FF_Q_12_DI
```

The LUT4s and PFUMXs make up the compare against 12,499,999.
