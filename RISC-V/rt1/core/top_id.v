`timescale 1ns/1ps

module top_id (
    input  wire clk,
    input  wire reset,

    // Señales de control para el latch ID/EX
    input  wire stall,      // stall_id
    input  wire flush       // flush_idex
);

    // ===========================
    // Entradas desde IF/ID REGISTER
    // (En un core real vienen del latch IF/ID)
    // ===========================
    reg [31:0] id_pc;
    reg [31:0] id_pc_plus4;
    reg [31:0] id_instr;
    reg        id_valid;

    // Podemos inicializar algo simple para pruebas
    initial begin
        id_pc       = 32'h0;
        id_pc_plus4 = 32'h4;
        id_instr    = 32'h00000013;   // NOP = ADDI x0,x0,0
        id_valid    = 1'b1;
    end

    // ===========================
    // Señales de WRITE-BACK (dummy para test)
    // ===========================
    reg        wb_we;
    reg [4:0]  wb_rd;
    reg [31:0] wb_wdata;

    initial begin
        wb_we    = 0;
        wb_rd    = 0;
        wb_wdata = 0;
    end

    // ===========================
    // Señales internas desde ID Stage
    // ===========================
    wire [31:0] id_rs1_data;
    wire [31:0] id_rs2_data;
    wire [31:0] id_imm;
    wire [4:0]  id_rs1;
    wire [4:0]  id_rs2;
    wire [4:0]  id_rd;
    wire [5:0]  id_alu_op;

    // Señales de control generadas por control_unit
    wire id_RegWrite;
    wire id_MemRead;
    wire id_MemWrite;
    wire id_MemToReg;
    wire id_ALUSrc;
    wire id_Branch;
    wire id_Jump;

    // ===========================
    // Señales hacia EX (latch ID/EX)
    // ===========================
    wire [31:0] idex_pc_plus4;
    wire [31:0] idex_rs1_data;
    wire [31:0] idex_rs2_data;
    wire [31:0] idex_imm;
    wire [4:0]  idex_rs1;
    wire [4:0]  idex_rs2;
    wire [4:0]  idex_rd;
    wire [5:0]  idex_alu_op;

    wire idex_RegWrite;
    wire idex_MemRead;
    wire idex_MemWrite;
    wire idex_MemToReg;
    wire idex_ALUSrc;
    wire idex_Branch;
    wire idex_Jump;
    wire idex_valid;

    // ===========================
    // CONTROL UNIT
    // ===========================
    control_unit cu (
        .instr    (id_instr),
        .RegWrite (id_RegWrite),
        .MemRead  (id_MemRead),
        .MemWrite (id_MemWrite),
        .MemToReg (id_MemToReg),
        .ALUSrc   (id_ALUSrc),
        .Branch   (id_Branch),
        .Jump     (id_Jump)
    );

    // ===========================
    // ID STAGE
    // ===========================
    id_stage #(
        .NB_OP(6)
    ) id_s (
        .clk(clk),
        .reset(reset),
        .stall_id(stall),
        .flush_idex(flush),

        .id_pc(id_pc),
        .id_pc_plus4(id_pc_plus4),
        .id_instr(id_instr),
        .id_valid(id_valid),

        .wb_we(wb_we),
        .wb_rd(wb_rd),
        .wb_wdata(wb_wdata),

        .idex_pc_plus4(),  // ignoramos esta salida (la verdadera viene del latch ID/EX)
        .idex_rs1_data(id_rs1_data),
        .idex_rs2_data(id_rs2_data),
        .idex_imm(id_imm),
        .idex_rs1(id_rs1),
        .idex_rs2(id_rs2),
        .idex_rd(id_rd),
        .idex_alu_op(id_alu_op)
    );

    // ===========================
    // ID/EX REGISTER (pipeline latch)
    // ===========================
    id_ex_reg #(
        .NB_OP(6)
    ) latch_id_ex (
        .clk(clk),
        .reset(reset),
        .stall(stall),
        .flush(flush),

        .id_pc_plus4 (id_pc_plus4),
        .id_rs1_data (id_rs1_data),
        .id_rs2_data (id_rs2_data),
        .id_imm      (id_imm),
        .id_rs1      (id_rs1),
        .id_rs2      (id_rs2),
        .id_rd       (id_rd),
        .id_alu_op   (id_alu_op),

        .id_RegWrite (id_RegWrite),
        .id_MemRead  (id_MemRead),
        .id_MemWrite (id_MemWrite),
        .id_MemToReg (id_MemToReg),
        .id_ALUSrc   (id_ALUSrc),
        .id_Branch   (id_Branch),
        .id_Jump     (id_Jump),
        .id_valid    (id_valid),

        .idex_pc_plus4(idex_pc_plus4),
        .idex_rs1_data(idex_rs1_data),
        .idex_rs2_data(idex_rs2_data),
        .idex_imm     (idex_imm),
        .idex_rs1     (idex_rs1),
        .idex_rs2     (idex_rs2),
        .idex_rd      (idex_rd),
        .idex_alu_op  (idex_alu_op),

        .idex_RegWrite(idex_RegWrite),
        .idex_MemRead (idex_MemRead),
        .idex_MemWrite(idex_MemWrite),
        .idex_MemToReg(idex_MemToReg),
        .idex_ALUSrc  (idex_ALUSrc),
        .idex_Branch  (idex_Branch),
        .idex_Jump    (idex_Jump),
        .idex_valid   (idex_valid)
    );

endmodule
