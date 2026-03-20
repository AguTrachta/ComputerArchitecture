`timescale 1ns / 1ps

/* Multiplexor de writeback: selecciona el dato que vuelve al banco de registros.
 * - MemToReg=1: escribe el dato proveniente de memoria (loads).
 * - MemToReg=0: escribe el resultado de la ALU (instrucciones ALU / addr calculada).
 */
 
module wb_mux (
    input  wire [31:0] mem_rdata,
    input  wire [31:0] alu_out,
    input  wire [31:0] pc_plus4,
    input  wire        MemToReg,
    input  wire        Jump,
    output wire [31:0] wb_wdata
);

    assign wb_wdata = Jump ? pc_plus4 :
                      (MemToReg ? mem_rdata : alu_out);
                      
endmodule
