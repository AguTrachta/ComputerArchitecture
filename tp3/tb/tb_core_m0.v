// tb/tb_core_m0.sv
`timescale 1ns / 1ps

module tb_core_m0;

    logic clk = 0, reset = 1;

    always #5 clk = ~clk;

    core_m0 dut(.clk(clk), .reset(reset));

    initial begin
        $display("=== CORE M0 Simulation Start ===");

        // reset
        repeat(2) @(posedge clk);
        reset = 0;

        // correr 20 ciclos
        repeat(20) begin
            @(posedge clk);
            $display("PC = 0x%08h  instr=0x%08h", dut.pc, dut.instr);
        end

        $finish;
    end

endmodule
