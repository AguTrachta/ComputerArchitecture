module interface #(
    parameter FIFO_W = 8,
    parameter NB_OP  = 6
) (
    input  wire clk, reset,

        // Conexión a FIFO RX
    input  wire [FIFO_W-1:0] r_data,   // Datos del FIFO RX
    input  wire              rx_empty, // Flag FIFO RX vacía
    output reg               rd_uart,  // Señal para leer dato del FIFO RX

    // Conexión a FIFO TX
    input  wire              tx_full,  // Flag FIFO TX llena
    output reg               wr_uart,  // Señal para escribir dato al FIFO TX

    // Conexión a ALU
    output wire [FIFO_W-1:0] o_data_a, // Salida interfaz - alu data a y b
    output wire [FIFO_W-1:0] o_data_b,
    output wire [NB_OP-1:0]  o_op      // Salida interfaz - alu op
);

    // ALU interface
    reg  [FIFO_W-1:0] data_a, data_b;
    reg  [NB_OP-1:0] op;

    // Control simple: máquina de estados para recibir 3 bytes
    localparam S_IDLE = 0, S_OP = 1, S_A = 2, S_B = 3, S_SEND = 4;
    reg [2:0] state_reg, state_next;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state_reg <= S_IDLE;
        end else begin
            state_reg <= state_next;
        end
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
            
            default: state_next = S_IDLE;
            
        endcase
    end

    // Guardar datos cuando leo
    always @(posedge clk) begin
        if(reset) begin
            data_a    <= {FIFO_W{1'b0}};
            data_b    <= {FIFO_W{1'b0}};
            op        <= {NB_OP{1'b0}};
        end
        if (!rx_empty && state_reg == S_OP) op     <= r_data[NB_OP-1:0];
        if (!rx_empty && state_reg == S_A)  data_a <= r_data;
        if (!rx_empty && state_reg == S_B)  data_b <= r_data;
    end

    // Conectar salidas
    assign o_data_a   = data_a;
    assign o_data_b   = data_b;
    assign o_op       = op;
    
endmodule
