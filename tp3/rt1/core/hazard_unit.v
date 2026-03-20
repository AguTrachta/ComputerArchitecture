`timescale 1ns/1ps

/*
===============================================================================
HAZARD UNIT
===============================================================================

Este módulo detecta dependencias de datos que pueden producir hazards en el
pipeline, especialmente cuando la instrucción en ID es un branch (BEQ/BNE).

Los branches son problemáticos porque necesitan comparar rs1 y rs2 para decidir
si el salto se toma o no. Si alguno de esos registros todavía no fue escrito por
una instrucción anterior, el comparador del branch recibiría un valor incorrecto.

Para evitar esto, el hazard unit puede:
    - detener el avance del pipeline (stall)
    - eliminar la instrucción que entró a EX (flush del latch ID/EX)

Las señales generadas son:
    stall_if   → detiene el PC y el IF stage
    stall_id   → detiene el IF/ID register
    flush_idex → inserta un NOP en el latch ID/EX

De esta forma el branch permanece en ID hasta que los datos correctos estén
disponibles.

-------------------------------------------------------------------------------
CASOS DE HAZARD DETECTADOS
-------------------------------------------------------------------------------

1) LOAD-USE clásico

    lw  x1, ...
    add x2, x1, x3

El valor cargado por el `lw` recién está disponible al final del stage MEM.
La instrucción siguiente intenta usar ese valor demasiado pronto.

Pipeline simplificado:

    C1  IF  lw
    C2  ID  lw    IF  add
    C3  EX  lw    ID  add   ← hazard

Solución:
    - stall de IF e ID
    - flush de ID/EX

Esto introduce un "bubble" que permite que el dato llegue desde MEM.

-------------------------------------------------------------------------------
2) Branch dependiente de instrucción en EX

    add x1, ...
    beq x1, x2, L

El branch necesita comparar x1 con x2, pero x1 todavía está siendo calculado
por la ALU en el stage EX.

Pipeline:

    C1  IF  add
    C2  ID  add   IF  beq
    C3  EX  add   ID  beq   ← hazard

El resultado de `add` recién estará disponible al final de EX.

Solución:
    - stall de IF e ID
    - flush de ID/EX

Esto mantiene el branch en ID durante un ciclo extra para que el resultado
pueda ser forwardeado o ya esté disponible.

Resultado:
    penalty = 1 ciclo.

-------------------------------------------------------------------------------
3) Branch dependiente de un LOAD en MEM

    lw  x1, ...
    beq x1, x2, L

Este caso es más costoso porque el valor cargado desde memoria aparece recién
al final del stage MEM.

Pipeline:

    C1  IF  lw
    C2  ID  lw    IF  beq
    C3  EX  lw    ID  beq   ← hazard
    C4  MEM lw    ID  beq   ← todavía no disponible

El branch necesita esperar un ciclo adicional.

Solución:
    - segundo stall
    - flush del ID/EX

Resultado:
    penalty = 2 ciclos.

-------------------------------------------------------------------------------
FUNCIONAMIENTO GENERAL
-------------------------------------------------------------------------------

El hazard unit compara los registros fuente del branch (rs1, rs2) con los
registros destino de las instrucciones que están en los stages EX y MEM.

Si detecta que el branch depende de un resultado todavía no disponible:

    stall_if   = 1
    stall_id   = 1
    flush_idex = 1

Esto produce:

    - IF e ID quedan congelados
    - se inserta un NOP en EX

De esta forma el pipeline se reacomoda hasta que los datos correctos estén
disponibles para evaluar el branch.

===============================================================================
*/


module hazard_unit(
    // Señales desde IF/ID (ID stage)
    input  wire [4:0] ifid_rs1,
    input  wire [4:0] ifid_rs2,
    input  wire       ifid_is_branch,
    input  wire       ifid_is_jalr,

    // Señales desde ID/EX (EX stage)
    input  wire [4:0] idex_rd,
    input  wire       idex_RegWrite,
    input  wire       idex_MemRead,

    // Señales desde EX/MEM (MEM stage)
    input  wire [4:0] exmem_rd,
    input  wire       exmem_MemRead,

    // Salidas
    output wire       stall_if,
    output wire       stall_id,
    output wire       flush_idex
);

    wire match_idex_rs1, match_idex_rs2;
    wire match_exmem_rs1, match_exmem_rs2;

    wire load_use_hazard;
    wire branch_dep_ex_hazard;
    wire branch_dep_memload_hazard;
    wire jalr_dep_ex_hazard;
    wire jalr_dep_memload_hazard;
    wire hazard_any;

    assign match_idex_rs1  = (idex_rd  != 5'd0) && (idex_rd  == ifid_rs1);
    assign match_idex_rs2  = (idex_rd  != 5'd0) && (idex_rd  == ifid_rs2);
    assign match_exmem_rs1 = (exmem_rd != 5'd0) && (exmem_rd == ifid_rs1);
    assign match_exmem_rs2 = (exmem_rd != 5'd0) && (exmem_rd == ifid_rs2);
    
    // Hazard clásico load-use
    assign load_use_hazard =
        idex_MemRead &&
        (match_idex_rs1 || match_idex_rs2);

    // Branch en ID dependiente de resultado todavía en EX
    // (ALU o load): requiere stall
    assign branch_dep_ex_hazard =
        ifid_is_branch &&
        idex_RegWrite &&
        (match_idex_rs1 || match_idex_rs2);

    // Branch en ID dependiente de un load que está en MEM:
    // hace falta un stall adicional
    assign branch_dep_memload_hazard =
        ifid_is_branch &&
        exmem_MemRead &&
        (match_exmem_rs1 || match_exmem_rs2);

    // JALR en ID depende solo de rs1 
    assign jalr_dep_ex_hazard =
        ifid_is_jalr &&
        idex_RegWrite &&
        match_idex_rs1;

    assign jalr_dep_memload_hazard =
        ifid_is_jalr &&
        exmem_MemRead &&
        match_exmem_rs1;

    assign hazard_any =
        load_use_hazard ||
        branch_dep_ex_hazard ||
        branch_dep_memload_hazard ||
        jalr_dep_ex_hazard ||
        jalr_dep_memload_hazard;
    
    assign stall_if   = hazard_any;
    assign stall_id   = hazard_any;
    assign flush_idex = hazard_any;

endmodule
