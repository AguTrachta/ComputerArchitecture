`timescale 1ns / 1ps

module tb_core_m0;

    reg clk = 0;
    reg reset = 1;

    // Clock
    always #5 clk = ~clk;

    // Instancia del core
    core_m0 dut (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        $display("=== CORE M0 Simulation Start ===");

        // Reset activo un par de ciclos
        @(posedge clk);
        @(posedge clk);
        reset = 0;

        // Correr 20 ciclos
        repeat(20) begin
            @(posedge clk);
            $display("PC = 0x%08h   instr = 0x%08h", dut.pc, dut.instr);
        end

        $finish;
    end

endmodule
