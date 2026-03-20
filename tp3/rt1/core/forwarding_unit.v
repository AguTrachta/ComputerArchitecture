`timescale 1ns / 1ps

module forwarding_unit (
  input  wire       exmem_RegWrite,
  input  wire [4:0] exmem_rd,
  input  wire       memwb_RegWrite,
  input  wire [4:0] memwb_rd,
  input  wire [4:0] idex_rs1,
  input  wire [4:0] idex_rs2,
  output reg  [1:0] fwdA,
  output reg  [1:0] fwdB
);
  always @(*) begin
    fwdA = 2'b00;
    fwdB = 2'b00;

    // EX hazard
    if (exmem_RegWrite && (exmem_rd != 0) && (exmem_rd == idex_rs1)) fwdA = 2'b10;
    if (exmem_RegWrite && (exmem_rd != 0) && (exmem_rd == idex_rs2)) fwdB = 2'b10;

    // MEM hazard (si no fue EX)
    if (memwb_RegWrite && (memwb_rd != 0) && !(exmem_RegWrite && (exmem_rd!=0) && (exmem_rd==idex_rs1))
                       && (memwb_rd == idex_rs1)) fwdA = 2'b01;

    if (memwb_RegWrite && (memwb_rd != 0) && !(exmem_RegWrite && (exmem_rd!=0) && (exmem_rd==idex_rs2))
                       && (memwb_rd == idex_rs2)) fwdB = 2'b01;
  end
endmodule