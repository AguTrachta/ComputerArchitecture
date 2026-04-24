`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/16/2026 10:47:09 PM
// Design Name: 
// Module Name: tb_uart_1
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


module tb_uart_1;

  localparam CLK_FREQ  = 100_000_000;
  localparam BAUD_RATE = 9600;
  localparam CLK_PER   = 10;                 // 100 MHz -> 10 ns
  localparam BIT_TIME  = 1_000_000_000 / BAUD_RATE; // ns por bit

  reg clk, reset;
  reg rx;
  wire tx;

  // DUT
  top #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) dut (
    .clk(clk),
    .reset(reset),
    .rx(rx),
    .tx(tx)
  );

  integer cyc;
  integer i;

  // ------------------------------------------------------------
  // Programa de prueba
  // ------------------------------------------------------------
  localparam PROG_WORDS = 4;

  reg [31:0] program_mem [0:PROG_WORDS-1];

  initial begin
    // ejemplo mínimo:
    // addi x1, x0, 5
    // addi x2, x0, 7
    // add  x3, x1, x2
    // halt/custom o nop según tu diseño
    program_mem[0] = 32'h00500093; // addi x1, x0, 5
    program_mem[1] = 32'h00700113; // addi x2, x0, 7
    program_mem[2] = 32'h002081b3; // add x3, x1, x2
    program_mem[3] = 32'hffffffff; // HALT custom (si lo usás)
  end

  // ------------------------------------------------------------
  // Clock
  // ------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #(CLK_PER/2) clk = ~clk;
  end

  // ------------------------------------------------------------
  // Reset + línea UART idle
  // ------------------------------------------------------------
  initial begin
    rx    = 1'b1; // UART idle
    reset = 1'b1;
    repeat (10) @(posedge clk);
    reset = 1'b0;
  end

  // ------------------------------------------------------------
  // Waves
  // ------------------------------------------------------------
  initial begin
    $dumpfile("tb_uart_1.vcd");
    $dumpvars(0, tb_uart_1);
  end

  // ------------------------------------------------------------
  // Helper: enviar 1 byte por UART (8N1)
  // LSB-first en UART
  // ------------------------------------------------------------
  task uart_send_byte;
    input [7:0] data;
    integer b;
    begin
      // start bit
      rx = 1'b0;
      #(BIT_TIME);

      // 8 data bits, LSB first
      for (b = 0; b < 8; b = b + 1) begin
        rx = data[b];
        #(BIT_TIME);
      end

      // stop bit
      rx = 1'b1;
      #(BIT_TIME);

      // pequeño margen entre bytes
      #(BIT_TIME/2);
    end
  endtask

  // ------------------------------------------------------------
  // Helper: enviar palabra de 32 bits MSB-first
  // (como espera la debug unit)
  // ------------------------------------------------------------
  task uart_send_word_be;
    input [31:0] w;
    begin
      uart_send_byte(w[31:24]);
      uart_send_byte(w[23:16]);
      uart_send_byte(w[15:8]);
      uart_send_byte(w[7:0]);
    end
  endtask

  // ------------------------------------------------------------
  // Helper: cargar programa completo
  // protocolo:
  //   CMD_PROG_BEGIN
  //   len_hi
  //   len_lo
  //   4*len bytes
  // ------------------------------------------------------------
  task uart_load_program;
      input integer words;
      integer k;
      begin
        // clear
        uart_send_byte(8'h40);
        wait_dbg_idle();
    
        // begin
        uart_send_byte(8'h10);
        uart_send_byte(words[15:8]);
        uart_send_byte(words[7:0]);
    
        for (k = 0; k < words; k = k + 1) begin
          uart_send_word_be(program_mem[k]);
        end
    
        // esperar fin de programación + reset_exec interno
        wait_dbg_idle();
      end
  endtask
  
  
  
    task wait_dbg_idle;
    begin
      wait (dut.dbg_u.state == dut.dbg_u.ST_IDLE);
      repeat (5) @(posedge clk);
    end
    endtask
  
    task wait_wb_event;
    begin
      wait (dut.wb_we == 1'b1);
      repeat (2) @(posedge clk);
    end
    endtask
  

  // ------------------------------------------------------------
  // Estímulo principal
  // ------------------------------------------------------------
  initial begin
    wait(reset == 1'b0);
    repeat (20) @(posedge clk);

    $display("=== Cargando programa por UART ===");
    uart_load_program(PROG_WORDS);

    // Esperar a que la debug unit termine de escribir IMEM
    repeat (2000) @(posedge clk);

    // --------------------------------------------------------
    // Verificación básica de IMEM por jerarquía
    // AJUSTAR nombres de instancia según tu top:
    // ejemplo: dut.if_s.imem_i.mem[0]
    // --------------------------------------------------------
    $display("=== Verificando IMEM ===");
    if (dut.if_s.imem_i.mem[0] !== program_mem[0]) begin
      $display("ERR IMEM[0] got=%h exp=%h", dut.if_s.imem_i.mem[0], program_mem[0]);
      $finish;
    end
    if (dut.if_s.imem_i.mem[1] !== program_mem[1]) begin
      $display("ERR IMEM[1] got=%h exp=%h", dut.if_s.imem_i.mem[1], program_mem[1]);
      $finish;
    end
    if (dut.if_s.imem_i.mem[2] !== program_mem[2]) begin
      $display("ERR IMEM[2] got=%h exp=%h", dut.if_s.imem_i.mem[2], program_mem[2]);
      $finish;
    end
    if (dut.if_s.imem_i.mem[3] !== program_mem[3]) begin
      $display("ERR IMEM[3] got=%h exp=%h", dut.if_s.imem_i.mem[3], program_mem[3]);
      $finish;
    end

    $display("OK: IMEM cargada correctamente por UART");

    // --------------------------------------------------------
    // STEP de prueba
    // --------------------------------------------------------
    $display("=== Ejecutando 1 STEP ===");
    uart_send_byte(8'h21); // CMD_STEP
    wait_dbg_idle();
    repeat (20) @(posedge clk);

    // --------------------------------------------------------
    // RUN continuo
    // --------------------------------------------------------
    $display("=== Ejecutando RUN ===");
    uart_send_byte(8'h20); // CMD_RUN

    // Esperar un rato a que corra
    repeat (500000) @(posedge clk);

    $display("=== Fin del test básico ===");
    $finish;
  end

  // ------------------------------------------------------------
  // Traza básica por ciclo
  // AJUSTAR señales según tu top real
  // ------------------------------------------------------------
    reg [3:0] prev_dbg_state;
    
    initial begin
      cyc = 0;
      prev_dbg_state = 0;
    end
    
    always @(posedge clk) begin
      #1;
      cyc = cyc + 1;
    
      if (!reset) begin
        if (dut.dbg_u.state != prev_dbg_state || dut.dbg_prog_we || dut.wb_we) begin
          $display("C%0d | rx=%b | dbg_state=%0d | prog_we=%b prog_addr=%h prog_wdata=%h | wb_we=%b rd=%0d wd=%h",
                   cyc,
                   rx,
                   dut.dbg_u.state,
                   dut.dbg_prog_we,
                   dut.dbg_prog_addr,
                   dut.dbg_prog_wdata,
                   dut.wb_we,
                   dut.wb_rd_idx,
                   dut.wb_write_data);
        end
      end
    
      prev_dbg_state = dut.dbg_u.state;
    
      if (cyc > 5000000) begin
        $display("TIMEOUT");
        $finish;
      end
    end
    
endmodule
