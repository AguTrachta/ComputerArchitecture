`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.09.2025 23:38:08
// Design Name: 
// Module Name: sevenseg_hex
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


module sevenseg_hex(
    input  wire        i_clk,     // 100 MHz Basys3
    input  wire        i_rst,
    input  wire [15:0] i_value,   // 4 nibbles (HEX)
    output wire  [6:0]  o_seg,     // a..g (low active)
    output wire         o_dp,      // punto (low active)
    output reg  [3:0]  o_an       // anodos (low active)
    );
    
    reg [15:0] div;
    always @(posedge i_clk or posedge i_rst)
        if (i_rst) 
            div <= 0; 
        else 
            div <= div + 1'b1;
    
    wire [1:0] sel = div[15:14];
    
    reg [3:0] nibble;
    always @* begin
        case (sel)
            2'd0: nibble = i_value[3:0];
            2'd1: nibble = i_value[7:4];
            2'd2: nibble = i_value[11:8];
            2'd3: nibble = i_value[15:12];
        endcase
    end
    
        hex_to_sseg u_hex2seg (
        .hex  (nibble),
        .sseg (o_seg)
    );

    assign o_dp = 1'b1;

    always @* begin
        o_an = 4'b1111;
        o_an[sel] = 1'b0;  
    end
endmodule
