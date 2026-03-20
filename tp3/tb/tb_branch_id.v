`timescale 1ns/1ps

module tb_branch_id;

  localparam NB_OP      = 6;
  localparam DMEM_BYTES = 4096;
  localparam TOTAL_WRITES = 22;
  localparam EXPECTED_TAKEN_BRANCHES = 4;
  
// 7 stalls totales:
//   beq x1,x2   -> 1
//   bne x5,x6   -> 1
//   beq x9,x10  -> 1
//   bne x13,x14 -> 1
//   beq x19,x19 -> 1
//   beq x22,x29 -> 2
  localparam EXPECTED_STALL_CYCLES    = 7;

  reg clk, reset;

  top #(
    .NB_OP(NB_OP),
    .DMEM_BYTES(DMEM_BYTES)
  ) dut (
    .clk(clk),
    .reset(reset)
  );

  integer cyc;
  integer exp_idx;
  integer taken_branch_count;
  integer stall_count;

  reg [4:0]  exp_rd [0:TOTAL_WRITES-1];
  reg [31:0] exp_wd [0:TOTAL_WRITES-1];

  // Clock
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

  function has_x32;
    input [31:0] v;
    begin
      has_x32 = (^v === 1'bx);
    end
  endfunction

  function [8*28-1:0] exp_desc;
    input integer idx;
    begin
      case (idx)
        0  : exp_desc = "addi x1, x0, 5";
        1  : exp_desc = "addi x2, x0, 5";
        2  : exp_desc = "addi x4, x0, 222";
        3  : exp_desc = "addi x5, x0, 1";
        4  : exp_desc = "addi x6, x0, 2";
        5  : exp_desc = "addi x8, x0, 77";
        6  : exp_desc = "addi x9, x0, 9";
        7  : exp_desc = "addi x10, x0, 8";
        8  : exp_desc = "addi x11, x0, 55";
        9  : exp_desc = "addi x12, x0, 66";
        10 : exp_desc = "addi x13, x0, 7";
        11 : exp_desc = "addi x14, x0, 7";
        12 : exp_desc = "addi x15, x0, 88";
        13 : exp_desc = "addi x16, x0, 99";
        14 : exp_desc = "addi x17, x0, 1";
        15 : exp_desc = "addi x18, x0, 2";
        16 : exp_desc = "add x19, x17, x18";
        17 : exp_desc = "addi x21, x0, 210";
        18 : exp_desc = "addi x28, x0, 64";
        19 : exp_desc = "addi x29, x0, 42";
        20 : exp_desc = "lw x22, 0(x28)";
        21 : exp_desc = "addi x24, x0, 240";
        default: exp_desc = "unknown";
      endcase
    end
  endfunction

  initial begin
    cyc = 0;
    exp_idx = 0;
    taken_branch_count = 0;
    stall_count = 0;

    exp_rd[0]  = 5'd1;   exp_wd[0]  = 32'd5;
    exp_rd[1]  = 5'd2;   exp_wd[1]  = 32'd5;
    exp_rd[2]  = 5'd4;   exp_wd[2]  = 32'd222;

    exp_rd[3]  = 5'd5;   exp_wd[3]  = 32'd1;
    exp_rd[4]  = 5'd6;   exp_wd[4]  = 32'd2;
    exp_rd[5]  = 5'd8;   exp_wd[5]  = 32'd77;

    exp_rd[6]  = 5'd9;   exp_wd[6]  = 32'd9;
    exp_rd[7]  = 5'd10;  exp_wd[7]  = 32'd8;
    exp_rd[8]  = 5'd11;  exp_wd[8]  = 32'd55;
    exp_rd[9]  = 5'd12;  exp_wd[9]  = 32'd66;

    exp_rd[10] = 5'd13;  exp_wd[10] = 32'd7;
    exp_rd[11] = 5'd14;  exp_wd[11] = 32'd7;
    exp_rd[12] = 5'd15;  exp_wd[12] = 32'd88;
    exp_rd[13] = 5'd16;  exp_wd[13] = 32'd99;

    exp_rd[14] = 5'd17;  exp_wd[14] = 32'd1;
    exp_rd[15] = 5'd18;  exp_wd[15] = 32'd2;
    exp_rd[16] = 5'd19;  exp_wd[16] = 32'd3;
    exp_rd[17] = 5'd21;  exp_wd[17] = 32'd210;

    exp_rd[18] = 5'd28;  exp_wd[18] = 32'd64;
    exp_rd[19] = 5'd29;  exp_wd[19] = 32'd42;
    exp_rd[20] = 5'd22;  exp_wd[20] = 32'd42;
    exp_rd[21] = 5'd24;  exp_wd[21] = 32'd240;
  end

  always @(posedge clk) begin
    #1;
    cyc = cyc + 1;

    if (!reset) begin
      if (has_x32(dut.if_pc) || has_x32(dut.if_instr)) begin
        $display("FATAL: X en IF (C%0d) PC=%h IN=%h", cyc, dut.if_pc, dut.if_instr);
        $finish;
      end

      if (dut.branch_taken_id)
        taken_branch_count = taken_branch_count + 1;

      if (dut.stall_if)
        stall_count = stall_count + 1;

      if (dut.wb_we && (dut.wb_rd_idx != 5'd0)) begin
        if (exp_idx >= TOTAL_WRITES) begin
          $display("ERR: write extra inesperado en C%0d | rd=x%0d wd=%0d (0x%h)",
                   cyc, dut.wb_rd_idx, dut.wb_write_data, dut.wb_write_data);
          $finish;
        end

        if ((dut.wb_rd_idx !== exp_rd[exp_idx]) ||
            (dut.wb_write_data !== exp_wd[exp_idx])) begin
          $display("ERR: WB mismatch en C%0d", cyc);
          $display("     esperado: %s", exp_desc(exp_idx));
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
      end

      $display("C%0d | IF:PC=%h IN=%h | ID:branch=%b taken=%b stall=%b | WB:we=%b rd=x%0d wd=%0d",
               cyc,
               dut.if_pc, dut.if_instr,
               dut.ifid_is_branch,
               dut.branch_taken_id,
               dut.stall_if,
               dut.wb_we, dut.wb_rd_idx, dut.wb_write_data);

      if (exp_idx == TOTAL_WRITES) begin
        if (taken_branch_count !== EXPECTED_TAKEN_BRANCHES) begin
          $display("ERR: cantidad de branches tomados incorrecta");
          $display("     got=%0d exp=%0d", taken_branch_count, EXPECTED_TAKEN_BRANCHES);
          $finish;
        end

        if (stall_count !== EXPECTED_STALL_CYCLES) begin
          $display("ERR: cantidad de stalls incorrecta");
          $display("     got=%0d exp=%0d", stall_count, EXPECTED_STALL_CYCLES);
          $finish;
        end

        $display("==============================================================");
        $display("OK: ETAPA D verificada.");
        $display("    Branches tomados detectados: %0d", taken_branch_count);
        $display("    Ciclos de stall detectados : %0d", stall_count);
        $display("    Casos cubiertos: BEQ/BNE tomado y no tomado,");
        $display("                    dependencia con ALU (1 stall),");
        $display("                    dependencia con LW  (2 stalls).");
        $display("==============================================================");
        $finish;
      end
    end

    if (cyc == 250) begin
      $display("TIMEOUT en tb_branch_id");
      $finish;
    end
  end

endmodule
