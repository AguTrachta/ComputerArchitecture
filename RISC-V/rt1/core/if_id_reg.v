module if_id_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,
    input  wire        flush,

    input  wire [31:0] if_pc,
    input  wire [31:0] if_pc_plus4,
    input  wire [31:0] if_instr,

    output reg  [31:0] id_pc,
    output reg  [31:0] id_pc_plus4,
    output reg  [31:0] id_instr,
    output reg         id_valid
);

    always @(posedge clk) begin
        if (reset || flush) begin
            id_pc        <= 32'b0;
            id_pc_plus4  <= 32'b0;
            id_instr     <= 32'b0;
            id_valid     <= 1'b0;
        end
        else if (!stall) begin // Si no hay Stall, los datos se copian, si no mantiene lo que ya habia
            id_pc        <= if_pc;
            id_pc_plus4  <= if_pc_plus4;
            id_instr     <= if_instr;
            id_valid     <= 1'b1;
        end
    end

endmodule
