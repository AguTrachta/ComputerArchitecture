`timescale 1ns / 1ps

module baud_gen #(
    parameter integer DIVISOR = 163  // default p/50 MHz y 19200 baud
)(
    input  wire clk, reset,
    output reg  sample_tick
);

    reg [$clog2(DIVISOR)-1:0] count_reg, count_next;

    always @(posedge clk, posedge reset)
        if (reset)
            count_reg <= 0;
        else
            count_reg <= count_next;

    always @* begin
        count_next  = count_reg + 1;
        sample_tick = 1'b0;
        if (count_reg == (DIVISOR-1)) begin
            count_next  = 0;
            sample_tick = 1'b1;
        end
    end

endmodule
