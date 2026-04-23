`timescale 1ns / 1ps

//Genera el inmediato extendido a 32 bits con signo según el tipo de instrucción

module immgen(
    input  wire [31:0] instr,
    output reg  [31:0] imm
);

    wire [6:0] opcode = instr[6:0];

    always @* begin
        case (opcode)

            // -------------------------------------------------
            // I-type: imm[31:0] = sign_extend(instr[31:20])
            // ADDI, ANDI, ORI, XORI, LW, SLLI, SRLI, SRAI, JALR
            // -------------------------------------------------
            7'b0010011, // OP-IMM
            7'b0000011, // LOAD
            7'b1100111: // JALR
                imm = {{20{instr[31]}}, instr[31:20]};

            // -------------------------------------------------
            // S-type (Stores): imm = sign_extend(instr[31:25] ++ instr[11:7])
            // -------------------------------------------------
            7'b0100011: // STORE (SW, SH, SB)
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // -------------------------------------------------
            // B-type (Branches): branch immediate
            // Layout RV32I: imm[12|10:5|4:1|11|0]
            // -------------------------------------------------
            7'b1100011: // BEQ, BNE, BLT, BGE, BLTU, BGEU
                imm = {
                    {19{instr[31]}},   // signo extendido
                    instr[31],         // imm[12]
                    instr[7],          // imm[11]
                    instr[30:25],      // imm[10:5]
                    instr[11:8],       // imm[4:1]
                    1'b0               // imm[0]
                };

            // -------------------------------------------------
            // U-type: LUI / AUIPC
            // imm[31:12] = instr[31:12], lower 12 bits = 0
            // -------------------------------------------------
            7'b0110111, // LUI
            7'b0010111: // AUIPC
                imm = {instr[31:12], 12'b0};

            // -------------------------------------------------
            // J-type: JAL
            // Layout RV32I: imm[20|10:1|11|19:12|0]
            // -------------------------------------------------
            7'b1101111: // JAL
                imm = {
                    {11{instr[31]}},   // signo
                    instr[31],         // imm[20]
                    instr[19:12],      // imm[19:12]
                    instr[20],         // imm[11]
                    instr[30:21],      // imm[10:1]
                    1'b0               // imm[0]
                };

            // -------------------------------------------------
            // Default: sin inmediato válido
            // -------------------------------------------------
            default:
                imm = 32'b0;
        endcase
    end

endmodule
