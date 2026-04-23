`timescale 1ns/1ps
module tb_pipeline_full;

  localparam NB_OP         = 6;
  localparam DMEM_BYTES    = 4096;
  localparam TOTAL_WRITES  = 40;
  localparam TOTAL_STORES = 6;   // 2 de C1 + 4 de C2

  // ALU ops (como tu alu32)
  localparam ADD = 6'b100000;
  localparam SUB = 6'b100010;
  localparam AND = 6'b100100;
  localparam OR  = 6'b100101;
  localparam XOR = 6'b100110;
  localparam SRA = 6'b000011;
  localparam SRL = 6'b000010;
  localparam SLL  = 6'b000001;
  localparam SLT  = 6'b101010;
  localparam SLTU = 6'b101011;
  localparam LUI  = 6'b001111;

  reg clk, reset;

  top #(
    .NB_OP(NB_OP),
    .DMEM_BYTES(DMEM_BYTES)
  ) dut (
    .clk(clk),
    .reset(reset)
  );

  // Clock 100MHz
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Reset
  initial begin
    reset = 1'b1;
    repeat(5) @(posedge clk);
    reset = 1'b0;
  end

  // Waves
  initial begin
    $dumpfile("tb_pipeline_full.vcd");
    $dumpvars(0, tb_pipeline_full);
  end

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  function has_x32;
    input [31:0] v;
    begin
      has_x32 = (^v === 1'bx);
    end
  endfunction

  function signed [31:0] alu_ref;
    input signed [31:0] a;
    input signed [31:0] b;
    input [NB_OP-1:0] op;
    reg [4:0] shamt;
    begin
      shamt = b[4:0];
      case (op)
        ADD: alu_ref = a + b;
        SUB: alu_ref = a - b;
        AND: alu_ref = a & b;
        OR : alu_ref = a | b;
        XOR: alu_ref = a ^ b;
        SRA: alu_ref = a >>> shamt;
        SRL: alu_ref = $unsigned(a) >> shamt;
        SLL : alu_ref = a << b[4:0];
        SLT : alu_ref = ($signed(a) < $signed(b)) ? 32'sd1 : 32'sd0;
        SLTU: alu_ref = ($unsigned(a) < $unsigned(b)) ? 32'sd1 : 32'sd0;
        LUI : alu_ref = b;
        default: alu_ref = 32'sd0;
      endcase
    end
  endfunction

  function [8*8-1:0] alu_op_name;
    input [NB_OP-1:0] op;
    begin
      case (op)
        ADD: alu_op_name = "ADD/ADDI";
        SUB: alu_op_name = "SUB";
        AND: alu_op_name = "AND/ANDI";
        OR : alu_op_name = "OR/ORI";
        XOR: alu_op_name = "XOR/XORI";
        SRA: alu_op_name = "SRA";
        SRL: alu_op_name = "SRL";
        SLL : alu_op_name = "SLL";
        SLT : alu_op_name = "SLT/SLTI";
        SLTU: alu_op_name = "SLTU/SLTIU";
        LUI : alu_op_name = "LUI";
        default: alu_op_name = "UNKNOWN";
      endcase
    end
  endfunction

function [8*24-1:0] exp_desc;
  input integer idx;
  begin
    case (idx)
      0  : exp_desc = "addi x1, x0, 5";
      1  : exp_desc = "addi x2, x0, 10";
      2  : exp_desc = "add x3, x1, x2";
      3  : exp_desc = "sub x4, x3, x1";
      4  : exp_desc = "andi x5, x3, 7";
      5  : exp_desc = "and x6, x1, x2";
      6  : exp_desc = "ori x7, x1, 8";
      7  : exp_desc = "or x8, x1, x2";
      8  : exp_desc = "xori x9, x1, 3";
      9  : exp_desc = "xor x10, x1, x2";
      10 : exp_desc = "srl x11, x2, x1";
      11 : exp_desc = "addi x12, x0, -8";
      12 : exp_desc = "addi x13, x0, 2";
      13 : exp_desc = "sra x14, x12, x13";
      14 : exp_desc = "srl x15, x12, x13";

      15 : exp_desc = "addi x16, x0, 1";
      16 : exp_desc = "addi x17, x0, 4";
      17 : exp_desc = "sll x18, x16, x17";
      18 : exp_desc = "slt x19, x16, x17";
      19 : exp_desc = "sltu x20, x16, x17";
      20 : exp_desc = "slti x21, x17, 3";
      21 : exp_desc = "slti x22, x16, 3";
      22 : exp_desc = "addi x23, x0, -1";
      23 : exp_desc = "slti x24, x23, 0";
      24 : exp_desc = "sltiu x25, x23, 1";
      25 : exp_desc = "lui x26, 0x12345";
      26 : exp_desc = "sltu x27, x23, x16";
      27 : exp_desc = "addi x28, x0, 64";
      28 : exp_desc = "addi x29, x0, 42";
      29 : exp_desc = "lw x30, 0(x28)";
      30 : exp_desc = "addi x29, x0, -7";
      31 : exp_desc = "lw x31, 4(x28)";
      32 : exp_desc = "lb x5, 8(x28)";
      33 : exp_desc = "lb x6, 9(x28)";
      34 : exp_desc = "lh x7, 12(x28)";
      35 : exp_desc = "lh x8, 14(x28)";
      36 : exp_desc = "lbu x9, 8(x28)";
      37 : exp_desc = "lbu x10, 9(x28)";
      38 : exp_desc = "lhu x11, 12(x28)";
      39 : exp_desc = "lhu x12, 14(x28)";
      default: exp_desc = "unknown";
    endcase
  end
endfunction

  integer cyc;

  // temporales para EX check
  reg signed [31:0] a_s, b_s, exp_s;

  // ---------- prev EX (para chequear EX/MEM) ----------
  reg        prev_ex_valid;
  reg [31:0] prev_ex_alu_out;
  reg [31:0] prev_ex_rs2_fwd;
  reg [4:0]  prev_ex_rd;
  reg        prev_ex_reg_write, prev_ex_mem_read, prev_ex_mem_write, prev_ex_mem_to_reg;

  // ---------- prev EXMEM (para chequear MEM/WB) ----------
  reg        prev_exmem_valid;
  reg [31:0] prev_exmem_alu_out;
  reg [4:0]  prev_exmem_rd;
  reg        prev_exmem_reg_write, prev_exmem_mem_to_reg;

  // ---------- scoreboard de writes ----------
  reg [4:0]  exp_rd [0:TOTAL_WRITES-1];
  reg [31:0] exp_wd [0:TOTAL_WRITES-1];
  integer    exp_idx;

  integer store_idx;
  reg [31:0] exp_store_addr [0:TOTAL_STORES-1];
  reg [31:0] exp_store_data [0:TOTAL_STORES-1];
  reg [3:0]  exp_store_be   [0:TOTAL_STORES-1];
    
  initial begin
    cyc = 0;

    prev_ex_valid       = 0;
    prev_ex_alu_out     = 0;
    prev_ex_rs2_fwd     = 0;
    prev_ex_rd          = 0;
    prev_ex_reg_write   = 0;
    prev_ex_mem_read    = 0;
    prev_ex_mem_write   = 0;
    prev_ex_mem_to_reg  = 0;

    prev_exmem_valid      = 0;
    prev_exmem_alu_out    = 0;
    prev_exmem_rd         = 0;
    prev_exmem_reg_write  = 0;
    prev_exmem_mem_to_reg = 0;

    // --------------------------------------------------------
    // Scoreboard esperado para ETAPA A
    // Programa asumido:
    //   addi x1,  x0, 5
    //   addi x2,  x0, 10
    //   add  x3,  x1, x2
    //   sub  x4,  x3, x1
    //   andi x5,  x3, 7
    //   and  x6,  x1, x2
    //   ori  x7,  x1, 8
    //   or   x8,  x1, x2
    //   xori x9,  x1, 3
    //   xor  x10, x1, x2
    //   srl  x11, x2, x1
    //   addi x12, x0, -8
    //   addi x13, x0, 2
    //   sra  x14, x12, x13
    //   srl  x15, x12, x13
    // --------------------------------------------------------
    // ETAPA A
    exp_rd[0]  = 5'd1;   exp_wd[0]  = 32'd5;
    exp_rd[1]  = 5'd2;   exp_wd[1]  = 32'd10;
    exp_rd[2]  = 5'd3;   exp_wd[2]  = 32'd15;
    exp_rd[3]  = 5'd4;   exp_wd[3]  = 32'd10;
    exp_rd[4]  = 5'd5;   exp_wd[4]  = 32'd7;
    exp_rd[5]  = 5'd6;   exp_wd[5]  = 32'd0;
    exp_rd[6]  = 5'd7;   exp_wd[6]  = 32'd13;
    exp_rd[7]  = 5'd8;   exp_wd[7]  = 32'd15;
    exp_rd[8]  = 5'd9;   exp_wd[8]  = 32'd6;
    exp_rd[9]  = 5'd10;  exp_wd[9]  = 32'd15;
    exp_rd[10] = 5'd11;  exp_wd[10] = 32'd0;
    exp_rd[11] = 5'd12;  exp_wd[11] = 32'hfffffff8;
    exp_rd[12] = 5'd13;  exp_wd[12] = 32'd2;
    exp_rd[13] = 5'd14;  exp_wd[13] = 32'hfffffffe;
    exp_rd[14] = 5'd15;  exp_wd[14] = 32'h3ffffffe;
    
    // ETAPA B
    exp_rd[15] = 5'd16;  exp_wd[15] = 32'd1;
    exp_rd[16] = 5'd17;  exp_wd[16] = 32'd4;
    exp_rd[17] = 5'd18;  exp_wd[17] = 32'd16;
    exp_rd[18] = 5'd19;  exp_wd[18] = 32'd1;
    exp_rd[19] = 5'd20;  exp_wd[19] = 32'd1;
    exp_rd[20] = 5'd21;  exp_wd[20] = 32'd0;
    exp_rd[21] = 5'd22;  exp_wd[21] = 32'd1;
    exp_rd[22] = 5'd23;  exp_wd[22] = 32'hffffffff;
    exp_rd[23] = 5'd24;  exp_wd[23] = 32'd1;
    exp_rd[24] = 5'd25;  exp_wd[24] = 32'd0;
    exp_rd[25] = 5'd26;  exp_wd[25] = 32'h12345000;
    exp_rd[26] = 5'd27;  exp_wd[26] = 32'd0;
    exp_rd[27] = 5'd28; exp_wd[27] = 32'd64;
    exp_rd[28] = 5'd29; exp_wd[28] = 32'd42;
    exp_rd[29] = 5'd30; exp_wd[29] = 32'd42;
    exp_rd[30] = 5'd29; exp_wd[30] = 32'hfffffff9; // -7
    exp_rd[31] = 5'd31; exp_wd[31] = 32'hfffffff9; // -7
    exp_rd[32] = 5'd5;   exp_wd[32] = 32'hfffffff9; // lb
    exp_rd[33] = 5'd6;   exp_wd[33] = 32'hfffffff9; // lb
    exp_rd[34] = 5'd7;   exp_wd[34] = 32'hfffffff9; // lh
    exp_rd[35] = 5'd8;   exp_wd[35] = 32'hfffffff9; // lh
    exp_rd[36] = 5'd9;   exp_wd[36] = 32'h000000f9; // lbu
    exp_rd[37] = 5'd10;  exp_wd[37] = 32'h000000f9; // lbu
    exp_rd[38] = 5'd11;  exp_wd[38] = 32'h0000fff9; // lhu
    exp_rd[39] = 5'd12;  exp_wd[39] = 32'h0000fff9; // lhu
    
    store_idx = 0;

    // -------------------------
    // C1: SW
    // -------------------------
    exp_store_addr[0] = 32'd64;
    exp_store_data[0] = 32'd42;
    exp_store_be[0]   = 4'b1111;

    exp_store_addr[1] = 32'd68;
    exp_store_data[1] = 32'hfffffff9; // -7
    exp_store_be[1]   = 4'b1111;

    // -------------------------
    // C2: SB / SH
    // x29 = 0xFFFF_FFF9
    // -------------------------
    exp_store_addr[2] = 32'd72;          // sb x29, 8(x28)
    exp_store_data[2] = 32'h000000F9;
    exp_store_be[2]   = 4'b0001;

    exp_store_addr[3] = 32'd73;          // sb x29, 9(x28)
    exp_store_data[3] = 32'h0000F900;
    exp_store_be[3]   = 4'b0010;

    exp_store_addr[4] = 32'd76;          // sh x29,12(x28)
    exp_store_data[4] = 32'h0000FFF9;
    exp_store_be[4]   = 4'b0011;

    exp_store_addr[5] = 32'd78;          // sh x29,14(x28)
    exp_store_data[5] = 32'hFFF90000;
    exp_store_be[5]   = 4'b1100;
  end

  function [31:0] be_mask32;
    input [3:0] be;
    begin
      be_mask32 = {
        {8{be[3]}},
        {8{be[2]}},
        {8{be[1]}},
        {8{be[0]}}
      };
    end
  endfunction

  always @(posedge clk) begin
    #1;
    cyc = cyc + 1;

    if (reset) begin
      exp_idx = 0;
    end else begin

      // ---------- IF sanity ----------
      if (has_x32(dut.if_pc) || has_x32(dut.if_instr)) begin
        $display("FATAL: X en IF (C%0d) PC=%h IN=%h", cyc, dut.if_pc, dut.if_instr);
        $finish;
      end

      // ---------- EX: chequeo funcional de ALU ----------
      if (dut.ex_valid && dut.ex_reg_write && (dut.ex_rd_idx != 5'd0)) begin
        a_s   = $signed(dut.ex_operand_a);
        b_s   = dut.idex_alu_src ? $signed(dut.idex_imm) : $signed(dut.ex_rs2_forwarded_in);
        exp_s = alu_ref(a_s, b_s, dut.idex_alu_op);

        $display("EX  C%0d | op=%s | rd=x%0d | FwdA=%b FwdB=%b | A=%0d (0x%h) | B=%0d (0x%h) | ALU got=%0d (0x%h) exp=%0d (0x%h)",
                 cyc,
                 alu_op_name(dut.idex_alu_op),
                 dut.ex_rd_idx,
                 dut.forward_a_sel,
                 dut.forward_b_sel,
                 a_s, a_s,
                 b_s, b_s,
                 dut.ex_alu_result, dut.ex_alu_result,
                 exp_s, exp_s);

        if (dut.ex_alu_result !== exp_s) begin
          $display("ERR: EX ALU mismatch en C%0d", cyc);
          $display("     op=%s rd=x%0d", alu_op_name(dut.idex_alu_op), dut.ex_rd_idx);
          $display("     A=%0d (0x%h)", a_s, a_s);
          $display("     B=%0d (0x%h)", b_s, b_s);
          $display("     GOT=%0d (0x%h)", dut.ex_alu_result, dut.ex_alu_result);
          $display("     EXP=%0d (0x%h)", exp_s, exp_s);
          $finish;
        end
      end

      // ---------- EX/MEM latch check ----------
      if (cyc > 2) begin
        if (dut.exmem_valid         !== prev_ex_valid      ||
            dut.exmem_alu_result    !== prev_ex_alu_out    ||
            dut.exmem_rs2_forwarded !== prev_ex_rs2_fwd    ||
            dut.exmem_rd_idx        !== prev_ex_rd         ||
            dut.exmem_reg_write     !== prev_ex_reg_write  ||
            dut.exmem_mem_read      !== prev_ex_mem_read   ||
            dut.exmem_mem_write     !== prev_ex_mem_write  ||
            dut.exmem_mem_to_reg    !== prev_ex_mem_to_reg) begin
          $display("ERR: EX/MEM no latcheó correctamente la salida previa de EX (C%0d)", cyc);
          $finish;
        end
      end

      // ---------- Stores esperados en MEM ----------
      if (dut.mem_write_enable === 1'b1) begin
          if (store_idx >= TOTAL_STORES) begin
              $display("ERR: store extra inesperado en C%0d | addr=%h data=%h be=%b",
                      cyc, dut.mem_addr, dut.mem_write_data, dut.mem_byte_enable);
              $finish;
          end

          if (dut.mem_addr !== exp_store_addr[store_idx] ||
              dut.mem_byte_enable !== exp_store_be[store_idx] ||
              (dut.mem_write_data & be_mask32(dut.mem_byte_enable)) !==
              (exp_store_data[store_idx] & be_mask32(exp_store_be[store_idx]))) begin
              $display("ERR: store mismatch en C%0d", cyc);
              $display("     got : addr=%h data=%h byte_en=%b masked=%h",
                      dut.mem_addr,
                      dut.mem_write_data,
                      dut.mem_byte_enable,
                      (dut.mem_write_data & be_mask32(dut.mem_byte_enable)));
              $display("     exp : addr=%h data=%h byte_en=%b masked=%h",
                      exp_store_addr[store_idx],
                      exp_store_data[store_idx],
                      exp_store_be[store_idx],
                      (exp_store_data[store_idx] & be_mask32(exp_store_be[store_idx])));
              $finish;
          end

          $display("OK  MEM store #%0d | addr=%0d (0x%h) <= bus=%h | be=%b | masked=%h",
                  store_idx,
                  dut.mem_addr, dut.mem_addr,
                  dut.mem_write_data,
                  dut.mem_byte_enable,
                  (dut.mem_write_data & be_mask32(dut.mem_byte_enable)));

          store_idx = store_idx + 1;
      end
          
      // ---------- MEM/WB latch check ----------
      if (cyc > 3) begin
        if (dut.memwb_valid      !== prev_exmem_valid      ||
            dut.memwb_alu_result !== prev_exmem_alu_out    ||
            dut.memwb_rd_idx     !== prev_exmem_rd         ||
            dut.memwb_reg_write  !== prev_exmem_reg_write  ||
            dut.memwb_mem_to_reg !== prev_exmem_mem_to_reg) begin
          $display("ERR: MEM/WB no latcheó correctamente la salida previa de EX/MEM (C%0d)", cyc);
          $finish;
        end
      end

      // ---------- WB mux check ----------
      if (dut.memwb_mem_to_reg === 1'b0) begin
        if (dut.wb_write_data !== dut.memwb_alu_result) begin
          $display("ERR: WB mux (MemToReg=0) en C%0d", cyc);
          $display("     wb_write_data=%h memwb_alu_result=%h",
                   dut.wb_write_data, dut.memwb_alu_result);
          $finish;
        end
      end else if (dut.memwb_mem_to_reg === 1'b1) begin
        if (dut.wb_write_data !== dut.memwb_mem_rdata) begin
          $display("ERR: WB mux (MemToReg=1) en C%0d", cyc);
          $display("     wb_write_data=%h memwb_mem_rdata=%h",
                   dut.wb_write_data, dut.memwb_mem_rdata);
          $finish;
        end
      end else begin
        $display("ERR: MemToReg en X (C%0d)", cyc);
        $finish;
      end

      // ---------- Scoreboard de writes al regfile ----------
      if (dut.wb_we && (dut.wb_rd_idx != 5'd0)) begin
        if (exp_idx >= TOTAL_WRITES) begin
          $display("ERR: write extra inesperado en C%0d | rd=x%0d | wdata=%0d (0x%h)",
                   cyc, dut.wb_rd_idx, dut.wb_write_data, dut.wb_write_data);
          $finish;
        end

        if (dut.wb_rd_idx !== exp_rd[exp_idx] || dut.wb_write_data !== exp_wd[exp_idx]) begin
          $display("ERR: WB write mismatch en C%0d", cyc);
          $display("     instruccion esperada: %s", exp_desc(exp_idx));
          $display("     got : rd=x%0d wd=%0d (0x%h)",
                   dut.wb_rd_idx, dut.wb_write_data, dut.wb_write_data);
          $display("     exp : rd=x%0d wd=%0d (0x%h)",
                   exp_rd[exp_idx], exp_wd[exp_idx], exp_wd[exp_idx]);
          $finish;
        end

        $display("OK  WB #%0d | %s | x%0d <= %0d (0x%h)",
                 exp_idx,
                 exp_desc(exp_idx),
                 dut.wb_rd_idx,
                 dut.wb_write_data,
                 dut.wb_write_data);

        exp_idx = exp_idx + 1;

        if ((exp_idx == TOTAL_WRITES) && (store_idx == TOTAL_STORES)) begin
            $display("==============================================================");
            $display("OK: ETAPA A + ETAPA B + ETAPA C1 + ETAPA C2 + ETAPA C3 verificadas.");
            $display("    A: ADDI, ADD, SUB, ANDI, AND, ORI, OR, XORI, XOR, SRL, SRA");
            $display("    B: SLL, SLT, SLTU, SLTI, SLTIU, LUI");
            $display("    C1: LW, SW");
            $display("    C2: SB, SH");
            $display("    C3: LB, LH, LBU, LHU");
            $display("==============================================================");
            $finish;
        end
      end

      // ---------- Print compacto por ciclo ----------
      $display("C%0d | IF: PC=%h IN=%h | EX: alu=%0d rd=x%0d v=%b | EXMEM: alu=%0d rd=x%0d v=%b | WB: we=%b rd=x%0d wd=%0d",
               cyc,
               dut.if_pc, dut.if_instr,
               dut.ex_alu_result, dut.ex_rd_idx, dut.ex_valid,
               dut.exmem_alu_result, dut.exmem_rd_idx, dut.exmem_valid,
               dut.wb_we, dut.wb_rd_idx, dut.wb_write_data);
    end

    // -------- guardar prev EX para EX/MEM check --------
    prev_ex_valid      = dut.ex_valid;
    prev_ex_alu_out    = dut.ex_alu_result;
    prev_ex_rs2_fwd    = dut.ex_rs2_forwarded;
    prev_ex_rd         = dut.ex_rd_idx;
    prev_ex_reg_write  = dut.ex_reg_write;
    prev_ex_mem_read   = dut.ex_mem_read;
    prev_ex_mem_write  = dut.ex_mem_write;
    prev_ex_mem_to_reg = dut.ex_mem_to_reg;

    // -------- guardar prev EXMEM para MEM/WB check --------
    prev_exmem_valid      = dut.exmem_valid;
    prev_exmem_alu_out    = dut.exmem_alu_result;
    prev_exmem_rd         = dut.exmem_rd_idx;
    prev_exmem_reg_write  = dut.exmem_reg_write;
    prev_exmem_mem_to_reg = dut.exmem_mem_to_reg;

    // watchdog por si algo cuelga
    if (cyc == 300) begin
      $display("TIMEOUT: no se observaron los %0d writes esperados para Etapa A.", TOTAL_WRITES);
      $finish;
    end
  end

endmodule