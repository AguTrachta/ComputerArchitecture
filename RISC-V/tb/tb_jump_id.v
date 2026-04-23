`timescale 1ns/1ps
module tb_jump_id;

  localparam NB_OP = 6;
  localparam DMEM_BYTES = 4096;

  localparam TOTAL_WRITES = 21;
  localparam EXPECTED_TAKEN_JUMPS = 6;
  localparam EXPECTED_STALL_CYCLES = 3;

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
  integer taken_jump_count;
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

  // Waves
  initial begin
    $dumpfile("tb_jump_id.vcd");
    $dumpvars(0, tb_jump_id);
  end

  function has_x32;
    input [31:0] v;
    begin
      has_x32 = (^v === 1'bx);
    end
  endfunction

  function [8*30-1:0] exp_desc;
    input integer idx;
    begin
      case (idx)
        0  : exp_desc = "addi x1, x0, 5";
        1  : exp_desc = "jal x5, +8";
        2  : exp_desc = "addi x3, x0, 33";
        3  : exp_desc = "addi x6, x0, 66";
        4  : exp_desc = "addi x10, x0, 44";
        5  : exp_desc = "addi x14, x0, 1";
        6  : exp_desc = "jalr x7, x10, 0";
        7  : exp_desc = "addi x9, x0, 99";
        8  : exp_desc = "addi x11, x0, 64";
        9  : exp_desc = "addi x15, x0, 2";
        10 : exp_desc = "addi x13, x0, 130";
        11 : exp_desc = "addi x17, x0, 84";
        12 : exp_desc = "addi x18, x0, 4";
        13 : exp_desc = "add x19, x17, x18";
        14 : exp_desc = "jalr x20, x19, 0";
        15 : exp_desc = "addi x22, x0, 220";
        16 : exp_desc = "addi x28, x0, 64";
        17 : exp_desc = "addi x29, x0, 124";
        18 : exp_desc = "lw x23, 0(x28)";
        19 : exp_desc = "jalr x24, x23, 0";
        20 : exp_desc = "addi x26, x0, 260";
        default: exp_desc = "unknown";
      endcase
    end
  endfunction

  initial begin
    cyc = 0;
    exp_idx = 0;
    taken_jump_count = 0;
    stall_count = 0;

    exp_rd[0]  = 5'd1;   exp_wd[0]  = 32'd5;
    exp_rd[1]  = 5'd5;   exp_wd[1]  = 32'd8;    // jal link = PC+4
    exp_rd[2]  = 5'd3;   exp_wd[2]  = 32'd33;
    exp_rd[3]  = 5'd6;   exp_wd[3]  = 32'd66;

    exp_rd[4]  = 5'd10;  exp_wd[4]  = 32'd44;
    exp_rd[5]  = 5'd14;  exp_wd[5]  = 32'd1;
    exp_rd[6]  = 5'd7;   exp_wd[6]  = 32'd40;   // jalr link = 0x28 = 40
    exp_rd[7]  = 5'd9;   exp_wd[7]  = 32'd99;

    exp_rd[8]  = 5'd11;  exp_wd[8]  = 32'd64;
    exp_rd[9]  = 5'd15;  exp_wd[9]  = 32'd2;
    exp_rd[10] = 5'd13;  exp_wd[10] = 32'd130;

    exp_rd[11] = 5'd17;  exp_wd[11] = 32'd84;
    exp_rd[12] = 5'd18;  exp_wd[12] = 32'd4;
    exp_rd[13] = 5'd19;  exp_wd[13] = 32'd88;
    exp_rd[14] = 5'd20;  exp_wd[14] = 32'd84;   // jalr link = 0x54 = 84
    exp_rd[15] = 5'd22;  exp_wd[15] = 32'd220;

    exp_rd[16] = 5'd28;  exp_wd[16] = 32'd64;
    exp_rd[17] = 5'd29;  exp_wd[17] = 32'd124;
    exp_rd[18] = 5'd23;  exp_wd[18] = 32'd124;
    exp_rd[19] = 5'd24;  exp_wd[19] = 32'd112;  // jalr link = 0x70 = 112
    exp_rd[20] = 5'd26;  exp_wd[20] = 32'd260;
  end

  always @(posedge clk) begin
    #1;
    cyc = cyc + 1;

    if (!reset) begin
      if (has_x32(dut.if_pc) || has_x32(dut.if_instr)) begin
        $display("FATAL: X en IF (C%0d) PC=%h IN=%h", cyc, dut.if_pc, dut.if_instr);
        $finish;
      end

      if (dut.jump_taken_id)
        taken_jump_count = taken_jump_count + 1;

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

      $display("C%0d | IF:PC=%h IN=%h | ID:jal=%b jalr=%b jump_taken=%b stall=%b | WB:we=%b rd=x%0d wd=%0d",
               cyc,
               dut.if_pc, dut.if_instr,
               dut.ifid_is_jal,
               dut.ifid_is_jalr,
               dut.jump_taken_id,
               dut.stall_if,
               dut.wb_we, dut.wb_rd_idx, dut.wb_write_data);

      if (exp_idx == TOTAL_WRITES) begin
        if (taken_jump_count !== EXPECTED_TAKEN_JUMPS) begin
          $display("ERR: cantidad de jumps tomados incorrecta");
          $display("     got=%0d exp=%0d", taken_jump_count, EXPECTED_TAKEN_JUMPS);
          $finish;
        end

        if (stall_count !== EXPECTED_STALL_CYCLES) begin
          $display("ERR: cantidad de stalls incorrecta");
          $display("     got=%0d exp=%0d", stall_count, EXPECTED_STALL_CYCLES);
          $finish;
        end

        $display("==============================================================");
        $display("OK: ETAPA E verificada.");
        $display("    Jumps tomados detectados : %0d", taken_jump_count);
        $display("    Ciclos de stall detectados: %0d", stall_count);
        $display("    Casos cubiertos: JAL, J, JALR, JR,");
        $display("                    ALU -> JALR (1 stall),");
        $display("                    LW  -> JALR (2 stalls).");
        $display("==============================================================");
        $finish;
      end
    end

    if (cyc == 250) begin
      $display("TIMEOUT en tb_jump_id");
      $finish;
    end
  end

endmodule