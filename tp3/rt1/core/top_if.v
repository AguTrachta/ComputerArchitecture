`timescale 1ns/1ps

module top_if (
    input  wire clk,
    input  wire reset,
    input  wire stall,
    input  wire flush
);

    // Señales IF
    wire [31:0] if_pc;
    wire [31:0] if_pc_plus4;
    wire [31:0] if_instr;

    // Señales IF/ID
    wire [31:0] id_pc;
    wire [31:0] id_pc_plus4;
    wire [31:0] id_instr;
    wire        id_valid;

    // ===========================
    // IF STAGE
    // ===========================
    if_stage if_s (
        .clk(clk),
        .reset(reset),
        .pc_write_en(1'b1),       // en M1 siempre permitimos avanzar el PC
        .flush(flush),      
        .pc_next_external(32'b0),
        .pc_sel_external(1'b0),
        .if_pc(if_pc),
        .if_pc_plus4(if_pc_plus4),
        .if_instr(if_instr)
    );

    // ===========================
    // IF/ID REGISTER (pipeline latch)
    // ===========================
    if_id_reg latch_if_id (
        .clk(clk),
        .reset(reset),
        .stall(stall),
        .flush(flush),
        .if_pc(if_pc),
        .if_pc_plus4(if_pc_plus4),
        .if_instr(if_instr),
        .id_pc(id_pc),
        .id_pc_plus4(id_pc_plus4),
        .id_instr(id_instr),
        .id_valid(id_valid)
    );

endmodule
