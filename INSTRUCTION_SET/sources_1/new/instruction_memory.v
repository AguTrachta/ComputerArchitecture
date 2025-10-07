`timescale 1ns / 1ps

module instruction_memory (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] mem [0:255]; // 256 palabras = 1KB

    initial begin
        // Ejemplo: tres instrucciones R-type (ADD, XOR, SUB)
        mem[0] = 32'b0000000_00010_00001_000_00011_0110011; // ADD x3,x1,x2
        mem[1] = 32'b0000000_00010_00011_100_00100_0110011; // XOR x4,x3,x2
        mem[2] = 32'b0100000_00011_00100_000_00101_0110011; // SUB x5,x4,x3
    end

    assign instr = mem[addr[9:2]]; // acceso por palabra (word address)
endmodule
