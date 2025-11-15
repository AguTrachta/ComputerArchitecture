// rtl/core/core_m0.v
`timescale 1ns / 1ps

module core_m0(
    input  wire clk,
    input  wire reset
);

    // ========================
    // Program Counter
    // ========================
    wire [31:0] pc, pc_next;
    assign pc_next = pc + 32'd4;

    pc pc_i (
        .clk(clk),
        .reset(reset),
        .pc_write_en(1'b1),   // siempre escribimos
        .pc_next(pc_next),
        .pc(pc)
    );

    // ========================
    // Instruction Memory
    // ========================
    wire [31:0] instr;

    instr_mem mem_i (
        .addr(pc),
        .instr(instr)
    );

    // ========================
    // Decoder
    // ========================
    wire [4:0] rs1, rs2, rd;
    wire is_rtype, is_itype;
    wire signed [11:0] imm_i;
    wire [5:0] alu_op;

    rv_decoder dec_i (
        .instr(instr),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .alu_op(alu_op),
        .is_rtype(is_rtype),
        .is_itype(is_itype),
        .imm_i(imm_i)
    );

    // ========================
    // Regfile
    // ========================
    wire [31:0] rdata1, rdata2;
    wire        we;

    assign we = (rd != 5'd0) && (is_rtype || is_itype);

    wire [31:0] write_data;

    regfile32 rf_i (
        .clk(clk),
        .raddr1(rs1),
        .raddr2(rs2),
        .rdata1(rdata1),
        .rdata2(rdata2),
        .we(we),
        .waddr(rd),
        .wdata(write_data)
    );

    // ========================
    // ALU
    // ========================
    wire [31:0] alu_src_b = is_itype ? {{20{imm_i[11]}}, imm_i} : rdata2;
    wire [31:0] alu_result;

    alu32 alu_i (
        .i_data_a(rdata1),
        .i_data_b(alu_src_b),
        .i_op(alu_op),
        .o_result(alu_result)
    );

    assign write_data = alu_result;

endmodule
