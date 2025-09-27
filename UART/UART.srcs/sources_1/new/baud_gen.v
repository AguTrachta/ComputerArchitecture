`timescale 1ns / 1ps

module baud_gen #(
    parameter CLK_FREQ = 50000000,   // frecuencia del reloj FPGA (50 MHz default)
    parameter BAUD_RATE = 19200      // baud rate
)(
    input  wire clk, reset,
    output reg  sample_tick
);

    localparam integer DIVISOR = CLK_FREQ / (BAUD_RATE * 16);

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
