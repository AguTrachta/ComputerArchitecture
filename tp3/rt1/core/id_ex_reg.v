`timescale 1ns / 1ps

module id_ex_reg #(
    parameter NB_OP = 6
)(
    input  wire         clk,
    input  wire         reset,

    // Señales de control de hazard
    input  wire         stall,   // stall_id
    input  wire         flush,   // flush_idex (inserta burbuja en EX)

    // --------- Entradas desde ID stage ---------
    // Datos
    input  wire [31:0]  id_pc_plus4,
    input  wire [31:0]  id_rs1_data,
    input  wire [31:0]  id_rs2_data,
    input  wire [31:0]  id_imm,
    input  wire [4:0]   id_rs1,
    input  wire [4:0]   id_rs2,
    input  wire [4:0]   id_rd,
    input  wire [NB_OP-1:0] id_alu_op,

    // Control
    input  wire         id_RegWrite,
    input  wire         id_MemRead,
    input  wire         id_MemWrite,
    input  wire         id_MemToReg,
    input  wire         id_ALUSrc,
    input  wire         id_Branch,
    input  wire         id_Jump,

    // Valid
    input  wire         id_valid,

    // --------- Salidas hacia EX stage ---------
    // Datos
    output reg  [31:0]  idex_pc_plus4,
    output reg  [31:0]  idex_rs1_data,
    output reg  [31:0]  idex_rs2_data,
    output reg  [31:0]  idex_imm,
    output reg  [4:0]   idex_rs1,
    output reg  [4:0]   idex_rs2,
    output reg  [4:0]   idex_rd,
    output reg  [NB_OP-1:0] idex_alu_op,

    // Control
    output reg          idex_RegWrite,
    output reg          idex_MemRead,
    output reg          idex_MemWrite,
    output reg          idex_MemToReg,
    output reg          idex_ALUSrc,
    output reg          idex_Branch,
    output reg          idex_Jump,

    // Valid
    output reg          idex_valid
);

    always @(posedge clk) begin
        if (reset || flush) begin
            // ========================
            // RESET / FLUSH -> burbuja
            // ========================
            idex_pc_plus4  <= 32'b0;
            idex_rs1_data  <= 32'b0;
            idex_rs2_data  <= 32'b0;
            idex_imm       <= 32'b0;
            idex_rs1       <= 5'b0;
            idex_rs2       <= 5'b0;
            idex_rd        <= 5'b0;
            idex_alu_op    <= {NB_OP{1'b0}};

            // Control en cero = no escribe, no lee, no branch
            idex_RegWrite  <= 1'b0;
            idex_MemRead   <= 1'b0;
            idex_MemWrite  <= 1'b0;
            idex_MemToReg  <= 1'b0;
            idex_ALUSrc    <= 1'b0;
            idex_Branch    <= 1'b0;
            idex_Jump      <= 1'b0;

            idex_valid     <= 1'b0;
        end
        else if (!stall) begin
            // ========================
            // Avance normal del pipeline
            // ========================
            idex_pc_plus4  <= id_pc_plus4;
            idex_rs1_data  <= id_rs1_data;
            idex_rs2_data  <= id_rs2_data;
            idex_imm       <= id_imm;
            idex_rs1       <= id_rs1;
            idex_rs2       <= id_rs2;
            idex_rd        <= id_rd;
            idex_alu_op    <= id_alu_op;

            idex_RegWrite  <= id_RegWrite;
            idex_MemRead   <= id_MemRead;
            idex_MemWrite  <= id_MemWrite;
            idex_MemToReg  <= id_MemToReg;
            idex_ALUSrc    <= id_ALUSrc;
            idex_Branch    <= id_Branch;
            idex_Jump      <= id_Jump;

            idex_valid     <= id_valid;
        end
        // else (stall == 1) -> mantiene todo lo que ya tenía
    end

endmodule
