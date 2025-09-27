module system_top (
    input  wire clk, reset,
    input  wire rx,            // UART RX (desde PC)
    output wire tx,            // UART TX (hacia PC)
    output wire [7:0] o_led_res
);

    // UART interface
    wire [7:0] r_data;
    wire       rx_empty;
    reg        rd_uart;
    wire [7:0] w_data;
    reg        wr_uart;
    wire       tx_full;

    // ALU interface
    reg  [7:0] data_a, data_b;
    reg  [5:0] op;
    wire [7:0] alu_result;

    // UART full-duplex con FIFO
    uart_top #(
        .DBIT(8),
        .SB_TICK(16),
        .FIFO_W(8),
        .FIFO_N(16)
    ) uart_inst (
        .clk(clk), .reset(reset),
        .rx(rx), .tx(tx),
        .rd_uart(rd_uart),
        .r_data(r_data),
        .rx_empty(rx_empty),
        .wr_uart(wr_uart),
        .w_data(w_data),
        .tx_full(tx_full)
    );

    // ALU
    alu alu_inst (
        .i_data_a(data_a),
        .i_data_b(data_b),
        .i_op(op),
        .o_result(alu_result)
    );

    // Control simple: máquina de estados para recibir 3 bytes
    localparam S_IDLE = 0, S_OP = 1, S_A = 2, S_B = 3, S_SEND = 4;
    reg [2:0] state_reg, state_next;

    always @(posedge clk, posedge reset) begin
        if (reset)
            state_reg <= S_IDLE;
        else
            state_reg <= state_next;
    end

    always @* begin
        state_next = state_reg;
        rd_uart    = 0;
        wr_uart    = 0;

        case (state_reg)
            S_IDLE: if (!rx_empty) state_next = S_OP;

            S_OP: if (!rx_empty) begin
                rd_uart = 1;
                state_next = S_A;
            end

            S_A: if (!rx_empty) begin
                rd_uart = 1;
                state_next = S_B;
            end

            S_B: if (!rx_empty) begin
                rd_uart = 1;
                state_next = S_SEND;
            end

            S_SEND: if (!tx_full) begin
                wr_uart = 1;
                state_next = S_IDLE;
            end
        endcase
    end

    // Guardar datos cuando leo
    always @(posedge clk) begin
        if (!rx_empty && state_reg == S_OP) op     <= r_data[5:0];
        if (!rx_empty && state_reg == S_A)  data_a <= r_data;
        if (!rx_empty && state_reg == S_B)  data_b <= r_data;
    end

    // Dato a enviar = resultado de la ALU
    assign w_data    = alu_result;
    assign o_led_res = alu_result;  // también en LEDs
endmodule
