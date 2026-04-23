`timescale 1ns/1ps

module top_mem_wb #(
    parameter integer DMEM_BYTES = 4096
)(
    input  wire clk,
    input  wire reset,
    
    // Entradas "EX/MEM simuladas"
    input  wire        exmem_valid,
    input  wire [31:0] exmem_alu_out,    // addr efectiva (LW/SW) o resultado ALU
    input  wire [31:0] exmem_rs2_fwd,    // dato a escribir (SW)
    input  wire [4:0]  exmem_rd,
    
    input  wire        exmem_RegWrite,
    input  wire        exmem_MemRead,
    input  wire        exmem_MemWrite,
    input  wire        exmem_MemToReg,
    // Para SB/SH/LB/LH TESTEAR
    //input  wire [2:0]  exmem_funct3,
    
    // Observables de WB
    output wire        wb_valid,
    output wire        wb_RegWrite,
    output wire [4:0]  wb_rd,
    output wire [31:0] wb_wdata
);

// instanciar un mem_stage que contiene data_mem     - Mepa que los hago sin stage, directo noma
// instanciar un wb_stage que contiene un wb_mux

// instanciar un mem/wb register que lleva los datos de data_mem a wb_mux

    // ============================================================
    // DATA MEM (BRAM-friendly, rdata registrada)
    // ============================================================
    
    wire do_write = exmem_valid && exmem_MemWrite;
    wire do_read  = exmem_valid && exmem_MemRead;

    // Por ahora: SW/LW palabra completa
    wire [3:0] byte_en = do_write ? 4'b1111 : 4'b0000;

    // Para evitar lecturas/escrituras fuera de caso
    wire [31:0] mem_addr = (do_read || do_write) ? exmem_alu_out : 32'h0000_0000;

    wire [31:0] dmem_rdata;

    data_mem #(
        .DEPTH_BYTES(DMEM_BYTES)
    ) u_dmem (
        .clk     (clk),
        .reset   (reset),
        .addr    (mem_addr),
        .wdata   (exmem_rs2_fwd),
        .we      (do_write),
        .byte_en (byte_en),
        .rdata   (dmem_rdata)
    );

    // ===========================
    // MEM/WB REGISTER (pipeline latch) - NO captura dmem_rdata porque la RAM ya lo registra (BRAM) TESTEAR
    // ===========================
    
    wire        wb_valid_i;
    wire [31:0] wb_alu_out_i;
    wire [4:0]  wb_rd_i;
    wire        wb_RegWrite_i;
    wire        wb_MemToReg_i;
    
    mem_wb_reg u_mem_wb (
        .clk         (clk),
        .reset       (reset),
        .en          (1'b1),        // FORZADA

        .mem_valid_in(exmem_valid),
        .alu_out_in  (exmem_alu_out),
        .rd_in       (exmem_rd),
        .RegWrite_in (exmem_RegWrite),
        .MemToReg_in (exmem_MemToReg),

        .wb_valid    (wb_valid_i),
        .wb_alu_out  (wb_alu_out_i),
        .wb_rd       (wb_rd_i),
        .wb_RegWrite (wb_RegWrite_i),
        .wb_MemToReg (wb_MemToReg_i)
    );
    
    // ============================================================
    // WB mux (MemToReg)
    // ============================================================
    
    wb_mux u_wb (
        .mem_rdata (dmem_rdata),
        .alu_out   (wb_alu_out_i),
        .MemToReg  (wb_MemToReg_i),
        .wb_wdata  (wb_wdata)
    );


    // Exporto señales de WB
    assign wb_valid    = wb_valid_i;
    assign wb_RegWrite = wb_RegWrite_i;
    assign wb_rd       = wb_rd_i;

endmodule