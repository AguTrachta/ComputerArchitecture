`timescale 1ns / 1ps

module datapath (
    input  wire clk,
    input  wire reset
);
    // Señales de interconexión
    wire [31:0] pc;
    wire [31:0] instr;
    wire [3:0]  rs1, rs2, rd, alu_op;
    wire [31:0] rd1, rd2, alu_result;
    wire reg_write;

    // PC
    program_counter pc_inst (
        .clk(clk),
        .reset(reset),
        .pc(pc)
    );

    // Instruction Memory
    instruction_memory imem_inst (
        .addr(pc),
        .instr(instr)
    );

    // Decoder
    decoder_rtype dec_inst (
        .instr(instr),
        .alu_op(alu_op),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .reg_write(reg_write)
    );

    // Register File
    register_file regf_inst (
        .clk(clk),
        .we(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .wd(alu_result),
        .rd1(rd1),
        .rd2(rd2)
    );

    // ALU (usa tu módulo actual)
    alu alu_inst (
        .i_data_a(rd1),
        .i_data_b(rd2),
        .i_op(alu_op),
        .o_result(alu_result)
    );

endmodule
