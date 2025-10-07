`timescale 1ns / 1ps

module program_counter (
    input  wire clk,
    input  wire reset,
    output reg  [31:0] pc
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 32'b0;
        else
            pc <= pc + 4; // avanza a la siguiente instrucción (word aligned)
    end
endmodule
