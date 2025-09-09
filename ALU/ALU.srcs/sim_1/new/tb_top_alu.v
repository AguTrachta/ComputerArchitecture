`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/08/2025 11:54:37 PM
// Design Name: 
// Module Name: tb_top_alu
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


module tb_top_alu;

    localparam NB_DATA = 8;
    localparam NB_OP   = 6;

    reg  clk=0, rst=0;
    reg  btn_a=0, btn_b=0, btn_op=0;
    reg  [NB_DATA-1:0] sw=0;
    wire [NB_DATA-1:0] led_res, led_now;
    
    top #(.NB_DATA(NB_DATA), .NB_OP(NB_OP)) dut (
        .i_clk(clk), .i_rst(rst),
        .i_btn_a(btn_a), .i_btn_b(btn_b), .i_btn_op(btn_op),
        .i_sw_data(sw),
        .o_led_res(led_res),
        .o_led_now(led_now)
    );
    
    
    
    always #5 clk = ~clk;



    task load_A(input [NB_DATA-1:0] v); begin
        sw=v; @(posedge clk); btn_a=1; @(posedge clk); btn_a=0;
    end endtask

    task load_B(input [NB_DATA-1:0] v); begin
        sw=v; @(posedge clk); btn_b=1; @(posedge clk); btn_b=0;
    end endtask

    task load_OP(input [NB_OP-1:0] v); begin
        sw={{(NB_DATA-NB_OP){1'b0}}, v}; @(posedge clk); btn_op=1; @(posedge clk); btn_op=0;
    end endtask
    
    
    
    initial begin
        // reset
        rst=1; 
        #5;
        rst=0;

        // A = -5 (0xFB), B = 3
        load_A($signed(-5));
        load_B(8'd3);

        // ADD
        load_OP(6'b100000);  // ADD
        repeat(2) @(posedge clk);

        // SUB
        load_OP(6'b100010);  // SUB
        repeat(2) @(posedge clk);

        // SRA: A >>> 1
        load_B(8'd1);
        load_OP(6'b000011);  // SRA
        repeat(2) @(posedge clk);

        // SRL: A >> 1 (lógico)
        load_OP(6'b000010);  // SRL
        repeat(2) @(posedge clk);

        // NOR
        load_OP(6'b100111);
        repeat(2) @(posedge clk);

        $stop;
    end
    
endmodule
