// `timescale 1ns / 1ps
// /*
// INSTRUCTION DECODE

// Bloque utilizado para interpretar la instrucción recibida 
// y generar operandos y señales de control para ejecutar

// Debe recibir :
// - instrucción de 32 bits del regsitro IF/ID
// - pc_plus4 (para abarcar casos de JUMP)
// - datos de A, B y lugar para almacenar rs1, rs2, rd.
// - stall para detener etapa
// - flush para vaciar etapa

// Debe sacar:
// - Campos rs1, rs2, rd ya decodificados
// - Señales de control listas para ID/EX
// - hazard_detected : indica que se requiere un stall en el pipeline
// */


// module id_stage(

//     // Señales globales
//     input  wire         clk,
//     input  wire         reset,
//     input  wire         stall_id,
//     input  wire         flush_idex,
    
//     // Entradas desde IF/ID Register
//     input  wire [31:0]  id_pc,
//     input  wire [31:0]  id_pc_plus4,
//     input  wire [31:0]  id_instr,
//     input  wire         id_valid,
    
//     // Salidas hacia el registro ID/EX
//     output wire [31:0]  idex_pc_plus4,
//     output wire [31:0]  idex_rs1_data,
//     output wire [31:0]  idex_rs2_data,
//     output wire [31:0]  idex_imm,
//     output wire [4:0]   idex_rs1,
//     output wire [4:0]   idex_rs2,
//     output wire [4:0]   idex_rd
    
//     // Falta agregar señales de control:
//     // output wire idex_regwrite, idex_memread, etc.

//     );
    
//     // Conexiones internas...
    
//     // ---------------------------------------
//     // Decodificación de campos de la instrucción
//     // ---------------------------------------
//     wire [6:0] opcode = id_instr[6:0];
//     wire [4:0] rd     = id_instr[11:7];
//     wire [2:0] funct3 = id_instr[14:12];
//     wire [4:0] rs1    = id_instr[19:15];
//     wire [4:5] rs2    = id_instr[24:20];
//     wire [6:0] funct7 = id_instr[31:25];
    
    
    
//     // ---------------------------------------
//     // Register File (lectura)
//     // ---------------------------------------
//     wire [31:0] rs1_data;
//     wire [31:0] rs2_data;
    
//     regfile32 regfile_i (
//         .clk(clk),
//         .reset(reset),
    
//         //.we(wb_regwrite),      // pendiente (al conectar con WB)
//         .waddr(wb_rd),
//         .wdata(wb_wdata),
    
//         .raddr1(rs1),
//         .raddr2(rs2),
//         .rdata1(rs1_data),
//         .rdata2(rs2_data)
//     );



//     // ---------------------------------------
//     // Immediate Generator
//     // ---------------------------------------
//     wire [31:0] imm;

//     // immgen immgen_i (
//     //     .instr(id_instr),
//     //     .imm_out(imm)
//     // );
    
    
    
    
    
    
    
    
//     // ---------------------------------------
//     // Salidas hacia el registro ID/EX
//     // ---------------------------------------
//     assign idex_pc_plus4 = id_pc_plus4;

//     assign idex_rs1 = rs1;
//     assign idex_rs2 = rs2;
//     assign idex_rd  = rd;

//     assign idex_rs1_data = rs1_data;
//     assign idex_rs2_data = rs2_data;

//     assign idex_imm = imm;
    
    
//     // Instancias internas (rv_decoder.v, regfile32.v, immgen.v, control_unit.v) (me falta ver que hago con hazard_unit.v)
    
// endmodule



`timescale 1ns / 1ps
/*
INSTRUCTION DECODE (ID STAGE)

- Decodifica la instrucción recibida desde IF/ID.
- Lee los operandos desde el register file.
- Genera el inmediato extendido (32 bits).
- Calcula el código de operación de la ALU (alu_op) usando rv_decoder.
- Entrega todo el bundle listo para el registro ID/EX.

Por ahora, stall_id / flush_idex / id_valid no se usan adentro
de este módulo: se aplican en el registro ID/EX.
*/

module id_stage #(
    parameter NB_OP = 6
)(
    // Señales globales
    input  wire         clk,
    input  wire         reset,
    input  wire         stall_id,    // reservado para uso futuro (ID/EX)
    input  wire         flush_idex,  // reservado para uso futuro (ID/EX)
    
    // Entradas desde IF/ID Register
    input  wire [31:0]  id_pc,
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
    output wire [NB_OP-1:0] idex_alu_op
);

    // ---------------------------------------
    // Señales internas desde el decoder
    // ---------------------------------------
    wire [4:0]       rs1;
    wire [4:0]       rs2;
    wire [4:0]       rd;
    wire [NB_OP-1:0] alu_op;
    wire             is_rtype;
    wire             is_itype;
    wire signed [11:0] imm_i;  // no lo usamos aquí, pero sale del decoder

    // Instancia del decoder (tal cual lo definiste)
    rv_decoder #(
        .NB_OP(NB_OP)
    ) dec_i (
        .instr   (id_instr),
        .rs1     (rs1),
        .rs2     (rs2),
        .rd      (rd),
        .alu_op  (alu_op),
        .is_rtype(is_rtype),
        .is_itype(is_itype),
        .imm_i   (imm_i)
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
        .raddr1(rs1),
        .raddr2(rs2),
        .rdata1(rs1_data),
        .rdata2(rs2_data),
        .we    (wb_we),
        .waddr (wb_rd),
        .wdata (wb_wdata)
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

endmodule
