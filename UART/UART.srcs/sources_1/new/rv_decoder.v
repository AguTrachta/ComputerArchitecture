// rv_decoder.v - decodifica instrucción R-type y genera NB_OP para tu ALU
module rv_decoder #(
    parameter NB_OP = 6
)(
    input  wire [31:0] instr,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output reg  [NB_OP-1:0] alu_op,
    output wire         is_rtype
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    assign rd   = instr[11:7];
    assign rs1  = instr[19:15];
    assign rs2  = instr[24:20];

    assign is_rtype = (opcode == 7'b0110011);

    // Códigos de tu ALU
    localparam ADD = 6'b100000,
               SUB = 6'b100010,
               AND = 6'b100100,
               OR  = 6'b100101,
               XOR = 6'b100110,
               SRA = 6'b000011,
               SRL = 6'b000010,
               NOR = 6'b100111;

    always @* begin
        alu_op = ADD; // default
        if (is_rtype) begin
            case (funct3)
                3'b000: alu_op = (funct7 == 7'b0100000) ? SUB : ADD; // SUB vs ADD
                3'b111: alu_op = AND;
                3'b110: alu_op = OR;
                3'b100: alu_op = XOR;
                3'b101: alu_op = (funct7 == 7'b0100000) ? SRA : SRL;
                // mapeo "extra" para NOR (no estándar)
                default: begin
                    if (funct3 == 3'b100 && funct7 == 7'b0100000)
                        alu_op = NOR;
                    else
                        alu_op = ADD;
                end
            endcase
        end
    end
endmodule
