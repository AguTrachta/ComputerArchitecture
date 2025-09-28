`timescale 1ns / 1ps

module top #(
    parameter integer DBIT    = 8,    // bits de datos
    parameter integer SB_TICK = 16,   // ticks stop
    parameter integer FIFO_W  = 8,    // ancho FIFO
    parameter integer NB_DATA  = 16,   // profundidad FIFO
    parameter integer NB_OP   = 6,    // cantidad de bits operaciones
    parameter integer CLK_FREQ  = 100_000_000,
    parameter integer BAUD_RATE = 9600
)(
    input  wire       clk, reset,
    input  wire       rx,             // línea serie de entrada
    output wire       tx             // línea serie de salida
);

    // Señales de muestreo
    wire sample_tick;
    // Señales RX
    wire [FIFO_W-1:0] rx_dout;  // Bus receptor - fifo
    wire       rx_done_tick;
    // Señales TX
    wire [FIFO_W-1:0] tx_din;  // Bus fifo - transmisor
    wire       tx_start, tx_done_tick;
    // FIFO Interface
    wire       rd_uart;        // leer dato recibido
    wire [FIFO_W-1:0] r_data;         // dato leído
    wire       rx_empty;       // FIFO Rx vacía
    wire       wr_uart;        // escribir dato a transmitir
    wire       tx_full;        // FIFO Tx llena
    // ALU Interface
    wire [FIFO_W-1:0] data_a, data_b;
    wire [NB_OP-1:0] op;
    wire [FIFO_W-1:0] alu_result;

    //-----------------------
    // Baud rate generator
    //-----------------------
    baud_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) baud_unit (
        .clk(clk),
        .reset(reset),
        .sample_tick(sample_tick)
    );

    //-----------------------
    // UART Receiver + FIFO
    //-----------------------
    uart_rx #(.DBIT(DBIT), .SB_TICK(SB_TICK)) rx_unit (
        .clk(clk), .reset(reset),
        .rx(rx),
        .sample_tick(sample_tick),
        .rx_done_tick(rx_done_tick),
        .dout(rx_dout)
    );

    fifo #(.W(FIFO_W), .N(NB_DATA)) fifo_rx (
        .clk(clk), .reset(reset),
        .wr(rx_done_tick),       // escribir en FIFO cuando llega dato
        .rd(rd_uart),            // leer nuevo cuando interfaz está lista
        .w_data(rx_dout),
        .r_data(r_data),     // dato leído por sistema                              //
        .full(),                 // no usamos "full" en RX
        .empty(rx_empty)         // indica si FIFO está vacía
    );

    //-----------------------
    // UART Transmitter + FIFO
    //-----------------------
    fifo #(.W(FIFO_W), .N(NB_DATA)) fifo_tx (
        .clk(clk), .reset(reset),
        .wr(wr_uart),            // sistema escribe dato a enviar                   //
        .rd(tx_done_tick),       // UART Tx lee cuando termina
        .w_data(alu_result),     // Resultado directo de la alu
        .r_data(tx_din),
        .full(tx_full),          // FIFO llena → no se puede escribir
        .empty(tx_empty)         // señal interna
    );

    assign tx_start = ~tx_empty;  // UART Tx arranca si FIFO no vacía

    uart_tx #(.DBIT(DBIT), .SB_TICK(SB_TICK)) tx_unit (
        .clk(clk), .reset(reset),
        .tx_start(tx_start),
        .sample_tick(sample_tick),
        .din(tx_din),
        .tx_done_tick(tx_done_tick),
        .tx(tx)
    );

    //-----------------------
    // ALU
    //-----------------------
    alu alu_inst (
        .i_data_a(data_a),
        .i_data_b(data_b),
        .i_op(op),
        .o_result(alu_result)
    );

    //-----------------------
    // ALU Interface
    //-----------------------
    interface #(.FIFO_W(FIFO_W)) iface_inst (
        .clk(clk), .reset(reset),
        .rd_uart(rd_uart),
        .r_data(r_data),
        .rx_empty(rx_empty),
        .wr_uart(wr_uart),
        .tx_full(tx_full),
        .o_data_a(data_a),
        .o_data_b(data_b),
        .o_op(op)
    );

endmodule

