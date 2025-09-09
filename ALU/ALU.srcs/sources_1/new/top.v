`timescale 1ns / 1ps

module top
#(
    parameter NB_DATA = 8,
    parameter NB_OP   = 6
)
(
    input  wire                   i_clk,
    input  wire                   i_rst,
    input  wire                   i_btn_a,
    input  wire                   i_btn_b,
    input  wire                   i_btn_op,
    input  wire [NB_DATA - 1 : 0] i_sw_data,
    output wire [NB_DATA - 1 : 0] o_led_res,
    output wire [NB_DATA - 1 : 0] o_led_now
    
);

    reg  signed [NB_DATA - 1 : 0] data_a; 
    reg  signed [NB_DATA - 1 : 0] data_b;
    reg         [NB_OP   - 1 : 0] op    ;
    wire signed [NB_DATA-1:0]     alu_result;
    
    alu #(
        .NB_DATA(NB_DATA),
        .NB_OP  (NB_OP)
    ) u_alu (
        .i_data_a (data_a),
        .i_data_b (data_b),
        .i_op     (op),
        .o_result (alu_result)
    );
    
    always@(posedge i_clk or posedge i_rst) begin
        
        if (i_rst) begin
            data_a <= 0;
            data_b <= 0;
            op     <= 0;
        end
        
        else begin
            if (i_btn_a ) data_a <= i_sw_data;
            if (i_btn_b ) data_b <= i_sw_data;
            if (i_btn_op) op     <= i_sw_data[NB_OP-1:0];
        end
    end
    
    assign o_led_now = i_sw_data;
    assign o_led_res = alu_result;

endmodule
