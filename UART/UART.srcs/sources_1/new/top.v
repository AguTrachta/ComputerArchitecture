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
    wire [NB_OP-1:0] op;
    wire [FIFO_W-1:0] alu_result;
    // --- Regfile 32x8 ---
    wire [7:0] rf_rdata1, rf_rdata2, rf_wdata;
    wire       rf_we;
    wire [4:0] rf_waddr, rf_raddr1, rf_raddr2;

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

    // -----------------------
    // ALU con soporte R e I-type
    // -----------------------
    
    // Señales internas para I-type (vienen del rv_interface / decoder)
    wire signed [11:0] imm_i;
    wire               is_itype;
    
    // Accedemos jerárquicamente al decoder dentro del rv_interface
    assign imm_i    = iface_inst.dec_i.imm_i;     // inmediato de 12 bits
    assign is_itype = iface_inst.dec_i.is_itype;  // flag de tipo I
    
    // Multiplexor: elige si usar registro rs2 o inmediato
    wire [FIFO_W-1:0] alu_src_b = is_itype ? imm_i[7:0] : rf_rdata2;
    
    alu alu_inst (
        .i_data_a(rf_rdata1),
        .i_data_b(alu_src_b),
        .i_op(op),
        .o_result(alu_result)
    );

    // -----------------------
    // ALU Interface (nueva)
    // -----------------------
    rv_interface #(.FIFO_W(FIFO_W), .NB_OP(NB_OP)) iface_inst (
        .clk(clk), .reset(reset),

        // FIFO RX
        .r_data(r_data),
        .rx_empty(rx_empty),
        .rd_uart(rd_uart),

        // FIFO TX
        .tx_full(tx_full),
        .wr_uart(wr_uart),

        // Regfile
        .rf_we(rf_we),
        .rf_waddr(rf_waddr),
        .rf_wdata(rf_wdata),
        .rf_raddr1(rf_raddr1),
        .rf_raddr2(rf_raddr2),
        .rf_rdata1(rf_rdata1),
        .rf_rdata2(rf_rdata2),

        // ALU
        .o_op(op),
        .alu_result_in(alu_result)
    );

    // --- Regfile 32x8 ---
    regfile #(.DATA_W(FIFO_W), .NREGS(32)) rf0 (
        .clk(clk),
        .raddr1(rf_raddr1),
        .raddr2(rf_raddr2),
        .rdata1(rf_rdata1),
        .rdata2(rf_rdata2),
        .we(rf_we),
        .waddr(rf_waddr),
        .wdata(rf_wdata)
    );
endmodule

