`timescale 1ns / 1ps

module decoder_rtype (
    input  wire [31:0] instr,
    output reg  [3:0]  alu_op,
    output reg  [3:0]  rs1, rs2, rd,
    output reg         reg_write
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    always @* begin
        alu_op    = 4'hF;  // NOP por defecto
        reg_write = 1'b0;
        rs1       = instr[19:15];
        rs2       = instr[24:20];
        rd        = instr[11:7];

        if (opcode == 7'b0110011) begin  // R-type
            reg_write = 1'b1;
            case (funct3)
                3'b000: alu_op = (funct7[5]) ? 4'h1 : 4'h0;  // SUB/ADD
                3'b100: alu_op = 4'h2; // XOR
                3'b110: alu_op = 4'h3; // OR
                3'b111: alu_op = 4'h4; // AND
                3'b101: alu_op = (funct7[5]) ? 4'h6 : 4'h5; // SRA/SRL
                default: alu_op = 4'hF;
            endcase
        end
    end
endmodule
