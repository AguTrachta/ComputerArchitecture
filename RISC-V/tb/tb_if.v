`timescale 1ns/1ps

module tb_if;

    reg clk=0, reset=1;

    always #5 clk = ~clk;

    top_if dut (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        $display("=== IF STAGE TEST ===");

        repeat(2) @(posedge clk);
        reset = 0;

        repeat(10) begin
            @(posedge clk);
            $display(
                "PC=%h | PC+4=%h | INSTR=%h | LATCH_PC=%h | VALID=%b",
                dut.if_s.if_pc,
                dut.if_s.if_pc_plus4,
                dut.if_s.if_instr,
                dut.latch.id_pc,
                dut.latch.id_valid
            );
        end
        
        $finish;
    end
endmodule
