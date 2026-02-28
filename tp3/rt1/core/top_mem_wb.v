`timescale 1ns/1ps

module top_mem_wb #(
    parameter integer DMEM_BYTES = 4096,
    parameter integer NB_OP = 6
)(
    input  wire clk,
    input  wire reset,

    // Entradas desde ID/EX
    input  wire        idex_valid,
    input  wire [31:0] idex_rs1_data,
    input  wire [31:0] idex_rs2_data,
    input  wire [31:0] idex_imm,
    input  wire [4:0]  idex_rd,
    input  wire [NB_OP-1:0] idex_alu_op,

    input  wire        idex_RegWrite,
    input  wire        idex_MemRead,
    input  wire        idex_MemWrite,
    input  wire        idex_MemToReg,
    input  wire        idex_ALUSrc,

    // Observables de WB
    output wire        wb_valid,
    output wire        wb_RegWrite,
    output wire [4:0]  wb_rd,
    output wire [31:0] wb_wdata
);

    // ============================================================
    // EX stage + EX/MEM register
    // ============================================================
    wire        ex_valid;
    wire [31:0] ex_alu_out;
    wire [31:0] ex_rs2_fwd;
    wire [4:0]  ex_rd;
    wire        ex_RegWrite;
    wire        ex_MemRead;
    wire        ex_MemWrite;
    wire        ex_MemToReg;

    ex_stage #(
        .NB_OP(NB_OP)
    ) u_ex_stage (
        .idex_rs1_data(idex_rs1_data),
        .idex_rs2_data(idex_rs2_data),
        .idex_imm(idex_imm),
        .idex_rd(idex_rd),
        .idex_alu_op(idex_alu_op),
        .idex_RegWrite(idex_RegWrite),
        .idex_MemRead(idex_MemRead),
        .idex_MemWrite(idex_MemWrite),
        .idex_MemToReg(idex_MemToReg),
        .idex_ALUSrc(idex_ALUSrc),
        .idex_valid(idex_valid),
        .ex_valid(ex_valid),
        .ex_alu_out(ex_alu_out),
        .ex_rs2_fwd(ex_rs2_fwd),
        .ex_rd(ex_rd),
        .ex_RegWrite(ex_RegWrite),
        .ex_MemRead(ex_MemRead),
        .ex_MemWrite(ex_MemWrite),
        .ex_MemToReg(ex_MemToReg)
    );

    wire        exmem_valid;
    wire [31:0] exmem_alu_out;
    wire [31:0] exmem_rs2_fwd;
    wire [4:0]  exmem_rd;
    wire        exmem_RegWrite;
    wire        exmem_MemRead;
    wire        exmem_MemWrite;
    wire        exmem_MemToReg;

    ex_mem_reg u_ex_mem (
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .ex_valid_in(ex_valid),
        .ex_alu_out_in(ex_alu_out),
        .ex_rs2_fwd_in(ex_rs2_fwd),
        .ex_rd_in(ex_rd),
        .ex_RegWrite_in(ex_RegWrite),
        .ex_MemRead_in(ex_MemRead),
        .ex_MemWrite_in(ex_MemWrite),
        .ex_MemToReg_in(ex_MemToReg),
        .exmem_valid(exmem_valid),
        .exmem_alu_out(exmem_alu_out),
        .exmem_rs2_fwd(exmem_rs2_fwd),
        .exmem_rd(exmem_rd),
        .exmem_RegWrite(exmem_RegWrite),
        .exmem_MemRead(exmem_MemRead),
        .exmem_MemWrite(exmem_MemWrite),
        .exmem_MemToReg(exmem_MemToReg)
    );

    // ============================================================
    // DATA MEM (BRAM-friendly, rdata registrada)
    // ============================================================

    wire do_write = exmem_valid && exmem_MemWrite;
    wire do_read  = exmem_valid && exmem_MemRead;

    // Por ahora: SW/LW palabra completa
    wire [3:0] byte_en = do_write ? 4'b1111 : 4'b0000;

    // Para evitar lecturas/escrituras fuera de caso
    wire [31:0] mem_addr = (do_read || do_write) ? exmem_alu_out : 32'h0000_0000;

    wire [31:0] dmem_rdata;

    data_mem #(
        .DEPTH_BYTES(DMEM_BYTES)
    ) u_dmem (
        .clk     (clk),
        .reset   (reset),
        .addr    (mem_addr),
        .wdata   (exmem_rs2_fwd),
        .we      (do_write),
        .byte_en (byte_en),
        .rdata   (dmem_rdata)
    );

    // ===========================
    // MEM/WB REGISTER (pipeline latch)
    // ===========================

    wire        wb_valid_i;
    wire [31:0] wb_alu_out_i;
    wire [4:0]  wb_rd_i;
    wire        wb_RegWrite_i;
    wire        wb_MemToReg_i;

    mem_wb_reg u_mem_wb (
        .clk         (clk),
        .reset       (reset),
        .en          (1'b1),

        .mem_valid_in(exmem_valid),
        .alu_out_in  (exmem_alu_out),
        .rd_in       (exmem_rd),
        .RegWrite_in (exmem_RegWrite),
        .MemToReg_in (exmem_MemToReg),

        .wb_valid    (wb_valid_i),
        .wb_alu_out  (wb_alu_out_i),
        .wb_rd       (wb_rd_i),
        .wb_RegWrite (wb_RegWrite_i),
        .wb_MemToReg (wb_MemToReg_i)
    );

    // ============================================================
    // WB mux (MemToReg)
    // ============================================================

    wb_mux u_wb (
        .mem_rdata (dmem_rdata),
        .alu_out   (wb_alu_out_i),
        .MemToReg  (wb_MemToReg_i),
        .wb_wdata  (wb_wdata)
    );

    // Exporto señales de WB
    assign wb_valid    = wb_valid_i;
    assign wb_RegWrite = wb_RegWrite_i;
    assign wb_rd       = wb_rd_i;

endmodule
