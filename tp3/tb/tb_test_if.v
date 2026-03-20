`timescale 1ns/1ps

module tb_test_if;

    reg clk=0, reset=1;
    reg stall=0, flush=0;

    always #5 clk = ~clk;

    // Instancia correcta del top
    top_if dut (
        .clk(clk),
        .reset(reset),
        .stall(stall),
        .flush(flush)
    );

    initial begin
        $display("=== TEST IF/ID con stall y flush ===");

        // Reset
        repeat(2) @(posedge clk);
        reset = 0;

        // Ciclos sin stall
        repeat(3) @(posedge clk);

        // Probamos stall
        $display("Activando STALL durante 3 ciclos");
        stall = 1;
        repeat(3) @(posedge clk);
        stall = 0;

        // Ciclos normales
        repeat(2) @(posedge clk);

        // Probamos flush
        $display("Activando FLUSH durante 1 ciclo");
        flush = 1;
        @(posedge clk);
        flush = 0;

        repeat(4) @(posedge clk);

        $finish;
    end

endmodule
