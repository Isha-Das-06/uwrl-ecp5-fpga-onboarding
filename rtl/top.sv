// LED blinker for the ULX3S (ECP5, 25 MHz clock).
// led flips every HALF_PERIOD_CYCLES rising edges of clk_25mhz.
// Default 12_500_000 -> 0.5 s on, 0.5 s off at 25 MHz.

`timescale 1ns/1ps

module top #(
    parameter int unsigned HALF_PERIOD_CYCLES = 12_500_000
) (
    input  logic clk_25mhz,
    output logic led
);

    // counter goes 0 .. HALF_PERIOD_CYCLES-1, so ceil(log2(N)) bits is enough.
    // N=1 would give a 0-bit counter, keep at least 1 bit.
    localparam int unsigned CNT_W = (HALF_PERIOD_CYCLES > 1) ? $clog2(HALF_PERIOD_CYCLES) : 1;
    localparam logic [CNT_W-1:0] CNT_MAX = CNT_W'(HALF_PERIOD_CYCLES - 1);

    if (HALF_PERIOD_CYCLES < 1) begin : g_bad_param
        initial $fatal(1, "HALF_PERIOD_CYCLES must be >= 1");
    end

    logic [CNT_W-1:0] count = '0;
    logic             led_q = 1'b0;

    always_ff @(posedge clk_25mhz) begin
        if (count == CNT_MAX) begin
            count <= '0;
            led_q <= ~led_q;
        end else begin
            count <= count + 1'b1;
        end
    end

    assign led = led_q;

endmodule
