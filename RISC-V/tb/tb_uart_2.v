`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/19/2026 12:32:35 AM
// Design Name: 
// Module Name: tb_uart_2
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


module tb_uart_2;

  localparam CLK_FREQ  = 100_000_000;
  localparam BAUD_RATE = 9600;
  localparam CLK_PER   = 10; // 100 MHz -> 10 ns
  localparam BIT_TIME  = 1_000_000_000 / BAUD_RATE; // ns por bit

  // UART commands
  localparam [7:0] CMD_PROG_BEGIN = 8'h10;
  localparam [7:0] CMD_RUN        = 8'h20;
  localparam [7:0] CMD_STEP       = 8'h21;
  localparam [7:0] CMD_STOP       = 8'h22;
  localparam [7:0] CMD_CLEAR_IMEM = 8'h40;

  reg clk, reset;
  reg rx;
  wire tx;

  integer cyc;
  integer i;

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

  // ============================================================
  // Programas de prueba
  // ============================================================

  localparam PROG1_WORDS = 4; // run + halt
  reg [31:0] prog_run_halt [0:PROG1_WORDS-1];

  localparam PROG2_WORDS = 4; // steps
  reg [31:0] prog_steps [0:PROG2_WORDS-1];

  localparam PROG3_WORDS = 8; // run + stop + continue
  reg [31:0] prog_stop_resume [0:PROG3_WORDS-1];

  initial begin
    // Programa 1: addi/addi/add/halt
    prog_run_halt[0] = 32'h00500093; // addi x1, x0, 5
    prog_run_halt[1] = 32'h00700113; // addi x2, x0, 7
    prog_run_halt[2] = 32'h002081b3; // add  x3, x1, x2
    prog_run_halt[3] = 32'hffffffff; // HALT

    // Programa 2: igual al anterior, para step por ciclo
    prog_steps[0] = 32'h00500093;
    prog_steps[1] = 32'h00700113;
    prog_steps[2] = 32'h002081b3;
    prog_steps[3] = 32'hffffffff;

    // Programa 3: más largo para probar stop/continue
    prog_stop_resume[0] = 32'h00100093; // addi x1, x0, 1
    prog_stop_resume[1] = 32'h00200113; // addi x2, x0, 2
    prog_stop_resume[2] = 32'h00300193; // addi x3, x0, 3
    prog_stop_resume[3] = 32'h00400213; // addi x4, x0, 4
    prog_stop_resume[4] = 32'h00500293; // addi x5, x0, 5
    prog_stop_resume[5] = 32'h00600313; // addi x6, x0, 6
    prog_stop_resume[6] = 32'h00700393; // addi x7, x0, 7
    prog_stop_resume[7] = 32'hffffffff; // HALT
  end

  // ============================================================
  // Clock / reset
  // ============================================================

  initial begin
    clk = 1'b0;
    forever #(CLK_PER/2) clk = ~clk;
  end

  initial begin
    rx    = 1'b1; // UART idle
    reset = 1'b1;
    cyc   = 0;
    repeat (10) @(posedge clk);
    reset = 1'b0;
  end

  initial begin
    $dumpfile("tb_uart_2.vcd");
    $dumpvars(0, tb_uart_2);
  end

  always @(posedge clk) begin
    #1;
    cyc = cyc + 1;
    if (cyc > 8_000_000) begin
      $display("TIMEOUT GLOBAL en C%0d", cyc);
      $finish;
    end
  end

  // ============================================================
  // Helpers UART
  // ============================================================

  task uart_send_byte;
    input [7:0] data;
    integer b;
    begin
      rx = 1'b0; #(BIT_TIME); // start
      for (b = 0; b < 8; b = b + 1) begin
        rx = data[b];
        #(BIT_TIME);
      end
      rx = 1'b1; #(BIT_TIME); // stop
      #(BIT_TIME/2);
    end
  endtask

  task uart_send_word_be;
    input [31:0] w;
    begin
      uart_send_byte(w[31:24]);
      uart_send_byte(w[23:16]);
      uart_send_byte(w[15:8]);
      uart_send_byte(w[7:0]);
    end
  endtask

  task wait_dbg_idle;
    begin
      wait (dut.dbg_u.state == dut.dbg_u.ST_IDLE);
      repeat (5) @(posedge clk);
    end
  endtask

  task send_cmd_run;
    begin
      $display("[TB ] C%0d -> CMD_RUN", cyc);
      uart_send_byte(CMD_RUN);
    end
  endtask

  task send_cmd_step;
    begin
      $display("[TB ] C%0d -> CMD_STEP", cyc);
      uart_send_byte(CMD_STEP);
    end
  endtask

  task send_cmd_stop;
    begin
      $display("[TB ] C%0d -> CMD_STOP", cyc);
      uart_send_byte(CMD_STOP);
    end
  endtask

  task load_program_from_array;
    input integer words;
    input integer selector; // 1=prog_run_halt, 2=prog_steps, 3=prog_stop_resume
    integer k;
    begin
      $display("[TB ] C%0d -> CMD_CLEAR_IMEM", cyc);
      uart_send_byte(CMD_CLEAR_IMEM);
      wait_dbg_idle();

      $display("[TB ] C%0d -> CMD_PROG_BEGIN (%0d words)", cyc, words);
      uart_send_byte(CMD_PROG_BEGIN);
      uart_send_byte(words[15:8]);
      uart_send_byte(words[7:0]);

      for (k = 0; k < words; k = k + 1) begin
        case (selector)
          1: uart_send_word_be(prog_run_halt[k]);
          2: uart_send_word_be(prog_steps[k]);
          3: uart_send_word_be(prog_stop_resume[k]);
          default: uart_send_word_be(32'h00000013);
        endcase
      end

      wait_dbg_idle();
    end
  endtask

  task check_imem_array;
    input integer words;
    input integer selector;
    integer k;
    reg [31:0] exp;
    begin
      $display("[TB ] C%0d -> Verificando IMEM (%0d words)", cyc, words);
      for (k = 0; k < words; k = k + 1) begin
        case (selector)
          1: exp = prog_run_halt[k];
          2: exp = prog_steps[k];
          3: exp = prog_stop_resume[k];
          default: exp = 32'h00000013;
        endcase

        if (dut.if_s.imem_i.mem[k] !== exp) begin
          $display("ERR IMEM[%0d] got=%h exp=%h", k, dut.if_s.imem_i.mem[k], exp);
          $finish;
        end
      end
      $display("[TB ] IMEM OK");
    end
  endtask

  // ============================================================
  // Helpers de chequeo simple
  // ============================================================

  task check_reg;
    input [4:0] idx;
    input [31:0] exp;
    begin
      if (dut.id_s.regfile_i.regs[idx] !== exp) begin
        $display("ERR REG x%0d got=%h exp=%h en C%0d", idx, dut.id_s.regfile_i.regs[idx], exp, cyc);
        $finish;
      end else begin
        $display("[TB ] REG OK x%0d = %h", idx, dut.id_s.regfile_i.regs[idx]);
      end
    end
  endtask

  task wait_some_cycles;
    input integer n;
    integer t;
    begin
      for (t = 0; t < n; t = t + 1)
        @(posedge clk);
    end
  endtask

  // ============================================================
  // Debug prints
  // ============================================================

  reg [4:0] prev_dbg_state;
  reg       prev_dbg_pipeline_en;
  reg       prev_dbg_reset_exec;
  reg       prev_cpu_end;
  reg [31:0] prev_pc;

  initial begin
    prev_dbg_state       = 0;
    prev_dbg_pipeline_en = 0;
    prev_dbg_reset_exec  = 0;
    prev_cpu_end         = 0;
    prev_pc              = 32'hxxxxxxxx;
  end

  always @(posedge clk) begin
    #1;
    if (!reset) begin
      if (dut.dbg_u.state != prev_dbg_state ||
          dut.dbg_pipeline_en != prev_dbg_pipeline_en ||
          dut.dbg_reset_exec != prev_dbg_reset_exec ||
          dut.id_halt != prev_cpu_end ||
          dut.wb_we ||
          dut.dbg_prog_we ||
          dut.if_pc != prev_pc) begin

        $display("C%0d | dbg_state=%0d pen=%b rstx=%b id_halt=%b | PC=%h IFIN=%h | prog_we=%b paddr=%h pwdata=%h | wb_we=%b rd=%0d wd=%h",
                 cyc,
                 dut.dbg_u.state,
                 dut.dbg_pipeline_en,
                 dut.dbg_reset_exec,
                 dut.id_halt,
                 dut.if_pc,
                 dut.if_instr,
                 dut.dbg_prog_we,
                 dut.dbg_prog_addr,
                 dut.dbg_prog_wdata,
                 dut.wb_we,
                 dut.wb_rd_idx,
                 dut.wb_write_data);
      end
    end

    prev_dbg_state       = dut.dbg_u.state;
    prev_dbg_pipeline_en = dut.dbg_pipeline_en;
    prev_dbg_reset_exec  = dut.dbg_reset_exec;
    prev_cpu_end         = dut.id_halt;
    prev_pc              = dut.if_pc;
  end

  // Print más orientado a pipeline en modo STEP
  always @(posedge clk) begin
    #1;
    if (!reset && (dut.dbg_u.state == dut.dbg_u.ST_STEP_ARM ||
                   dut.dbg_u.state == dut.dbg_u.ST_STEP_EXEC)) begin
      $display("[STEPDBG] C%0d | IF:pc=%h in=%h | IFID:v=%b in=%h | IDEX:v=%b rd=%0d | EXMEM:v=%b rd=%0d | MEMWB:v=%b rd=%0d",
               cyc,
               dut.if_pc, dut.if_instr,
               dut.ifid_valid, dut.ifid_instr,
               dut.idex_valid, dut.idex_rd_idx,
               dut.exmem_valid, dut.exmem_rd_idx,
               dut.memwb_valid, dut.memwb_rd_idx);
    end
  end

  // ============================================================
  // Pruebas
  // ============================================================

  initial begin
    wait(reset == 1'b0);
    wait_some_cycles(20);

    // ----------------------------------------------------------
    // TEST 1: LOAD + RUN + HALT
    // ----------------------------------------------------------
    $display("\n================ TEST 1: LOAD + RUN + HALT ================\n");
    load_program_from_array(PROG1_WORDS, 1);
    check_imem_array(PROG1_WORDS, 1);

    send_cmd_run();
    wait_dbg_idle();         // debería volver a IDLE por id_halt
    wait_some_cycles(20);

    check_reg(5'd1, 32'd5);
    check_reg(5'd2, 32'd7);
    check_reg(5'd3, 32'd12);

    // ----------------------------------------------------------
    // TEST 2: LOAD + varios STEP
    // ----------------------------------------------------------
    $display("\n================ TEST 2: LOAD + STEP x ciclos ================\n");
    load_program_from_array(PROG2_WORDS, 2);
    check_imem_array(PROG2_WORDS, 2);

    // 8 steps para ver moverse el pipeline
    for (i = 0; i < 8; i = i + 1) begin
      $display("[TB ] ---- STEP #%0d ----", i);
      send_cmd_step();
      wait_dbg_idle();
      wait_some_cycles(5);
    end

    // Tras suficientes steps, deberían haberse retirado las instrucciones
    check_reg(5'd1, 32'd5);
    check_reg(5'd2, 32'd7);
    check_reg(5'd3, 32'd12);

    // ----------------------------------------------------------
    // TEST 3: LOAD + RUN + STOP + RUN
    // ----------------------------------------------------------
    $display("\n================ TEST 3: LOAD + RUN + STOP + RUN ================\n");
    load_program_from_array(PROG3_WORDS, 3);
    check_imem_array(PROG3_WORDS, 3);

    send_cmd_run();

    // darle algo de tiempo a que arranque
    wait_some_cycles(200);

    send_cmd_stop();
    wait_dbg_idle();
    wait_some_cycles(20);

    $display("[TB ] Estado tras STOP:");
    $display("[TB ] x1=%h x2=%h x3=%h x4=%h x5=%h x6=%h x7=%h",
             dut.id_s.regfile_i.regs[1],
             dut.id_s.regfile_i.regs[2],
             dut.id_s.regfile_i.regs[3],
             dut.id_s.regfile_i.regs[4],
             dut.id_s.regfile_i.regs[5],
             dut.id_s.regfile_i.regs[6],
             dut.id_s.regfile_i.regs[7]);

    // continuar
    send_cmd_run();
    wait_dbg_idle();
    wait_some_cycles(20);

    check_reg(5'd1, 32'd1);
    check_reg(5'd2, 32'd2);
    check_reg(5'd3, 32'd3);
    check_reg(5'd4, 32'd4);
    check_reg(5'd5, 32'd5);
    check_reg(5'd6, 32'd6);
    check_reg(5'd7, 32'd7);

    $display("\n================ TODOS LOS TESTS TERMINARON ================\n");
    $finish;
  end


endmodule
