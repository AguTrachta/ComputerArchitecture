// rtl/core/instr_mem.v
`timescale 1ns / 1ps

module instr_mem #(
    parameter ADDR_W = 10  // 2^10 words = 1024 instrucciones
)(
    input  wire [31:0] addr,    // dirección en bytes
    output wire [31:0] instr
);
    localparam DEPTH = 1 << ADDR_W;

    reg [31:0] rom [0:DEPTH-1];

    initial begin
        // luego: $readmemh("coe/program.hex", rom);
        // por ahora hardcodeamos un archivo mini tipo "program_m0.hex"
        $readmemh("D:/Facultad/arquitectura de computadoras/ComputerArchitecture/tp3/coe/program_m0.hex", rom);
    end

    // addr[31:2] = índice de palabra alineada a 4 bytes
    assign instr = rom[addr[31:2]];

endmodule
