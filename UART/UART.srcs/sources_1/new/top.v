`timescale 1ns / 1ps

module uart_top #(
    parameter integer DBIT      = 8,           // bits de datos
    parameter integer SB_TICK   = 16,          // ticks stop
    parameter integer FIFO_W    = 8,           // ancho FIFO
    parameter integer FIFO_N    = 16,          // profundidad FIFO
    parameter integer BAUD_RATE = 9600,        // 
    parameter integer CLK_FREQ  = 100_000_000, //
    parameter integer DIVISOR = CLK_FREQ / (BAUD_RATE * 16)
)(
    input  wire       clk, reset,
    input  wire       rx,             // línea serie de entrada
    output wire       tx             // línea serie de salida
);

    wire sample_tick;
    // Señales RX
    wire [7:0] rx_dout;
    wire       rx_done_tick;
    // Señales TX
    wire [7:0] tx_din;
    wire       tx_start, tx_done_tick;

    // ADDER
    wire [7:0] fifo_rx_out;  // salida directa de la FIFO
    wire       adder_wr;  // write/valid del adder
    wire       adder_rd;
    wire [7:0] adder_out;
    wire rx_empty;
    wire tx_full;
    wire tx_empty;

    //-----------------------
    // Baud rate generator
    //-----------------------
    baud_gen #(
        .DIVISOR(DIVISOR)
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

    fifo #(.W(FIFO_W), .N(FIFO_N)) fifo_rx (
        .clk(clk), .reset(reset),
        .wr(rx_done_tick),       // escribir en FIFO cuando llega dato
        .rd(adder_rd),            // leer cuando sistema lo pide
        .w_data(rx_dout),
        .r_data(fifo_rx_out),    // <-- sale hacia el adder
        .full(),                 // no usamos "full" en RX
        .empty(rx_empty)         // indica si FIFO está vacía
    );


    //-----------------------
    // UART Transmitter + FIFO
    //-----------------------
    fifo #(.W(FIFO_W), .N(FIFO_N)) fifo_tx (
        .clk(clk), .reset(reset),
        .wr(adder_wr),            // sistema escribe dato a enviar
        .rd(tx_done_tick),       // UART Tx lee cuando termina
        .w_data(adder_out),
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

    // Adder
    adder5 #(.W(FIFO_W)) adder_inst (
        .in_data(fifo_rx_out),
        .rx_empty(rx_empty),
        .tx_full(tx_full),
        .out_data(adder_out),
        .f_rd(adder_rd),
        .f_wr(adder_wr)
    );
    
    //assign r_data = adder_out;

endmodule

