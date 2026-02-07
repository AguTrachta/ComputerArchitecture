`timescale 1ns / 1ps

/* Memoria de datos del mem_stage
 * - addr es byte-address; internamente usa word addressing (addr[31:2]).
 * - Escritura sincrónica con mascara byte_en (permite Store Word y deja listo Store Byte/Half Byte).
 * - Lectura sincrónica (rdata va en registro primero).
 * - Politica write-first: si se escribe en memoria, la salida refleja el valor actualizado al toque.
 */

module data_mem #(
    parameter integer DEPTH_BYTES = 4096  // 4KB
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire [3:0]  byte_en,
    output wire [31:0] rdata
);

    // Cantidad de palabras de 32 bits (DEPTH_BYTES debe ser múltiplo de 4)
    localparam integer DEPTH_WORDS = (DEPTH_BYTES / 4);
    localparam integer WORD_AW     = $clog2(DEPTH_WORDS);

    // Memoria word-addressable (BRAM-friendly)
    (* ram_style = "block" *) reg [31:0] mem [0:DEPTH_WORDS-1];

    // Alineación a palabra (M4: LW/SW)
    wire addr_aligned = (addr[1:0] == 2'b00);

    // Índice de palabra (usa sólo los bits necesarios)
    wire [WORD_AW-1:0] word_addr = addr[WORD_AW+1 : 2];

    // Rango: si bits altos por encima del índice son 0, entonces está dentro
    wire in_range = (addr[31 : WORD_AW+2] == { (32-(WORD_AW+2)) {1'b0} });

    // Acceso válido (en rango y alineado)
    wire access_ok = in_range && addr_aligned;

    // Word leído (si no es válido, devolvemos 0)
    wire [31:0] mem_word = access_ok ? mem[word_addr] : 32'h0000_0000;

    // Merge del word con byte_en (máscara por byte)
    reg [31:0] merged;
    always @(*) begin
        merged = mem_word;
        if (byte_en[0]) merged[7:0]   = wdata[7:0];
        if (byte_en[1]) merged[15:8]  = wdata[15:8];
        if (byte_en[2]) merged[23:16] = wdata[23:16];
        if (byte_en[3]) merged[31:24] = wdata[31:24];
    end

    // Salida registrada (lectura sincrónica)
    reg [31:0] rdata_reg;
    assign rdata = rdata_reg;

    always @(posedge clk) begin
        if (reset) begin
            rdata_reg <= 32'h0000_0000;
        end else begin
            if (access_ok) begin
                if (we) begin
                    // write-first: escribo y también actualizo rdata con lo nuevo
                    mem[word_addr] <= merged;
                    rdata_reg      <= merged;
                end else begin
                    // lectura: registro lo que hay en memoria
                    rdata_reg      <= mem_word;
                end
            end else begin
                rdata_reg <= 32'h0000_0000;
            end
        end
    end

endmodule
