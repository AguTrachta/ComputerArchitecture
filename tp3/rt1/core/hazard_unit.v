`timescale 1ns/1ps

// ===============================================================
// HAZARD UNIT
// Detecta únicamente el hazard LOAD-USE (RAW de LW seguido por uso)
// Si se detecta el hazard, genera:
//   - stall_if     = 1  → PC no avanza
//   - stall_id     = 1  → IF/ID latch no avanza
//   - flush_idex   = 1  → ID/EX latch se llena con burbuja (NO-OP)
// ===============================================================

module hazard_unit(
    // Señales desde IF/ID (ID Stage)
    input  wire [4:0] ifid_rs1,
    input  wire [4:0] ifid_rs2,

    // Señales desde ID/EX (EX Stage)
    input  wire [4:0] idex_rd,
    input  wire       idex_MemRead,

    // Salidas de control
    output wire       stall_if,
    output wire       stall_id,
    output wire       flush_idex
);

    // ------------------------------------------------------------
    // LOAD-USE HAZARD:
    //   Si la instrucción en EX es un LW (idex_MemRead = 1)
    //   Y su rd coincide con rs1 o rs2 de la instrucción en ID,
    //   entonces hay dependencia RAW imposible de resolver sin stall.
    // ------------------------------------------------------------

    wire load_use_hazard;
    assign load_use_hazard =
           idex_MemRead &&
           (idex_rd != 5'd0) &&                   // evitar dependencias con x0
           ((idex_rd == ifid_rs1) ||
            (idex_rd == ifid_rs2));

    // ------------------------------------------------------------
    // SALIDAS
    // ------------------------------------------------------------
    assign stall_if   = load_use_hazard;   // Congela PC (no IF/PC update)
    assign stall_id   = load_use_hazard;   // Congela IF/ID latch
    assign flush_idex = load_use_hazard;   // Inserta burbuja en EX

endmodule
