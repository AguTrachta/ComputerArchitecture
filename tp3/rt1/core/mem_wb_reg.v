`timescale 1ns / 1ps

/* Registro de pipeline MEM/WB: captura (en posedge) los datos/control que salen de MEM, WB los usa estables el ciclo siguiente.
 * - reset limpia las salidas.
 * - en permite stallar (en=0 mantiene el estado).
 * - Transporta rd, alu_out y señales RegWrite/MemToReg (el dato de memoria viene ya registrado por data_mem).
 */

module mem_wb_reg #(
    parameter NB_OP = 6
)(
    input  wire         clk,
    input  wire         reset,
    input  wire         en,
    // desde mem_stage
    input  wire [31:0]  pc_plus4_in,
    input  wire         mem_valid_in,
    input  wire [31:0]  alu_out_in,
    input  wire [4:0]   rd_in,
    input  wire [31:0]  mem_rdata_in,
    input  wire         RegWrite_in,
    input  wire         MemToReg_in,
    input  wire         Jump_in,
    // hacia wb
    output reg          wb_valid,
    output reg  [31:0]  wb_alu_out,
    output reg  [4:0]   wb_rd,
    output reg  [31:0]  wb_pc_plus4,
    output reg  [31:0]  wb_mem_rdata,
    output reg          wb_RegWrite,
    output reg          wb_MemToReg,
    output reg          wb_Jump
);
    
    always @(posedge clk) begin
        if (reset) begin
            wb_valid    <= 1'b0;
            wb_alu_out  <= 32'h0;
            wb_rd       <= 5'd0;
            wb_mem_rdata <= 32'b0;
            wb_RegWrite <= 1'b0;
            wb_MemToReg <= 1'b0;
            wb_pc_plus4 <= 32'b0;
            wb_Jump     <= 1'b0;
        end else if (en) begin
            wb_valid    <= mem_valid_in;
            wb_alu_out  <= alu_out_in;
            wb_rd       <= rd_in;
            wb_mem_rdata <= mem_rdata_in;
            wb_RegWrite <= RegWrite_in;
            wb_MemToReg <= MemToReg_in;
            wb_pc_plus4 <= pc_plus4_in;
            wb_Jump     <= Jump_in;
        end
    end
    
endmodule