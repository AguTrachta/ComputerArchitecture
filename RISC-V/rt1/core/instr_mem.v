// rtl/core/instr_mem.v
`timescale 1ns / 1ps

module instr_mem #(
    // Este parámetro hay que agregarlo al top y a la debug unit
    parameter ADDR_W = 10  // 2^10 words = 1024 instrucciones
)(
    input  wire        clk,
    
    input  wire [31:0] addr,    // dirección en bytes
    output wire [31:0] instr,
    
    // Control para Debug Unit
    input  wire        prog_we,
    input  wire [31:0] prog_addr,
    input  wire [31:0] prog_wdata 
);
    localparam DEPTH = 1 << ADDR_W;

    //reg [31:0] rom [0:DEPTH-1];
    reg [31:0] mem [0:DEPTH-1];
    
    // FIX LINTER:
    // ----------------------------
    // Dirección de programación
    // ----------------------------
    wire [ADDR_W-1:0] prog_word_addr = prog_addr[ADDR_W+1:2];
    wire [1:0]        prog_offset    = prog_addr[1:0];
    wire              prog_aligned   = (prog_offset == 2'b00);
    wire              prog_in_range  = (prog_addr[31:ADDR_W+2] == {(32-(ADDR_W+2)){1'b0}});

    always @(posedge clk) begin
        if (prog_we && prog_aligned && prog_in_range) begin
            mem[prog_word_addr] <= prog_wdata;
        end
    end

    // addr[31:2] = índice de palabra alineada a 4 bytes
     // FIX LINTER: Consumo de LSB. Instrucciones deberían venir a partir del 3er bit de addr, si por error llega una dirección no alineada mando NOP
    // ----------------------------
    // Dirección de fetch
    // ----------------------------
    wire [ADDR_W-1:0] fetch_word_addr = addr[ADDR_W+1:2];
    wire [1:0]        fetch_offset    = addr[1:0];
    wire              fetch_aligned   = (fetch_offset == 2'b00);
    wire              fetch_in_range  = (addr[31:ADDR_W+2] == {(32-(ADDR_W+2)){1'b0}});
    
    assign instr = (fetch_aligned && fetch_in_range) ? mem[fetch_word_addr] : 32'h0000_0013;
    //assign instr = mem[addr[31:2]];

endmodule
