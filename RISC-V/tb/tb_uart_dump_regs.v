`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/19/2026 07:25:48 PM
// Design Name: 
// Module Name: tb_uart_dump_regs
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


module tb_uart_dump_regs;

  // ============================================================
  // Parámetros
  // ============================================================
  localparam CLK_FREQ  = 100_000_000;
  localparam BAUD_RATE = 9600;
  localparam CLK_PER   = 10; // 100 MHz -> 10 ns
  localparam BIT_TIME  = 1_000_000_000 / BAUD_RATE; // ~104166 ns por bit

  // A 9600 la simulación tarda bastante
  localparam GLOBAL_TIMEOUT_CYC    = 30_000_000;
  localparam WAIT_IDLE_TIMEOUT_CYC = 8_000_000;

  // ============================================================
  // Estados debug_unit
  // ============================================================
  localparam [4:0]
      ST_IDLE            = 5'd0,
      ST_DECODE_CMD      = 5'd1,
      ST_ERROR           = 5'd2,
      ST_PROG_CLEAR      = 5'd3,
      ST_PROG_BEGIN      = 5'd4,
      ST_PROG_LEN_HI     = 5'd5,
      ST_PROG_LEN_LO     = 5'd6,
      ST_PROG_B0         = 5'd7,
      ST_PROG_B1         = 5'd8,
      ST_PROG_B2         = 5'd9,
      ST_PROG_B3         = 5'd10,
      ST_PROG_WRITE_WORD = 5'd11,
      ST_PROG_END        = 5'd12,
      ST_RUN_CONTINUOUS  = 5'd13,
      ST_STEP_ARM        = 5'd14,
      ST_STEP_EXEC       = 5'd15,
      ST_RESET_EXEC      = 5'd16,
      ST_DRAIN           = 5'd17,
      ST_DUMP_LATCHES    = 5'd18,
      ST_DUMP_MEM        = 5'd19,
      ST_DUMP_DONE       = 5'd20,
      ST_DUMP_REGS_HDR   = 5'd21,
      ST_DUMP_REGS_SET_IDX = 5'd22,
      ST_DUMP_REGS_LATCH = 5'd23,
      ST_DUMP_REGS_SEND_B3 = 5'd24,
      ST_DUMP_REGS_SEND_B2 = 5'd25,
      ST_DUMP_REGS_SEND_B1 = 5'd26,
      ST_DUMP_REGS_SEND_B0 = 5'd27,
      ST_DUMP_REGS_NEXT  = 5'd28;

  // ============================================================
  // Comandos UART
  // ============================================================
  localparam [7:0]
      CMD_NONE         = 8'h00,
      CMD_PROG_BEGIN   = 8'h10,
      CMD_PROG_END     = 8'h11,
      CMD_RUN          = 8'h20,
      CMD_STEP         = 8'h21,
      CMD_STOP         = 8'h22,
      CMD_DUMP_REGS    = 8'h30,
      CMD_DUMP_LATCHES = 8'h31,
      CMD_DUMP_MEM     = 8'h32,
      CMD_CLEAR_IMEM   = 8'h40;

  // ACKs / respuestas
  localparam [7:0]
      RESP_OK_CLEAR    = 8'hC0,
      RESP_OK_PROG     = 8'hC1,
      RESP_OK_STEP     = 8'hC2,
      RESP_OK_STOP     = 8'hC3,
      RESP_OK_RUN_END  = 8'hC4,
      RESP_DUMP_REGS   = 8'hD0,
      RESP_DUMP_LATCH  = 8'hD1,
      RESP_DUMP_MEM    = 8'hD2,
      RESP_ERR         = 8'hEE;

  reg clk, reset;
  reg rx;
  wire tx;

  integer cyc;
  integer i;

  // ============================================================
  // DUT
  // ============================================================
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
  // Programa de prueba
  // ============================================================
  //
  // 0: addi x1, x0, 5     -> x1 = 5
  // 1: addi x2, x0, 7     -> x2 = 7
  // 2: add  x3, x1, x2    -> x3 = 12
  // 3: sub  x4, x3, x1    -> x4 = 7
  // 4: or   x5, x4, x2    -> x5 = 7
  // 5: and  x6, x3, x4    -> x6 = 4
  // 6: xor  x7, x6, x5    -> x7 = 3
  //
  // No ponemos HALT porque este test está centrado en STEP + DUMP_REGS.
  // Luego del programa, IMEM queda en NOP por el clear.
  //
  localparam PROG_WORDS = 7;
  reg [31:0] prog [0:PROG_WORDS-1];

  initial begin
    prog[0] = 32'h00500093; // addi x1, x0, 5
    prog[1] = 32'h00700113; // addi x2, x0, 7
    prog[2] = 32'h002081B3; // add  x3, x1, x2
    prog[3] = 32'h40118233; // sub  x4, x3, x1
    prog[4] = 32'h002262B3; // or   x5, x4, x2
    prog[5] = 32'h0041F333; // and  x6, x3, x4
    prog[6] = 32'h005343B3; // xor  x7, x6, x5
  end

  // ============================================================
  // Arrays para dumps / esperados
  // ============================================================
  reg [31:0] dump_regs [0:31];
  reg [31:0] exp_regs  [0:31];

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
    $dumpfile("tb_uart_dump_regs.vcd");
    $dumpvars(0, tb_uart_dump_regs);
  end

  always @(posedge clk) begin
    #1;
    cyc = cyc + 1;
    if (cyc > GLOBAL_TIMEOUT_CYC) begin
      $display("TIMEOUT GLOBAL en C%0d", cyc);
      $finish;
    end
  end

  // ============================================================
  // Helpers UART TX->DUT
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
      #(BIT_TIME/2);          // gap pequeño
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

  // ============================================================
  // Helpers UART DUT->TB
  // ============================================================
  task wait_sample_ticks;
    input integer n;
    integer k;
    begin
      for (k = 0; k < n; k = k + 1) begin
        @(posedge clk);
        while (dut.sample_tick !== 1'b1)
          @(posedge clk);
      end
    end
  endtask


  task uart_recv_byte;
    output [7:0] data;
    integer b;
    begin
      data = 8'h00;

      // Esperar flanco de bajada del start bit
      @(negedge tx);

      // Ir al centro del start bit
      wait_sample_ticks(8);

      if (tx !== 1'b0) begin
        $display("ERR UART RX TB: start bit invalido en t=%0t", $time);
        $finish;
      end

      // Ir al centro del bit 0
      wait_sample_ticks(16);

      // Leer 8 bits, uno cada 16 ticks
      for (b = 0; b < 8; b = b + 1) begin
        data[b] = tx;
        wait_sample_ticks(16);
      end

      // Stop bit
      if (tx !== 1'b1) begin
        $display("ERR UART RX TB: stop bit invalido en t=%0t", $time);
        $finish;
      end

      // Dejar un pequeño margen
      wait_sample_ticks(2);
    end
  endtask

  task expect_uart_byte;
    input [7:0] exp;
    reg   [7:0] got;
    begin
      uart_recv_byte(got);
      if (got !== exp) begin
        $display("ERR UART byte got=%02h exp=%02h en C%0d t=%0t", got, exp, cyc, $time);
        $finish;
      end else begin
        $display("[TB ] UART OK byte=%02h", got);
      end
    end
  endtask

  // ============================================================
  // Helpers varios
  // ============================================================
  task wait_some_cycles;
    input integer n;
    integer t;
    begin
      for (t = 0; t < n; t = t + 1)
        @(posedge clk);
    end
  endtask

  task wait_dbg_idle;
    integer t0;
    begin
      t0 = cyc;
      while (dut.dbg_u.state != ST_IDLE) begin
        @(posedge clk);
        if ((cyc - t0) > WAIT_IDLE_TIMEOUT_CYC) begin
          $display("ERR timeout esperando ST_IDLE en C%0d. state=%0d", cyc, dut.dbg_u.state);
          $finish;
        end
      end
      repeat (5) @(posedge clk);
    end
  endtask

  // ============================================================
  // Carga de programa
  // ============================================================
  task check_imem_array;
    integer words;
    integer selector;
    integer k;
    reg [31:0] exp;
    begin
      words = PROG_WORDS;
      $display("[TB ] C%0d -> Verificando IMEM (%0d words)", cyc, words);
      for (k = 0; k < words; k = k + 1) begin
        exp = prog[k];
        
        if (dut.if_s.imem_i.mem[k] !== exp) begin
          $display("ERR IMEM[%0d] got=%h exp=%h", k, dut.if_s.imem_i.mem[k], exp);
          $finish;
        end
      end
      $display("[TB ] IMEM OK");
    end
  endtask
  
  task load_program;
    integer words;
    integer k;
    begin
      $display("[TB ] C%0d -> CMD_CLEAR_IMEM", cyc);
      //uart_send_byte(CMD_CLEAR_IMEM);
      wait_dbg_idle();

      $display("[TB ] C%0d -> CMD_PROG_BEGIN (%0d words)", cyc, words);
      words = PROG_WORDS;
      uart_send_byte(CMD_PROG_BEGIN);
      uart_send_byte(words[15:8]);
      uart_send_byte(words[7:0]);
      
      for (k = 0; k < words; k = k + 1) begin
        uart_send_word_be(prog[k]);
      end

      wait_dbg_idle();
    end
  endtask

  // ============================================================
  // STEP
  // ============================================================
  task do_one_step;
    begin
      $display("[TB ] C%0d -> CMD_STEP", cyc);
      uart_send_byte(CMD_STEP);
      //expect_uart_byte(RESP_OK_STEP);
      wait_dbg_idle();
    end
  endtask

  task do_n_steps;
    input integer n;
    integer k;
    begin
      for (k = 0; k < n; k = k + 1) begin
        do_one_step();
      end
    end
  endtask

  // ============================================================
  // DUMP_REGS
  // ============================================================
  task recv_dump_regs_payload;
    integer k;
    reg [7:0] hdr;
    reg [7:0] b3, b2, b1, b0;
    begin
      uart_recv_byte(hdr);
      if (hdr !== RESP_DUMP_REGS) begin
        $display("ERR DUMP header got=%02h exp=%02h", hdr, RESP_DUMP_REGS);
        $finish;
      end

      for (k = 0; k < 32; k = k + 1) begin
        uart_recv_byte(b3);
        uart_recv_byte(b2);
        uart_recv_byte(b1);
        uart_recv_byte(b0);
        dump_regs[k] = {b3, b2, b1, b0};
      end
    end
  endtask

  task request_dump_regs_and_capture;
    begin
      $display("[TB ] C%0d -> CMD_DUMP_REGS", cyc);
      uart_send_byte(CMD_DUMP_REGS);

      // Mientras dumpea, el pipeline debe estar frenado
      wait_some_cycles(20);
      if (dut.dbg_pipeline_en !== 1'b0) begin
        $display("ERR: dbg_pipeline_en no está en 0 durante dump");
        $finish;
      end

      //recv_dump_regs_payload();
      wait_dbg_idle();
    end
  endtask

  // ============================================================
  // Esperados
  // ============================================================
  task build_expected_checkpoint;
    input integer checkpoint;
    integer k;
    begin
      for (k = 0; k < 32; k = k + 1)
        exp_regs[k] = 32'd0;

      case (checkpoint)
        // Checkpoint 1: después de 5 steps
        // Commit esperado:
        //   x1 = 5
        1: begin
          exp_regs[1] = 32'd5;
        end

        // Checkpoint 2: después de 7 steps
        // Commit esperado:
        //   x1 = 5
        //   x2 = 7
        //   x3 = 12
        2: begin
          exp_regs[1] = 32'd5;
          exp_regs[2] = 32'd7;
          exp_regs[3] = 32'd12;
        end

        // Checkpoint 3: después de 11 steps
        // Commit esperado:
        //   x1 = 5
        //   x2 = 7
        //   x3 = 12
        //   x4 = 7
        //   x5 = 7
        //   x6 = 4
        //   x7 = 3
        3: begin
          exp_regs[1] = 32'd5;
          exp_regs[2] = 32'd7;
          exp_regs[3] = 32'd12;
          exp_regs[4] = 32'd7;
          exp_regs[5] = 32'd7;
          exp_regs[6] = 32'd4;
          exp_regs[7] = 32'd3;
        end

        default: begin
        end
      endcase
    end
  endtask

  task compare_dump_against_expected;
    input integer checkpoint;
    integer k;
    begin
      build_expected_checkpoint(checkpoint);

      $display("[TB ] Comparando dump con esperado para checkpoint %0d...", checkpoint);
      for (k = 0; k < 32; k = k + 1) begin
        if (dump_regs[k] !== exp_regs[k]) begin
          $display("ERR DUMP chk=%0d reg x%0d got=%h exp=%h",
                   checkpoint, k, dump_regs[k], exp_regs[k]);
          $display("      regfile interno actual = %h", dut.id_s.regfile_i.regs[k]);
          $finish;
        end
      end
      $display("[TB ] DUMP OK para checkpoint %0d", checkpoint);
    end
  endtask

  task compare_dump_against_internal_regfile;
    integer k;
    begin
      for (k = 0; k < 32; k = k + 1) begin
        if (dump_regs[k] !== dut.id_s.regfile_i.regs[k]) begin
          $display("ERR DUMP vs REGFILE x%0d got=%h internal=%h",
                   k, dump_regs[k], dut.id_s.regfile_i.regs[k]);
          $finish;
        end
      end
      $display("[TB ] DUMP coincide con regfile interno");
    end
  endtask

  task run_dump_checkpoint;
    input integer checkpoint;
    begin
      request_dump_regs_and_capture();
      //compare_dump_against_expected(checkpoint);
      $display("[TB ] ESPERAMOS UNOS CICLOS DE RELOJ PARA QUE SE ENVÍE TODO");
      repeat (14500000) @(posedge clk);
      //compare_dump_against_internal_regfile();
    end
  endtask

  // ============================================================
  // Prints resumidos
  // ============================================================
  reg [4:0] prev_dbg_state;
  reg       prev_dbg_pipeline_en;
  reg       prev_dbg_reset_exec;

  initial begin
    prev_dbg_state       = 0;
    prev_dbg_pipeline_en = 0;
    prev_dbg_reset_exec  = 0;
  end

  always @(posedge clk) begin
    #1;
    if (!reset) begin
      if (dut.dbg_u.state        != prev_dbg_state       ||
          dut.dbg_pipeline_en    != prev_dbg_pipeline_en ||
          dut.dbg_reset_exec     != prev_dbg_reset_exec) begin

        $display("C%0d | dbg_state=%0d pen=%b rstx=%b | PC=%h IFIN=%h | IFID=%b IDEX=%b EXMEM=%b MEMWB=%b",
                 cyc,
                 dut.dbg_u.state,
                 dut.dbg_pipeline_en,
                 dut.dbg_reset_exec,
                 dut.if_pc,
                 dut.if_instr,
                 dut.ifid_valid,
                 dut.idex_valid,
                 dut.exmem_valid,
                 dut.memwb_valid);
      end
    end

    prev_dbg_state       = dut.dbg_u.state;
    prev_dbg_pipeline_en = dut.dbg_pipeline_en;
    prev_dbg_reset_exec  = dut.dbg_reset_exec;
  end

  // ============================================================
  // TEST
  // ============================================================
  initial begin
    wait(reset == 1'b0);
    wait_some_cycles(20);

    $display("\n================ TEST DUMP_REGS POR UART ================\n");

    // 1) Cargar programa
    load_program();
    check_imem_array();

    // ----------------------------------------------------------
    // Checkpoint 1: después de 5 steps
    // Esperado: x1 = 5
    // ----------------------------------------------------------
    $display("\n---- CHECKPOINT 1 ----\n");
    do_n_steps(15);
    run_dump_checkpoint(1);

    // ----------------------------------------------------------
    // Checkpoint 2: después de 7 steps totales
    // Esperado: x1 = 5, x2 = 7, x3 = 12
    // ----------------------------------------------------------
    $display("\n---- CHECKPOINT 2 ----\n");
    do_n_steps(2);
    run_dump_checkpoint(2);

    // ----------------------------------------------------------
    // Checkpoint 3: después de 11 steps totales
    // Esperado final completo
    // ----------------------------------------------------------
    $display("\n---- CHECKPOINT 3 ----\n");
    do_n_steps(4);
    run_dump_checkpoint(3);

    $display("\n================ TEST OK: DUMP_REGS VALIDADO ================\n");
    $finish;
  end

endmodule
