`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/19/2026 03:22:53 AM
// Design Name: 
// Module Name: tb_uart_3
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


module tb_uart_3;

  // ============================================================
  // Parámetros
  // ============================================================
  localparam CLK_FREQ  = 100_000_000;
  localparam BAUD_RATE = 9600;
  localparam CLK_PER   = 10; // 100 MHz -> 10 ns
  localparam BIT_TIME  = 1_000_000_000 / BAUD_RATE; // ~104166 ns por bit

  // Ojo: a 9600 todo tarda MUCHO más en simulación
  localparam GLOBAL_TIMEOUT_CYC    = 30_000_000;
  localparam WAIT_IDLE_TIMEOUT_CYC = 8_000_000;
  localparam WAIT_HALT_TIMEOUT_CYC = 4_000_000;
  localparam WAIT_STOP_TIMEOUT_CYC = 4_000_000;

  // UART commands
  localparam [7:0] CMD_PROG_BEGIN = 8'h10;
  localparam [7:0] CMD_RUN        = 8'h20;
  localparam [7:0] CMD_STEP       = 8'h21;
  localparam [7:0] CMD_STOP       = 8'h22;
  localparam [7:0] CMD_CLEAR_IMEM = 8'h40;
  localparam [7:0] RESP_OK_STEP   = 8'hC2;
  localparam [7:0] RESP_OK_RUN_END = 8'hC4;

  reg clk, reset;
  reg rx;
  reg seen_drain;
  reg [31:0] x1_after_stop1;
  reg [31:0] x1_after_stop2;

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
  // Programas de prueba
  // ============================================================
  localparam PROG1_WORDS = 4; // run + halt
  reg [31:0] prog_run_halt [0:PROG1_WORDS-1];

  localparam PROG2_WORDS = 4; // steps
  reg [31:0] prog_steps [0:PROG2_WORDS-1];

  localparam PROG3_WORDS = 15; // run + stop + continue
  reg [31:0] prog_stop_resume [0:PROG3_WORDS-1];

  localparam PROG4_WORDS = 4; // store + halt
  reg [31:0] prog_store_halt [0:PROG4_WORDS-1];

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

    // Programa 3: loop con contador para ver el stop y run
    //prog_stop_resume[0] = 32'h00000093; // addi x1, x0, 0
    //prog_stop_resume[1] = 32'h00108093; // addi x1, x1, 1
    //prog_stop_resume[2] = 32'hFFDFF06F; // jal x0, -4   (vuelve a prog3_mem[1])
    // Programa: muchas escrituras en memoria y luego loop infinito
    /*prog_stop_resume[0]  = 32'h00000093; // addi x1, x0, 0        ; base addr = 0
    
    // x2 = 0x11
    prog_stop_resume[1]  = 32'h01100113; // addi x2, x0, 17
    
    prog_stop_resume[2]  = 32'h00208023; // sb x2, 0(x1)
    prog_stop_resume[3]  = 32'h002080A3; // sb x2, 1(x1)
    prog_stop_resume[4]  = 32'h00208123; // sb x2, 2(x1)
    prog_stop_resume[5]  = 32'h002081A3; // sb x2, 3(x1)
    prog_stop_resume[6]  = 32'h00209223; // sh x2, 4(x1)
    prog_stop_resume[7]  = 32'h00209323; // sh x2, 6(x1)
    prog_stop_resume[8]  = 32'h0020A423; // sw x2, 8(x1)
    prog_stop_resume[9]  = 32'h0020A623; // sw x2, 12(x1)
    
    // x2 = 0x22
    prog_stop_resume[10] = 32'h02200113; // addi x2, x0, 34
    
    prog_stop_resume[11] = 32'h00208823; // sb x2, 16(x1)
    prog_stop_resume[12] = 32'h002088A3; // sb x2, 17(x1)
    prog_stop_resume[13] = 32'h00208923; // sb x2, 18(x1)
    prog_stop_resume[14] = 32'h002089A3; // sb x2, 19(x1)
    prog_stop_resume[15] = 32'h00209A23; // sh x2, 20(x1)
    prog_stop_resume[16] = 32'h00209B23; // sh x2, 22(x1)
    prog_stop_resume[17] = 32'h0020AC23; // sw x2, 24(x1)
    prog_stop_resume[18] = 32'h0020AE23; // sw x2, 28(x1)
    
    // x2 = 0x33
    prog_stop_resume[19] = 32'h03300113; // addi x2, x0, 51
    
    prog_stop_resume[20] = 32'h02208023; // sb x2, 32(x1)
    prog_stop_resume[21] = 32'h022080A3; // sb x2, 33(x1)
    prog_stop_resume[22] = 32'h02208123; // sb x2, 34(x1)
    prog_stop_resume[23] = 32'h022081A3; // sb x2, 35(x1)
    prog_stop_resume[24] = 32'h02209223; // sh x2, 36(x1)
    prog_stop_resume[25] = 32'h02209323; // sh x2, 38(x1)
    prog_stop_resume[26] = 32'h0220A423; // sw x2, 40(x1)
    prog_stop_resume[27] = 32'h0220A623; // sw x2, 44(x1)
    
    // x2 = 0x44
    prog_stop_resume[28] = 32'h04400113; // addi x2, x0, 68
    
    prog_stop_resume[29] = 32'h02208823; // sb x2, 48(x1)
    prog_stop_resume[30] = 32'h022088A3; // sb x2, 49(x1)
    prog_stop_resume[31] = 32'h02208923; // sb x2, 50(x1)
    prog_stop_resume[32] = 32'h022089A3; // sb x2, 51(x1)
    prog_stop_resume[33] = 32'h02209A23; // sh x2, 52(x1)
    prog_stop_resume[34] = 32'h02209B23; // sh x2, 54(x1)
    prog_stop_resume[35] = 32'h0220AC23; // sw x2, 56(x1)
    prog_stop_resume[36] = 32'h0220AE23; // sw x2, 60(x1)
    
    // loop infinito
    prog_stop_resume[37] = 32'h0000006F; // jal x0, 0*/
    
    
    // Programa corto de test de memoria: SB, SH, SW y LW
    prog_stop_resume[0]  = 32'h00000093; // addi x1, x0, 0        ; base addr = 0
    prog_stop_resume[1]  = 32'h01100113; // addi x2, x0, 17       ; x2 = 0x11
    
    // 4 stores byte -> debería formar 0x11111111 en addr 0
    prog_stop_resume[2]  = 32'h00208023; // sb x2, 0(x1)
    prog_stop_resume[3]  = 32'h002080A3; // sb x2, 1(x1)
    prog_stop_resume[4]  = 32'h00208123; // sb x2, 2(x1)
    prog_stop_resume[5]  = 32'h002081A3; // sb x2, 3(x1)
    
    // 2 stores halfword -> debería formar 0x00110011 en addr 4
    prog_stop_resume[6]  = 32'h00209223; // sh x2, 4(x1)
    prog_stop_resume[7]  = 32'h00209323; // sh x2, 6(x1)
    
    // 2 stores word
    prog_stop_resume[8]  = 32'h0020A423; // sw x2, 8(x1)
    prog_stop_resume[9]  = 32'h0020A623; // sw x2, 12(x1)
    
    // Lecturas
    prog_stop_resume[10] = 32'h0000A183; // lw x3, 0(x1)
    prog_stop_resume[11] = 32'h0040A203; // lw x4, 4(x1)
    prog_stop_resume[12] = 32'h0080A283; // lw x5, 8(x1)
    prog_stop_resume[13] = 32'h00C0A303; // lw x6, 12(x1)
    
    // loop infinito
    prog_stop_resume[14] = 32'h0000006F; // jal x0, 0

    // Programa 4: store con HALT inmediatamente después
    prog_store_halt[0] = 32'h00000093; // addi x1, x0, 0
    prog_store_halt[1] = 32'h02A00113; // addi x2, x0, 42
    prog_store_halt[2] = 32'h0020A023; // sw x2, 0(x1)
    prog_store_halt[3] = 32'hffffffff; // HALT
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
    $dumpfile("tb_uart_3.vcd");
    $dumpvars(0, tb_uart_3);
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
      #(BIT_TIME/2);          // pequeño gap
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

  task wait_some_cycles;
    input integer n;
    integer t;
    begin
      for (t = 0; t < n; t = t + 1)
        @(posedge clk);
    end
  endtask

  task reset_halt_tracking;
    begin
      seen_drain               = 1'b0;
      run_end_resp_count       = 0;
      step_resp_count          = 0;
      first_drain_cycle        = -1;
      first_pipeline_empty_cycle = -1;
      last_run_end_cycle       = -1;
      last_step_resp_cycle     = -1;
      last_wb_cycle            = -1;
      last_mem_write_cycle     = -1;
    end
  endtask

  task wait_dbg_idle;
    integer t0;
    begin
      t0 = cyc;
      while (dut.dbg_u.state != dut.dbg_u.ST_IDLE) begin
        @(posedge clk);
        if ((cyc - t0) > WAIT_IDLE_TIMEOUT_CYC) begin
          $display("ERR timeout esperando ST_IDLE en C%0d. state=%0d", cyc, dut.dbg_u.state);
          $finish;
        end
      end
      repeat (5) @(posedge clk);
    end
  endtask

    task wait_dbg_drain;
      integer t0;
      begin
        t0 = cyc;
        while (dut.dbg_u.state != dut.dbg_u.ST_DRAIN) begin
          @(posedge clk);
          if ((cyc - t0) > WAIT_HALT_TIMEOUT_CYC) begin
            $display("ERR timeout esperando ST_DRAIN en C%0d. state=%0d", cyc, dut.dbg_u.state);
            $finish;
          end
        end
        $display("[TB ] ST_DRAIN detectado en C%0d", cyc);
      end
    endtask
    
    task wait_wb_commits(input integer delta);
      integer target;
      integer timeout;
      begin
        target = wb_commit_count + delta;
        timeout = 0;
    
        while (wb_commit_count < target) begin
          wait_some_cycles(1);
          timeout = timeout + 1;
    
          if (timeout > 10000) begin
            $display("ERR timeout esperando commits. wb_commit_count=%0d target=%0d",
                     wb_commit_count, target);
            $finish;
          end
        end
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
      //uart_send_byte(CMD_CLEAR_IMEM);
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
          4: uart_send_word_be(prog_store_halt[k]);
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
          4: exp = prog_store_halt[k];
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
  // Helpers de chequeo
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

  task wait_pipeline_drained;
    input integer timeout_cyc;
    integer t0;
    begin
      t0 = cyc;
      while (dut.ifid_valid || dut.idex_valid || dut.exmem_valid || dut.memwb_valid) begin
        @(posedge clk);
        if ((cyc - t0) > timeout_cyc) begin
          $display("ERR timeout esperando pipeline drained en C%0d", cyc);
          $display("      IFID=%b IDEX=%b EXMEM=%b MEMWB=%b",
                   dut.ifid_valid, dut.idex_valid, dut.exmem_valid, dut.memwb_valid);
          $finish;
        end
      end
      $display("[TB ] Pipeline drenado en C%0d", cyc);
    end
  endtask

  // ============================================================
  // Contador de writeback
  // ============================================================

  integer wb_commit_count;
  integer run_end_resp_count;
  integer step_resp_count;
  integer first_drain_cycle;
  integer first_pipeline_empty_cycle;
  integer last_run_end_cycle;
  integer last_step_resp_cycle;
  integer last_wb_cycle;
  integer last_mem_write_cycle;
  integer step_cmd_count;

  initial begin
    wb_commit_count = 0;
    reset_halt_tracking();
  end

  always @(posedge clk) begin
    #1;
    if (!reset && dut.wb_we) begin
      wb_commit_count = wb_commit_count + 1;
      last_wb_cycle = cyc;
      $display("[WB ] C%0d -> x%0d <= %h", cyc, dut.wb_rd_idx, dut.wb_write_data);
    end
  end

  always @(posedge clk) begin
    #1;
    if (reset) begin
      seen_drain = 1'b0;
    end else begin
      if (dut.dbg_u.state == dut.dbg_u.ST_DRAIN) begin
        seen_drain = 1'b1;
        if (first_drain_cycle < 0)
          first_drain_cycle = cyc;
      end

      if (seen_drain && dut.pipeline_empty && (first_pipeline_empty_cycle < 0))
        first_pipeline_empty_cycle = cyc;

      if (dut.dbg_tx_wr_en && (dut.dbg_tx_data == RESP_OK_RUN_END)) begin
        run_end_resp_count = run_end_resp_count + 1;
        last_run_end_cycle = cyc;
      end

      if (dut.dbg_tx_wr_en && (dut.dbg_tx_data == RESP_OK_STEP)) begin
        step_resp_count = step_resp_count + 1;
        last_step_resp_cycle = cyc;
      end

      if (dut.mem_write_enable)
        last_mem_write_cycle = cyc;
    end
  end

  // ============================================================
  // Prints resumidos
  // ============================================================

  reg [4:0] prev_dbg_state;
  reg       prev_dbg_pipeline_en;
  reg       prev_dbg_reset_exec;
  reg       prev_id_halt;

  initial begin
    prev_dbg_state       = 0;
    prev_dbg_pipeline_en = 0;
    prev_dbg_reset_exec  = 0;
    prev_id_halt         = 0;
  end

  always @(posedge clk) begin
    #1;
    if (!reset) begin
      if (dut.dbg_u.state        != prev_dbg_state       ||
          dut.dbg_pipeline_en    != prev_dbg_pipeline_en ||
          dut.dbg_reset_exec     != prev_dbg_reset_exec  ||
          dut.id_halt            != prev_id_halt         ||
          dut.dbg_prog_we ||
          dut.wb_we) begin

        $display("C%0d | dbg_state=%0d pen=%b rstx=%b id_halt=%b | PC=%h IFIN=%h | IFID=%b IDEX=%b EXMEM=%b MEMWB=%b",
                 cyc,
                 dut.dbg_u.state,
                 dut.dbg_pipeline_en,
                 dut.dbg_reset_exec,
                 dut.id_halt,
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
    prev_id_halt         = dut.id_halt;
  end

  // ============================================================
  // TESTS
  // ============================================================

  initial begin
    seen_drain = 1'b0;
    wait(reset == 1'b0);
    wait_some_cycles(20);

    // ----------------------------------------------------------
    // TEST 1: LOAD + RUN + HALT
    // ----------------------------------------------------------
    $display("\n================ TEST 1: LOAD + RUN + HALT ================\n");

    reset_halt_tracking();
    wb_commit_count = 0;
    load_program_from_array(PROG1_WORDS, 1);
    check_imem_array(PROG1_WORDS, 1);

    send_cmd_run();

    wait_dbg_idle();
    wait_pipeline_drained(WAIT_HALT_TIMEOUT_CYC);
    if (!seen_drain) begin
      $display("ERR TEST1: nunca se vio ST_DRAIN");
      $finish;
    end
    if (run_end_resp_count != 1) begin
      $display("ERR TEST1: RESP_OK_RUN_END inesperado. count=%0d", run_end_resp_count);
      $finish;
    end
    if (step_resp_count != 0) begin
      $display("ERR TEST1: apareció RESP_OK_STEP durante RUN. count=%0d", step_resp_count);
      $finish;
    end
    if (first_pipeline_empty_cycle < 0 || last_run_end_cycle < first_pipeline_empty_cycle) begin
      $display("ERR TEST1: RUN_END llegó antes de pipeline_empty. empty=%0d run_end=%0d",
               first_pipeline_empty_cycle, last_run_end_cycle);
      $finish;
    end
    if (last_wb_cycle < 0 || last_wb_cycle >= last_run_end_cycle) begin
      $display("ERR TEST1: último WB no quedó antes del fin. wb=%0d run_end=%0d",
               last_wb_cycle, last_run_end_cycle);
      $finish;
    end
    wait_some_cycles(20);

    check_reg(5'd1, 32'd5);
    check_reg(5'd2, 32'd7);
    check_reg(5'd3, 32'd12);

    if (wb_commit_count < 3) begin
      $display("ERR TEST1: commits insuficientes. wb_commit_count=%0d", wb_commit_count);
      $finish;
    end

    // ----------------------------------------------------------
    // TEST 2: LOAD + varios STEP
    // ----------------------------------------------------------
    $display("\n================ TEST 2: LOAD + STEP x ciclos ================\n");
    
    reset_halt_tracking();
    wb_commit_count = 0;
    load_program_from_array(PROG2_WORDS, 2);
    check_imem_array(PROG2_WORDS, 2);

    step_cmd_count = 0;
    while ((run_end_resp_count == 0) && (step_cmd_count < 8)) begin
      $display("[TB ] ---- STEP #%0d ----", step_cmd_count);
      send_cmd_step();
      wait_dbg_idle();
      wait_some_cycles(3);
      step_cmd_count = step_cmd_count + 1;
    end

    wait_pipeline_drained(WAIT_HALT_TIMEOUT_CYC);

    if (run_end_resp_count != 1) begin
      $display("ERR TEST2: no apareció un único RESP_OK_RUN_END. count=%0d", run_end_resp_count);
      $finish;
    end
    if (!seen_drain) begin
      $display("ERR TEST2: nunca se vio ST_DRAIN al alcanzar HALT con STEP");
      $finish;
    end
    if (step_resp_count != (step_cmd_count - 1)) begin
      $display("ERR TEST2: RESP_OK_STEP inesperados. steps=%0d step_resp=%0d",
               step_cmd_count, step_resp_count);
      $finish;
    end
    if (last_step_resp_cycle >= last_run_end_cycle) begin
      $display("ERR TEST2: RESP_OK_STEP apareció después de RUN_END. step=%0d run_end=%0d",
               last_step_resp_cycle, last_run_end_cycle);
      $finish;
    end
    if (first_pipeline_empty_cycle < 0 || last_run_end_cycle < first_pipeline_empty_cycle) begin
      $display("ERR TEST2: RUN_END llegó antes de pipeline_empty. empty=%0d run_end=%0d",
               first_pipeline_empty_cycle, last_run_end_cycle);
      $finish;
    end

    check_reg(5'd1, 32'd5);
    check_reg(5'd2, 32'd7);
    check_reg(5'd3, 32'd12);

    // ----------------------------------------------------------
    // TEST 3: LOAD + RUN + STOP + RUN
    // ----------------------------------------------------------
    $display("\n================ TEST 3: INFINITE LOOP + STOP + RESUME ================\n");
    
    reset_halt_tracking();
    wb_commit_count = 0;
    
    load_program_from_array(PROG3_WORDS, 3);
    check_imem_array(PROG3_WORDS, 3);
    
    // RUN 1
    send_cmd_run();
    wait_wb_commits(20);
    send_cmd_stop();
    wait_dbg_idle();
    wait_some_cycles(10);
    
    x1_after_stop1 = dut.id_s.regfile_i.regs[1];
    
    $display("[TB ] Tras STOP1: x1=%0d (%h)", x1_after_stop1, x1_after_stop1);
    
    if (seen_drain) begin
      $display("ERR TEST3: apareció ST_DRAIN en un programa infinito");
      $finish;
    end
    
    if (x1_after_stop1 == 0) begin
      $display("ERR TEST3: x1 no avanzó antes del STOP");
      $finish;
    end
    
    // RUN 2
    send_cmd_run();
    wait_wb_commits(20);
    send_cmd_stop();
    wait_dbg_idle();
    wait_some_cycles(10);
    
    x1_after_stop2 = dut.id_s.regfile_i.regs[1];
    
    $display("[TB ] Tras STOP2: x1=%0d (%h)", x1_after_stop2, x1_after_stop2);
    
    if (x1_after_stop2 <= x1_after_stop1) begin
      $display("ERR TEST3: x1 no siguió avanzando después del segundo RUN");
      $finish;
    end
    
    $display("[TB ] OK TEST3: x1 siguió contando tras reanudar");

    // ----------------------------------------------------------
    // TEST 4: STORE + HALT
    // ----------------------------------------------------------
    $display("\n================ TEST 4: STORE + HALT ================\n");

    reset_halt_tracking();
    wb_commit_count = 0;
    load_program_from_array(PROG4_WORDS, 4);
    check_imem_array(PROG4_WORDS, 4);

    send_cmd_run();
    wait_dbg_idle();
    wait_pipeline_drained(WAIT_HALT_TIMEOUT_CYC);

    if (!seen_drain) begin
      $display("ERR TEST4: nunca se vio ST_DRAIN");
      $finish;
    end
    if (run_end_resp_count != 1) begin
      $display("ERR TEST4: RESP_OK_RUN_END inesperado. count=%0d", run_end_resp_count);
      $finish;
    end
    if (dut.u_dmem.mem[0] !== 32'h0000002A) begin
      $display("ERR TEST4: memoria[0] incorrecta. got=%h exp=%h",
               dut.u_dmem.mem[0], 32'h0000002A);
      $finish;
    end
    if (last_mem_write_cycle < 0 || last_mem_write_cycle >= last_run_end_cycle) begin
      $display("ERR TEST4: el store no ocurrió antes del RUN_END. store=%0d run_end=%0d",
               last_mem_write_cycle, last_run_end_cycle);
      $finish;
    end
    if (first_pipeline_empty_cycle < 0 || last_run_end_cycle < first_pipeline_empty_cycle) begin
      $display("ERR TEST4: RUN_END llegó antes de pipeline_empty. empty=%0d run_end=%0d",
               first_pipeline_empty_cycle, last_run_end_cycle);
      $finish;
    end
    $display("[TB ] OK TEST4: store completado antes del fin del programa");
     
    $display("\n================ TODOS LOS TESTS TERMINARON ================\n");
    $finish;
  end

endmodule
