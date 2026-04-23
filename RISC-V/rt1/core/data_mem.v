`timescale 1ns / 1ps

/* Memoria de datos del mem_stage
 * - addr es byte-address; internamente usa word addressing (addr[31:2]).
 * - Escritura sincrónica con mascara byte_en (permite Store Word y deja listo Store Byte/Half Byte).
 * - Lectura sincrónica (rdata va en registro primero).
 * - Politica write-first: si se escribe en memoria, la salida refleja el valor actualizado al toque.
 */

module data_mem #(
    parameter DEPTH_BYTES = 4096,  // 4KB
    parameter DEPTH_WORDS = (DEPTH_BYTES / 4),  // 1024
    parameter WORD_AW     = $clog2(DEPTH_WORDS) //10
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire [3:0]  byte_en,
    output wire [31:0] rdata,
    output wire        busy_clear // Podríamos ver de implementarla con rsta_busy si algo no funciona bien con los tiempos de R o W
    
    // Se usa un mux para seleccionar si el control es desde el pipeline o de la debug unit
    //input  wire [WORD_AW-1:0]   i_dbg_mem_idx, // Dirección de memoria a leer
    //output wire [31:0]          o_dbg_mem_data // Datos de la memoria a leer
);

    // Cantidad de palabras de 32 bits (DEPTH_BYTES debe ser múltiplo de 4)
    //localparam integer DEPTH_WORDS = (DEPTH_BYTES / 4); // 1024
    //localparam integer WORD_AW     = $clog2(DEPTH_WORDS); //10
    
    // Tamaño de la memoria es 4KB
    // Como puedo almacenar hasta Half-Word (2 Bytes) --> 8 bits * 4 = 32 bits
    // La profundidad de la memoria será de 1024
    // Para recorrer 1024, necesito 10 bits
    // Teniendo en cuenta el tamao original de 4KB, necesito recorrer con 12 bits
    // de bits 11 a 2 recorro diferentes direcciones de memoria
    // de bits 1 a 0 recorro diferentes posiciones en una dirección
    
    
/* // BLOQUE ORIGINAL START
    // Memoria word-addressable (BRAM-friendly)
    (* ram_style = "block" *) reg [31:0] mem [0:DEPTH_WORDS-1];

    // Índice de palabra (usa sólo los bits necesarios)
    wire [WORD_AW-1:0] word_addr = addr[WORD_AW+1 : 2];

    // Rango: si bits altos por encima del índice son 0, entonces está dentro
    wire in_range = (addr[31 : WORD_AW+2] == { (32-(WORD_AW+2)) {1'b0} });

    // Para C2/C3 no exigimos alineación a palabra acá.
    // La selección fina de bytes la hace byte_en y luego, en C3, la extracción.
    wire access_ok = in_range;

    // Word leído (si no es válido, devolvemos 0)
    wire [31:0] mem_word = access_ok ? mem[word_addr] : 32'h0000_0000;

    // Merge del word con byte_en (máscara por byte)
    reg [31:0] merged;
    always @(*) begin
        merged = mem_word;
        if (byte_en[0]) merged[7:0]   = wdata[7:0]  ;
        else            merged[7:0]   = 8'h00;
        if (byte_en[1]) merged[15:8]  = wdata[15:8] ;
        else            merged[15:8]  = 8'h00;
        if (byte_en[2]) merged[23:16] = wdata[23:16];
        else            merged[23:16] = 8'h00;
        if (byte_en[3]) merged[31:24] = wdata[31:24];
        else            merged[31:24] = 8'h00;
    end

    // Lectura combinacional:
    // - si es un load, sale mem_word
    // - si es un store, mostramos merged (write-first)
    assign rdata = access_ok ? (we ? merged : mem_word) : 32'h0000_0000;
    
    
    always @(posedge clk) begin
        if (reset) begin
        end 
        
        else begin
            if (access_ok && we) begin
                mem[word_addr] <= merged;
            end
        end
    end
*/ // BLOQUE ORIGINAL END

    // Dirección por palabra --> 10 bits
    //wire [WORD_AW-1:0] word_addr = addr[WORD_AW+1:2];
    wire [1:0]         byte_offset  = addr[1:0];
    wire               aligned_word = (byte_offset == 2'b00);
    
    // Offset de Byte dentro de una palabra --> 2 bits
    //wire [1:0] byte_offset  = addr[1:0];

    // Rango válido
    wire in_range = (addr[31:WORD_AW+2] == {(32-(WORD_AW+2)){1'b0}}); // Verifico que no se pase de 12 bits
    wire allow_unaligned = 1'b1; // para evitar linter warning de 2 bits no usados en addr, los consumo con algo que da 1 siempre.
    wire access_ok = in_range && (allow_unaligned || aligned_word); // Si está en rango puedo operar, si no lo está, no lo dejo (Ta bien?)
    // wire access_ok = in_range;
    
    // Salida del IP
    wire [31:0] douta;
    reg  access_ok_r;

    // Para escrituras por byte
    wire [3:0] wea_i = (access_ok && we) ? byte_en : 4'b0000;
    
    always @(posedge clk) begin
        if (reset)
            access_ok_r <= 1'b0;
        else
            access_ok_r <= access_ok;
    end
    
    // ----------------------------------------------------------------
    // IP core de memoria
    // ----------------------------------------------------------------
    blk_mem_gen_0 u_dmem (
        .clka   (clk),
        .rsta   (reset),
        .ena    (access_ok),
        .wea    (wea_i),
        .addra  (addr),
        .dina   (wdata),
        .douta  (douta),
        .rsta_busy() // Podríamos ver de implementarla si algo no funciona bien con los tiempos de R o W
    );
    
    assign rdata      = access_ok_r ? douta : 32'h0000_0000;
    assign busy_clear = 1'b0; // Podríamos ver de implementarla con rsta_busy si algo no funciona bien con los tiempos de R o W
    
endmodule
