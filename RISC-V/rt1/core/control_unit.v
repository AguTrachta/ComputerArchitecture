`timescale 1ns/1ps

module control_unit(
    //input  wire [31:0] instr,
    input  wire [6:0] opcode,

    output reg  RegWrite,
    output reg  MemRead,
    output reg  MemWrite,
    output reg  MemToReg,
    output reg  ALUSrc,
    output reg  Branch,
    output reg  Jump
);

    //wire [6:0] opcode = instr[6:0];
    // wire [2:0] funct3 = instr[14:12]; // WARNING LINTER: not used

    always @* begin
        // Valores por defecto
        RegWrite = 0;
        MemRead  = 0;
        MemWrite = 0;
        MemToReg = 0;
        ALUSrc   = 0;
        Branch   = 0;
        Jump     = 0;

        case (opcode)

            // ============================
            // R-TYPE (ADD,SUB,AND,OR,...)
            // opcode = 0110011
            // ============================
            7'b0110011: begin
                RegWrite = 1;
                ALUSrc   = 0;   // usa rs2
            end

            // ============================
            // I-TYPE (ADDI, ANDI, ORI, XORI)
            // opcode = 0010011
            // ============================
            7'b0010011: begin
                RegWrite = 1;
                ALUSrc   = 1;   // inmediato
            end

            // ============================
            // LOAD (LW)
            // opcode = 0000011
            // ============================
            7'b0000011: begin
                RegWrite = 1;
                MemRead  = 1;
                MemToReg = 1;   // wb usa la memoria
                ALUSrc   = 1;   // base + offset
            end

            // ============================
            // STORE (SW)
            // opcode = 0100011
            // ============================
            7'b0100011: begin
                MemWrite = 1;
                ALUSrc   = 1;  // rs1 + offset
            end

            // ============================
            // BRANCH (BEQ/BNE/BLT/BGE)
            // opcode = 1100011
            // ============================
            7'b1100011: begin
                Branch = 1;
            end

            // ============================
            // JAL (Jump and Link)
            // opcode = 1101111
            // ============================
            7'b1101111: begin
                RegWrite = 1; // escribe PC+4 en RD
                Jump     = 1;
            end

            // ============================
            // JALR (Jump and Link Register)
            // opcode = 1100111
            // ============================
            7'b1100111: begin
                RegWrite = 1; 
                Jump     = 1;
                ALUSrc   = 1;  // usado para calcular target
            end

            // ============================
            // LUI
            // opcode = 0110111
            // ============================
            7'b0110111: begin
                RegWrite = 1;
                ALUSrc   = 1;
            end

            // ============================
            // AUIPC
            // opcode = 0010111
            // ============================
            7'b0010111: begin
                RegWrite = 1;
                ALUSrc   = 1;
            end

            default: begin
                // Todo en cero
            end
        endcase
    end

endmodule
