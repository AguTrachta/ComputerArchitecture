`timescale 1ns / 1ps

module register_file #(
    parameter XLEN = 32,
    parameter NREG = 16
)(
    input  wire clk,
    input  wire we,
    input  wire [3:0] rs1, rs2, rd,
    input  wire [XLEN-1:0] wd,
    output wire [XLEN-1:0] rd1, rd2
);
    reg [XLEN-1:0] regs [0:NREG-1];
    integer i;
    initial for (i=0; i<NREG; i=i+1) regs[i]=0;

    assign rd1 = (rs1==0) ? 0 : regs[rs1];
    assign rd2 = (rs2==0) ? 0 : regs[rs2];

    always @(posedge clk)
        if (we && (rd!=0))
            regs[rd] <= wd;
endmodule
