`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/07/2026 04:17:09 PM
// Design Name: 
// Module Name: tb_top_mem_wb
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


module tb_top_mem_wb;

    // Clock 100MHz (10ns)
    reg clk = 0;
    always #5 clk = ~clk;

    reg reset;

    // Inputs EX/MEM simulados
    reg        exmem_valid;
    reg [31:0] exmem_alu_out;
    reg [31:0] exmem_rs2_fwd;
    reg [4:0]  exmem_rd;
    reg        exmem_RegWrite;
    reg        exmem_MemRead;
    reg        exmem_MemWrite;
    reg        exmem_MemToReg;

    // Outputs WB
    wire        wb_valid;
    wire        wb_RegWrite;
    wire [4:0]  wb_rd;
    wire [31:0] wb_wdata;

    // DUT
    top_mem_wb dut (
        .clk(clk),
        .reset(reset),

        .exmem_valid(exmem_valid),
        .exmem_alu_out(exmem_alu_out),
        .exmem_rs2_fwd(exmem_rs2_fwd),
        .exmem_rd(exmem_rd),

        .exmem_RegWrite(exmem_RegWrite),
        .exmem_MemRead(exmem_MemRead),
        .exmem_MemWrite(exmem_MemWrite),
        .exmem_MemToReg(exmem_MemToReg),

        .wb_valid(wb_valid),
        .wb_RegWrite(wb_RegWrite),
        .wb_rd(wb_rd),
        .wb_wdata(wb_wdata)
    );

    // -------------------------
    // Helpers
    // -------------------------
    task drive_nop;
    begin
        exmem_valid    = 1'b0;
        exmem_alu_out  = 32'h0;
        exmem_rs2_fwd  = 32'h0;
        exmem_rd       = 5'd0;
        exmem_RegWrite = 1'b0;
        exmem_MemRead  = 1'b0;
        exmem_MemWrite = 1'b0;
        exmem_MemToReg = 1'b0;
    end
    endtask

    task check_wb_invalid;
    begin
        #1;
        if (wb_valid !== 1'b0) begin
            $display("FAIL: esperaba wb_valid=0, tengo %0d", wb_valid);
            $fatal;
        end else begin
            $display("PASS: wb_valid=0 (NOP/invalid)");
        end
    end
    endtask

    task do_store_word(input [31:0] addr, input [31:0] data);
    begin
        exmem_valid    = 1'b1;
        exmem_alu_out  = addr;
        exmem_rs2_fwd  = data;
        exmem_rd       = 5'd0;

        exmem_RegWrite = 1'b0;
        exmem_MemRead  = 1'b0;
        exmem_MemWrite = 1'b1;
        exmem_MemToReg = 1'b0;

        @(posedge clk);
        drive_nop();
    end
    endtask

    // Igual que store, pero NO mete NOP al final (para back-to-back)
    task do_store_word_no_nop(input [31:0] addr, input [31:0] data);
    begin
        exmem_valid    = 1'b1;
        exmem_alu_out  = addr;
        exmem_rs2_fwd  = data;
        exmem_rd       = 5'd0;

        exmem_RegWrite = 1'b0;
        exmem_MemRead  = 1'b0;
        exmem_MemWrite = 1'b1;
        exmem_MemToReg = 1'b0;

        @(posedge clk);
    end
    endtask

    // Store con valid=0 (no debería escribir nada)
    task do_store_word_invalid_should_not_write(input [31:0] addr, input [31:0] data);
    begin
        exmem_valid    = 1'b0;      // <- invalid
        exmem_alu_out  = addr;
        exmem_rs2_fwd  = data;
        exmem_rd       = 5'd0;

        exmem_RegWrite = 1'b0;
        exmem_MemRead  = 1'b0;
        exmem_MemWrite = 1'b1;      // aunque esté en 1, el top lo gatea con valid
        exmem_MemToReg = 1'b0;

        @(posedge clk);
        drive_nop();
    end
    endtask

    task do_load_word_and_check(input [31:0] addr, input [4:0] rd, input [31:0] expected);
    begin
        exmem_valid    = 1'b1;
        exmem_alu_out  = addr;
        exmem_rs2_fwd  = 32'h0;
        exmem_rd       = rd;

        exmem_RegWrite = 1'b1;
        exmem_MemRead  = 1'b1;
        exmem_MemWrite = 1'b0;
        exmem_MemToReg = 1'b1;

        @(posedge clk);
        #1;

        if (!(wb_valid && wb_RegWrite && (wb_rd == rd) && (wb_wdata == expected))) begin
            $display("FAIL LW: addr=%h wb_valid=%0d wb_RegWrite=%0d wb_rd=%0d wb_wdata=%h expected=%h",
                     addr, wb_valid, wb_RegWrite, wb_rd, wb_wdata, expected);
            $fatal;
        end else begin
            $display("PASS LW: addr=%h -> x%0d=%h", addr, rd, wb_wdata);
        end

        drive_nop();
    end
    endtask

    // Load sin NOP al final (para back-to-back si querés encadenar)
    task do_load_word_and_check_no_nop(input [31:0] addr, input [4:0] rd, input [31:0] expected);
    begin
        exmem_valid    = 1'b1;
        exmem_alu_out  = addr;
        exmem_rs2_fwd  = 32'h0;
        exmem_rd       = rd;

        exmem_RegWrite = 1'b1;
        exmem_MemRead  = 1'b1;
        exmem_MemWrite = 1'b0;
        exmem_MemToReg = 1'b1;

        @(posedge clk);
        #1;

        if (!(wb_valid && wb_RegWrite && (wb_rd == rd) && (wb_wdata == expected))) begin
            $display("FAIL LW(no_nop): addr=%h wb_valid=%0d wb_RegWrite=%0d wb_rd=%0d wb_wdata=%h expected=%h",
                     addr, wb_valid, wb_RegWrite, wb_rd, wb_wdata, expected);
            $fatal;
        end else begin
            $display("PASS LW(no_nop): addr=%h -> x%0d=%h", addr, rd, wb_wdata);
        end
    end
    endtask

    // Load con valid=0 (no debería "contar")
    task do_load_invalid_should_not_count;
    begin
        exmem_valid    = 1'b0;     // <- invalid
        exmem_alu_out  = 32'h0000_0010;
        exmem_rs2_fwd  = 32'h0;
        exmem_rd       = 5'd1;

        exmem_RegWrite = 1'b1;
        exmem_MemRead  = 1'b1;
        exmem_MemWrite = 1'b0;
        exmem_MemToReg = 1'b1;

        @(posedge clk);
        check_wb_invalid();
        drive_nop();
    end
    endtask

    task do_alu_wb_and_check(input [31:0] alu_res, input [4:0] rd, input [31:0] expected);
    begin
        exmem_valid    = 1'b1;
        exmem_alu_out  = alu_res;
        exmem_rs2_fwd  = 32'h0;
        exmem_rd       = rd;

        exmem_RegWrite = 1'b1;
        exmem_MemRead  = 1'b0;
        exmem_MemWrite = 1'b0;
        exmem_MemToReg = 1'b0; // select ALU

        @(posedge clk);
        #1;

        if (!(wb_valid && wb_RegWrite && (wb_rd == rd) && (wb_wdata == expected))) begin
            $display("FAIL ALU-WB: wb_valid=%0d wb_RegWrite=%0d wb_rd=%0d wb_wdata=%h expected=%h",
                     wb_valid, wb_RegWrite, wb_rd, wb_wdata, expected);
            $fatal;
        end else begin
            $display("PASS ALU-WB: x%0d=%h", rd, wb_wdata);
        end

        drive_nop();
    end
    endtask

    // Check opcional de write-first mirando la salida de la RAM interna del top
    task check_write_first_dmem_rdata(input [31:0] expected);
    begin
        #1;
        if (dut.dmem_rdata !== expected) begin
            $display("FAIL write-first: dmem_rdata=%h expected=%h", dut.dmem_rdata, expected);
            $fatal;
        end else begin
            $display("PASS write-first: dmem_rdata=%h", dut.dmem_rdata);
        end
    end
    endtask

    // -------------------------
    // Test sequence
    // -------------------------
    initial begin
        $dumpfile("tb_top_mem_wb.vcd");
        $dumpvars(0, tb_top_mem_wb);

        reset = 1'b1;
        drive_nop();

        // reset 2 ciclos
        @(posedge clk);
        @(posedge clk);
        reset = 1'b0;

        // A) Básicos
        do_store_word(32'h0000_0010, 32'hDEAD_BEEF);
        do_load_word_and_check(32'h0000_0010, 5'd3, 32'hDEAD_BEEF);
        do_alu_wb_and_check(32'h1234_5678, 5'd7, 32'h1234_5678);

        // NOP / invalid
        drive_nop();
        @(posedge clk);
        check_wb_invalid();

        // B4) Back-to-back SW -> LW sin NOP
        do_store_word_no_nop(32'h0000_0010, 32'hAAAA_5555);
        check_write_first_dmem_rdata(32'hAAAA_5555); // opcional
        do_load_word_and_check(32'h0000_0010, 5'd1, 32'hAAAA_5555);

        // B5) LW repetido
        do_store_word(32'h0000_0014, 32'h1111_2222);
        do_load_word_and_check_no_nop(32'h0000_0014, 5'd2, 32'h1111_2222);
        do_load_word_and_check      (32'h0000_0014, 5'd2, 32'h1111_2222);

        // C6) Dos palabras distintas: 0x10 y 0x14
        do_store_word(32'h0000_0010, 32'h3333_4444);
        do_store_word(32'h0000_0014, 32'h5555_6666);
        do_load_word_and_check(32'h0000_0010, 5'd4, 32'h3333_4444);
        do_load_word_and_check(32'h0000_0014, 5'd5, 32'h5555_6666);

        // C7) Misaligned (debe dar 0 por access_ok)
        do_load_word_and_check(32'h0000_0012, 5'd6, 32'h0000_0000);

        // D8) MemWrite con valid=0 no debe escribir
        do_store_word(32'h0000_0020, 32'hDEAD_BEEF);
        do_store_word_invalid_should_not_write(32'h0000_0020, 32'hABCD_EF01);
        do_load_word_and_check(32'h0000_0020, 5'd8, 32'hDEAD_BEEF);

        // D9) MemRead con valid=0 no debe "contar"
        do_load_invalid_should_not_count();

        // E10) Última palabra válida (DMEM=4KB => última addr=0xFFC)
        do_store_word(32'h0000_0FFC, 32'hCAFE_BABE);
        do_load_word_and_check(32'h0000_0FFC, 5'd9, 32'hCAFE_BABE);

        // E11) Fuera de rango (0x1000)
        do_store_word(32'h0000_1000, 32'h9999_AAAA);     // no debería escribir
        do_load_word_and_check(32'h0000_1000, 5'd10, 32'h0000_0000);

        $display("ALL TESTS PASSED ✅");
        $finish;
    end

endmodule
