`timescale 1ns / 1ps

module ex_stage #(
    parameter NB_OP = 6
)(
    // --------- Entradas desde ID/EX ---------
    input  wire [31:0] idex_rs1_data,
    input  wire [31:0] idex_rs2_data,
    input  wire [31:0] idex_imm,
    input  wire [4:0]  idex_rd,
    input  wire [NB_OP-1:0] idex_alu_op,

    // Control
    input  wire        idex_RegWrite,
    input  wire        idex_MemRead,
    input  wire        idex_MemWrite,
    input  wire        idex_MemToReg,
    input  wire        idex_ALUSrc,
    input  wire        idex_valid,

    // --------- Salidas combinacionales hacia EX/MEM ---------
    output wire        ex_valid,
    output wire [31:0] ex_alu_out,
    output wire [31:0] ex_rs2_fwd,
    output wire [4:0]  ex_rd,
    output wire        ex_RegWrite,
    output wire        ex_MemRead,
    output wire        ex_MemWrite,
    output wire        ex_MemToReg
);

    wire [31:0] alu_b = idex_ALUSrc ? idex_imm : idex_rs2_data;

    alu32 #(
        .NB_DATA(32),
        .NB_OP(NB_OP)
    ) u_alu (
        .i_data_a (idex_rs1_data),
        .i_data_b (alu_b),
        .i_op     (idex_alu_op),
        .o_result (ex_alu_out)
    );

    assign ex_rs2_fwd  = idex_rs2_data;
    assign ex_rd       = idex_rd;
    assign ex_valid    = idex_valid;
    assign ex_RegWrite = idex_RegWrite;
    assign ex_MemRead  = idex_MemRead;
    assign ex_MemWrite = idex_MemWrite;
    assign ex_MemToReg = idex_MemToReg;

endmodule
