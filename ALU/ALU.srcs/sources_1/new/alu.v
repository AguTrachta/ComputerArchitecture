//  ADD     100000
//  SUB     100010
//  AND     100100
//  OR      100101
//  XOR     100110
//  SRA     000011
//  SRL     000010
//  NOR     100111

module alu
#(
    parameter NB_DATA = 8,  // Cantidad de bits de datos
    parameter NB_OP   = 6   // Cantidad de bits para el operador
)
(
    input  wire signed  [NB_DATA - 1 : 0] i_data_a,
    input  wire signed  [NB_DATA - 1 : 0] i_data_b,
    input  wire         [NB_OP   - 1 : 0] i_op    ,
    output wire signed  [NB_DATA - 1 : 0] o_result
);

    localparam ADD = 6'b100000;
    localparam SUB = 6'b100010;
    localparam AND = 6'b100100;
    localparam OR  = 6'b100101;
    localparam XOR = 6'b100110;
    localparam SRA = 6'b000011; // Right Shift
    localparam SRL = 6'b000010; // Logic Right Shift
    localparam NOR = 6'b100111;

    reg signed [NB_DATA : 0] r_result;
    
    always @(*) begin
    
        case (i_op)
            ADD     : r_result = i_data_a + i_data_b;
            SUB     : r_result = i_data_a - i_data_b;
            AND     : r_result = i_data_a & i_data_b;
            OR      : r_result = i_data_a | i_data_b;
            XOR     : r_result = i_data_a ^ i_data_b;
            SRA     : r_result = i_data_a >>> i_data_b;
            SRL     : r_result = $unsigned(i_data_a) >> i_data_b[$clog2(NB_DATA)-1:0];
            NOR     : r_result = ~(i_data_a | i_data_b);
            
            default : r_result = {NB_DATA{1'b0}}; // All 0
        endcase
    
    end
    
    assign o_result = r_result;

endmodule