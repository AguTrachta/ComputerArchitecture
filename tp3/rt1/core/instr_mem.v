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

//    initial begin
        // luego: $readmemh("coe/program.hex", rom);
        // por ahora hardcodeamos un archivo mini tipo "program_m0.hex"
        //$readmemh("D:/Facultad/arquitectura de computadoras/ComputerArchitecture/tp3/coe/program_m0.hex", rom);
        //$readmemh("D:/Facultad/arquitectura de computadoras/tp3/tp3/coe/program_branches_jumps.hex", rom);
//        $readmemh("/home/agus/Documentos/UNC-IC/Arqui_comp/2025/ComputerArchitecture/tp3/coe/program_branches_jumps.hex", rom);
//    end

    always @(posedge clk) begin
        if (prog_we) begin
            mem[prog_addr[ADDR_W+1:2]] <= prog_wdata;
        end
    end

    // addr[31:2] = índice de palabra alineada a 4 bytes
    //assign instr = rom[addr[31:2]];
    assign instr = mem[addr[31:2]];

endmodule
