`timescale 1ns / 1ps

module uart_top #(
    parameter DBIT    = 8,    // bits de datos
    parameter SB_TICK = 16,   // ticks stop
    parameter FIFO_W  = 8,    // ancho FIFO
    parameter FIFO_N  = 16    // profundidad FIFO
)(
    input  wire       clk, reset,
    input  wire       rx,             // línea serie de entrada
    output wire       tx,             // línea serie de salida
    // Interfaz con sistema (lado usuario)
    input  wire       rd_uart,        // leer dato recibido
    output wire [7:0] r_data,         // dato leído
    output wire       rx_empty,       // FIFO Rx vacía
    input  wire       wr_uart,        // escribir dato a transmitir
    input  wire [7:0] w_data,         // dato a transmitir
    output wire       tx_full         // FIFO Tx llena
);

    wire sample_tick;
    // Señales RX
    wire [7:0] rx_dout;
    wire       rx_done_tick;
    // Señales TX
    wire [7:0] tx_din;
    wire       tx_start, tx_done_tick;

    //-----------------------
    // Baud rate generator
    //-----------------------
    baud_gen baud_unit (
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

    fifo #(.W(FIFO_W), .N(FIFO_N)) fifo_rx (
        .clk(clk), .reset(reset),
        .wr(rx_done_tick),       // escribir en FIFO cuando llega dato
        .rd(rd_uart),            // leer cuando sistema lo pide
        .w_data(rx_dout),
        .r_data(r_data),
        .full(),                 // no usamos "full" en RX
        .empty(rx_empty)         // indica si FIFO está vacía
    );

    //-----------------------
    // UART Transmitter + FIFO
    //-----------------------
    fifo #(.W(FIFO_W), .N(FIFO_N)) fifo_tx (
        .clk(clk), .reset(reset),
        .wr(wr_uart),            // sistema escribe dato a enviar
        .rd(tx_done_tick),       // UART Tx lee cuando termina
        .w_data(w_data),
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

endmodule

