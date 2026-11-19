// led blinker, flips led every HALF_PERIOD_CYCLES clock edges
// 12.5M @ 25MHz = 0.5s on / 0.5s off

`timescale 1ns/1ps

module top #(
    parameter int unsigned HALF_PERIOD_CYCLES = 12_500_000
) (
    input  logic clk_25mhz,
    output logic led
);

    // $clog2(1) is 0 so force at least 1 bit
    localparam int unsigned CNT_W = (HALF_PERIOD_CYCLES > 1) ? $clog2(HALF_PERIOD_CYCLES) : 1;
    localparam logic [CNT_W-1:0] CNT_MAX = CNT_W'(HALF_PERIOD_CYCLES - 1);

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
