// rtl/core/pc.v
`timescale 1ns / 1ps

module pc (
    input  wire        clk,
    input  wire        reset,
    input  wire        pc_write_en,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);

    always @(posedge clk) begin
        if (reset)
            pc <= 32'd0;
        else if (pc_write_en)
            pc <= pc_next;
    end

endmodule
