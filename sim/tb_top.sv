`timescale 1ns/1ps

// Testbench for top. Clock is 40 ns (25 MHz), first rising edge at 20 ns.
//
// Expected behaviour, worked out by hand (not from the RTL):
//   rising edges are numbered 1, 2, 3, ...
//   led flips only on edges N, 2N, 3N, ...   (N = HALF_PERIOD_CYCLES)
//   so after edge n, led should be floor(n / N) mod 2
//   N=7 -> flips on edges 7, 14, 21, ... -> t = 260, 540, 820 ns ...
//   N=6 -> flips on edges 6, 12, 18, ... -> t = 220, 460, 700 ns ...
//   N=1 -> flips on every edge
//
// Checks:
//   - led is 0 after time-zero init, before the first edge
//   - led matches the expected value 1 ps after every rising edge
//   - led never changes except right on a rising edge (catches glitches)
//   - no X/Z on led after init
//   - total number of toggles is right
//   - separate timeout in case the sim hangs

module tb_top #(
    parameter int HALF_PERIOD_CYCLES = 7
);

    localparam int NUM_TOGGLES = 6;
    // go N-1 edges past the last toggle so an extra/early toggle would show up
    localparam int TOTAL_EDGES = HALF_PERIOD_CYCLES * (NUM_TOGGLES + 1) - 1;
    localparam int TIMEOUT_NS  = (TOTAL_EDGES + 10) * 40;

    logic clk = 1'b0;
    logic led;

    top #(
        .HALF_PERIOD_CYCLES(HALF_PERIOD_CYCLES)
    ) dut (
        .clk_25mhz(clk),
        .led      (led)
    );

    always #20 clk = ~clk;

    int      edge_num  = 0;
    realtime last_rise = -1.0;
    int      toggles   = 0;

    always @(posedge clk) begin
        edge_num  = edge_num + 1;
        last_rise = $realtime;
    end

    // watch every change on led, not just what we sample once per clock
    always @(led) begin
        if ($realtime == 0) begin
            // time-zero init, ignore
        end else if ($isunknown(led)) begin
            $fatal(1, "led went to %b at %t", led, $realtime);
        end else if ($realtime != last_rise) begin
            $fatal(1, "led changed between clock edges at %t (last rising edge %t)", $realtime, last_rise);
        end else if (edge_num % HALF_PERIOD_CYCLES != 0) begin
            $fatal(1, "led toggled on edge %0d at %t, should only toggle on multiples of %0d",
                   edge_num, $realtime, HALF_PERIOD_CYCLES);
        end else begin
            toggles++;
        end
    end

    logic exp_led;

    initial begin
        $timeformat(-9, 3, " ns", 12);
        $dumpfile("build/blink.vcd");
        $dumpvars(0, tb_top);

        $display("HALF_PERIOD_CYCLES = %0d, expecting led flips on edges %0d, %0d, %0d, ... (%0d edges total)",
                 HALF_PERIOD_CYCLES, HALF_PERIOD_CYCLES, 2*HALF_PERIOD_CYCLES, 3*HALF_PERIOD_CYCLES, TOTAL_EDGES);

        // let time-zero init settle, first edge isn't until 20 ns
        #1ps;
        if (led !== 1'b0)
            $fatal(1, "led should start low, got %b at %t", led, $realtime);

        for (int n = 1; n <= TOTAL_EDGES; n++) begin
            @(posedge clk);
            #1ps; // let the nonblocking updates land
            exp_led = ((n / HALF_PERIOD_CYCLES) % 2) ? 1'b1 : 1'b0;
            if (led !== exp_led)
                $fatal(1, "edge %0d (%t): led = %b, expected %b", n, $realtime, led, exp_led);
        end

        if (toggles != NUM_TOGGLES)
            $fatal(1, "saw %0d toggles, expected %0d", toggles, NUM_TOGGLES);

        $display("PASS: HALF_PERIOD_CYCLES = %0d, %0d edges checked, %0d toggles", HALF_PERIOD_CYCLES, TOTAL_EDGES, toggles);
        $finish;
    end

    initial begin
        #(TIMEOUT_NS);
        $fatal(1, "timeout after %0d ns", TIMEOUT_NS);
    end

endmodule
