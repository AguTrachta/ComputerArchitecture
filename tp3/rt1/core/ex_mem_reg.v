`timescale 1ns / 1ps

module ex_mem_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,

    // Desde EX
    input  wire        ex_valid_in,
    input  wire [31:0] ex_alu_out_in,
    input  wire [31:0] ex_rs2_fwd_in,
    input  wire [4:0]  ex_rd_in,
    input  wire        ex_RegWrite_in,
    input  wire        ex_MemRead_in,
    input  wire        ex_MemWrite_in,
    input  wire        ex_MemToReg_in,

    // Hacia MEM
    output reg         exmem_valid,
    output reg  [31:0] exmem_alu_out,
    output reg  [31:0] exmem_rs2_fwd,
    output reg  [4:0]  exmem_rd,
    output reg         exmem_RegWrite,
    output reg         exmem_MemRead,
    output reg         exmem_MemWrite,
    output reg         exmem_MemToReg
);

    always @(posedge clk) begin
        if (reset) begin
            exmem_valid    <= 1'b0;
            exmem_alu_out  <= 32'b0;
            exmem_rs2_fwd  <= 32'b0;
            exmem_rd       <= 5'b0;
            exmem_RegWrite <= 1'b0;
            exmem_MemRead  <= 1'b0;
            exmem_MemWrite <= 1'b0;
            exmem_MemToReg <= 1'b0;
        end else if (en) begin
            exmem_valid    <= ex_valid_in;
            exmem_alu_out  <= ex_alu_out_in;
            exmem_rs2_fwd  <= ex_rs2_fwd_in;
            exmem_rd       <= ex_rd_in;
            exmem_RegWrite <= ex_RegWrite_in;
            exmem_MemRead  <= ex_MemRead_in;
            exmem_MemWrite <= ex_MemWrite_in;
            exmem_MemToReg <= ex_MemToReg_in;
        end
    end

endmodule
