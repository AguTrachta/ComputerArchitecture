module adder5 #(
    parameter W = 8
)(
    input  wire [W-1:0]     in_data,
    input  wire             rx_empty,
    input  wire             tx_full,
    output reg  [W-1:0]     out_data,
    output reg              f_rd,       // leer FIFO RX
    output reg              f_wr        // escribir FIFO TX
);

    always @(*) begin
        f_rd       = 0;
        f_wr       = 0;
        out_data = {W{1'b0}};
        if (!rx_empty && !tx_full) begin
            f_rd       = 1;
            f_wr       = 1;
            out_data = in_data + 5;
        end
    end
endmodule
