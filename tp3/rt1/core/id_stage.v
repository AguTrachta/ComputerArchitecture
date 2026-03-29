`timescale 1ns / 1ps
/*
INSTRUCTION DECODE (ID STAGE)

- Decodifica la instrucción recibida desde IF/ID.
- Lee los operandos desde el register file.
- Genera el inmediato extendido (32 bits).
- Calcula el código de operación de la ALU (alu_op) usando rv_decoder.
- Entrega todo el bundle listo para el registro ID/EX.

Por ahora, stall_id / flush_idex no se usan adentro
de este módulo: se aplican en el registro ID/EX.
id_valid solo se usa para detectar HALT sobre instrucciones válidas.
*/

module id_stage #(
    parameter NB_OP = 6
)(
    // Señales globales
    input  wire         clk,
    input  wire         reset,
    // input  wire         stall_id,    // reservado para uso futuro (ID/EX)    // WARNING LINTER: not used
    // input  wire         flush_idex,  // reservado para uso futuro (ID/EX)    // WARNING LINTER: not used
    
    // Entradas desde IF/ID Register
    // input  wire [31:0]  id_pc,       // WARNING LINTER: not used
    input  wire [31:0]  id_pc_plus4,
    input  wire [31:0]  id_instr,
    input  wire         id_valid,
    
    // Interfaz de write-back hacia el register file
    input  wire         wb_we,
    input  wire [4:0]   wb_rd,
    input  wire [31:0]  wb_wdata,
    
    // Salidas hacia el registro ID/EX
    output wire [31:0]  idex_pc_plus4,
    output wire [31:0]  idex_rs1_data,
    output wire [31:0]  idex_rs2_data,
    output wire [31:0]  idex_imm,
    output wire [4:0]   idex_rs1,
    output wire [4:0]   idex_rs2,
    output wire [4:0]   idex_rd,
    output wire [NB_OP-1:0] idex_alu_op,
    output wire [2:0] idex_funct3,
    output wire         id_halt, // Salida para indicar el HALT

    // Controles hacia ID/EX (se latchean en id_ex_reg)
    output wire         id_RegWrite,
    output wire         id_MemRead,
    output wire         id_MemWrite,
    output wire         id_MemToReg,
    output wire         id_ALUSrc,
    output wire         id_Branch,
    output wire         id_Jump,
    
    // Debug Unit
    input  wire [4:0]   i_dbg_reg_idx,
    output wire [31:0]  o_dbg_reg_data
);

    // ---------------------------------------
    // Señales internas desde el decoder
    // ---------------------------------------
    wire [4:0]       rs1;
    wire [4:0]       rs2;
    wire [4:0]       rd;
    wire [NB_OP-1:0] alu_op;
    // wire             is_rtype; // WARNING LINTER: not used
    // wire             is_itype; // WARNING LINTER: not used
    // wire signed [11:0] imm_i;  // no lo usamos aquí, pero sale del decoder // WARNING LINTER: not used

    // Instancia del decoder (tal cual lo definiste)
    rv_decoder #(
        .NB_OP(NB_OP)
    ) dec_i (
        .instr   (id_instr),
        .rs1     (rs1),
        .rs2     (rs2),
        .rd      (rd),
        .alu_op  (alu_op),
        //.is_rtype(is_rtype),  // WARNING LINTER: not used
        .is_rtype(),            // WARNING LINTER: not used
        //.is_itype(is_itype),  // WARNING LINTER: not used
        .is_itype(),            // WARNING LINTER: not used
        //.imm_i   (imm_i), // WARNING LINTER: not used
        .imm_i   (),        // WARNING LINTER: not used
        //.is_lui  (is_lui) // FALTA IMPLEMENTAR    // WARNING LINTER: not used
        .is_lui  ()                                // WARNING LINTER: not used
    );

    // ---------------------------------------
    // Register File (lectura + write-back)
    // ---------------------------------------
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    regfile32 #(
        .DATA_W(32),
        .NREGS (32)
    ) regfile_i (
        .clk   (clk),
        .reset (reset),
        .raddr1(rs1),
        .raddr2(rs2),
        .rdata1(rs1_data),
        .rdata2(rs2_data),
        .we    (wb_we),
        .waddr (wb_rd),
        .wdata (wb_wdata),
        
        // Debug Unit
        .i_dbg_reg_idx(i_dbg_reg_idx),
        .o_dbg_reg_data(o_dbg_reg_data)
    );

    // ---------------------------------------
    // Immediate Generator (32 bits sign-extended)
    // ---------------------------------------
    wire [31:0] imm;

    immgen immgen_i (
        .instr(id_instr),
        .imm  (imm)
    );
    
    // ---------------------------------------
    // CONTROL UNIT
    // ---------------------------------------
    
    // wire RegWrite; 
    // wire MemRead; 
    // wire MemWrite; 
    // wire MemToReg; 
    // wire ALUSrc;
    // wire Branch; 
    // wire Jump;

    // assign id_RegWrite = RegWrite;
    // assign id_MemRead  = MemRead;
    // assign id_MemWrite = MemWrite;
    // assign id_MemToReg = MemToReg;
    // assign id_ALUSrc   = ALUSrc;
    // assign id_Branch   = Branch;
    // assign id_Jump     = Jump;
    
    // control_unit cu (
    //     .instr(id_instr),
    //     .RegWrite(RegWrite),
    //     .MemRead(MemRead),
    //     .MemWrite(MemWrite),
    //     .MemToReg(MemToReg),
    //     .ALUSrc(ALUSrc),
    //     .Branch(Branch),
    //     .Jump(Jump)
    // );

    control_unit cu (
        .opcode    (id_instr[6:0]),
        .RegWrite (id_RegWrite),
        .MemRead  (id_MemRead),
        .MemWrite (id_MemWrite),
        .MemToReg (id_MemToReg),
        .ALUSrc   (id_ALUSrc),
        .Branch   (id_Branch),
        .Jump     (id_Jump)
    );

    // ---------------------------------------
    // Salidas hacia el registro ID/EX
    // ---------------------------------------
    assign idex_pc_plus4  = id_pc_plus4;

    assign idex_rs1       = rs1;
    assign idex_rs2       = rs2;
    assign idex_rd        = rd;

    assign idex_rs1_data  = rs1_data;
    assign idex_rs2_data  = rs2_data;

    assign idex_imm       = imm;
    assign idex_alu_op    = alu_op;

    assign idex_funct3 = id_instr[14:12];
    
    // Se detecta HALT solo si la instrucción en ID es válida.
    assign id_halt        = id_valid && (id_instr == 32'hffff_ffff);

endmodule
