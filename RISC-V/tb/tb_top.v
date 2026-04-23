`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2026 12:13:16 AM
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top;

  // -------------------------
  // Parámetros del DUT
  // -------------------------
  localparam NB_OP      = 6;
  localparam DMEM_BYTES = 4096;

  // -------------------------
  // Señales DUT (Verilog)
  // -------------------------
  reg  clk;
  reg  reset;

  // Instancia del DUT
  top #(
    .NB_OP(NB_OP),
    .DMEM_BYTES(DMEM_BYTES)
  ) dut (
    .clk   (clk),
    .reset (reset)
  );

  // -------------------------
  // Clock: 100 MHz (T=10ns)
  // -------------------------
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // -------------------------
  // Reset
  // -------------------------
  initial begin
    reset = 1'b1;
    repeat (5) @(posedge clk);
    reset = 1'b0;
  end

  // -------------------------
  // Dump de ondas (Icarus/GTKWave)
  // -------------------------
  initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
  end

  // -------------------------
  // Debug / watchdog
  // -------------------------
  integer cycles;
  reg [31:0] prev_pc;

  // init
  initial begin
    cycles  = 0;
    prev_pc = 32'h0;
  end

  // Función para detectar X en un bus
  function has_x32;
    input [31:0] v;
    begin
      has_x32 = (^v === 1'bx); // reducción XOR -> x si hay x/z
    end
  endfunction

  always @(posedge clk) begin
    cycles = cycles + 1;

    if (!reset) begin

      // Print compacto por ciclo (una sola línea)
      $display("[%0t] C%0d PC=%08h IF_INSTR=%08h | IDv=%0b stall=%0b flush=%0b | ID: RW=%0b MR=%0b MW=%0b M2R=%0b AS=%0b | EX: ALU=%08h RD=%0d | WB: we=%0b rd=%0d wdata=%08h",
               $time, cycles,
               dut.w_if_pc, dut.w_if_instr,
               dut.w_id_valid, dut.w_stall, dut.w_flush,
               dut.w_id_RegWrite, dut.w_id_MemRead, dut.w_id_MemWrite, dut.w_id_MemToReg, dut.w_id_ALUSrc,
               dut.w_ex_alu_out, dut.w_ex_rd,
               dut.w_wb_we, dut.w_wb_rd_out, dut.w_wb_wdata);
    
      // Chequeos básicos
      if (has_x32(dut.w_if_pc)) begin
        $display("FATAL: PC en X -> revisar reset/IF");
        $finish;
      end
    
      if (has_x32(dut.w_if_instr)) begin
        $display("FATAL: IF_INSTR en X -> revisar imem/if_stage");
        $finish;
      end
    
      // Check de avance PC (solo si no hay stall/flush)
      if (!dut.w_stall && !dut.w_flush) begin
        if ((cycles > 2) && (dut.w_if_pc != (prev_pc + 32'd4))) begin
          $display("WARN: PC no incrementó +4 (prev=%08h now=%08h)",
                   prev_pc, dut.w_if_pc);
        end
      end
    
      prev_pc = dut.w_if_pc;
    
    end else begin
      prev_pc = 32'h0;
    end

    // Cortar la sim
    if (cycles == 80) begin
      $display("FIN: 80 ciclos ejecutados.");
      $finish;
    end
  end

endmodule
