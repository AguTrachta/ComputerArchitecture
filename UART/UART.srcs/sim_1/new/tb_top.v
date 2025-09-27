`timescale 1ns / 1ps

module tb_top;

    // Parámetros del DUT
    localparam CLK_FREQ  = 50000000;
    localparam BAUD_RATE = 19200;
    localparam BIT_PERIOD = (1_000_000_000 / BAUD_RATE); // en ns, un bit UART dura ~52us

    // Señales
    reg clk, reset;
    reg rx;
    wire tx;

    // Interfaz con el sistema
    reg        rd_uart, wr_uart;
    reg  [7:0] w_data;
    wire [7:0] r_data;
    wire       rx_empty, tx_full;

    // DUT
    uart_top #(
        .DBIT(8),
        .SB_TICK(16),
        .FIFO_W(8),
        .FIFO_N(16)
    ) dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx),
        .rd_uart(rd_uart),
        .r_data(r_data),
        .rx_empty(rx_empty),
        .wr_uart(wr_uart),
        .w_data(w_data),
        .tx_full(tx_full)
    );

    //-------------------------------
    // Generador de clock
    //-------------------------------
    initial begin
        clk = 0;
        forever #(10) clk = ~clk;  // 50 MHz => periodo 20ns
    end

    //-------------------------------
    // Tareas útiles para simular
    //-------------------------------

    // Enviar un byte serial por la línea RX (LSB primero, formato 8N1)
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            rx = 0;
            #(BIT_PERIOD);
            // Data bits
            for (i=0; i<8; i=i+1) begin
                rx = data[i];
                #(BIT_PERIOD);
            end
            // Stop bit
            rx = 1;
            #(BIT_PERIOD);
        end
    endtask

    // Recibir un byte desde TX (captura la línea tx)
    task uart_capture_byte;
        integer i;
        reg [7:0] data;
        begin
            // Espera start
            @(negedge tx);  // start bit = 0
            #(BIT_PERIOD/2); // mitad del start

            // Captura 8 bits
            for (i=0; i<8; i=i+1) begin
                #(BIT_PERIOD);
                data[i] = tx;
            end

            // Espera stop
            #(BIT_PERIOD);

            $display("Byte recibido en TX = %h", data);
        end
    endtask

    //-------------------------------
    // Estímulos
    //-------------------------------
    initial begin
        // Inicialización
        reset   = 1;
        rx      = 1;  // línea inactiva en reposo
        rd_uart = 0;
        wr_uart = 0;
        w_data  = 0;

        #(100);
        reset = 0;

        // Simulación: Enviar un byte desde la "PC" a la FPGA
        #(1000);
        $display(">>> PC manda 0xA5 por RX");
        uart_send_byte(8'hA5);

        // Espera a que UART lo meta en FIFO
        #(20*BIT_PERIOD);

        // Leer dato recibido de FIFO RX
        if (!rx_empty) begin
            rd_uart = 1;
            #(20);
            rd_uart = 0;
            $display(">>> FPGA recibió byte: %h", r_data);
        end

        // Simulación: Mandar un byte desde FPGA a PC
        #(1000);
        $display(">>> FPGA manda 0x3C por TX");
        w_data  = 8'h3C;
        wr_uart = 1;
        #(20);
        wr_uart = 0;

        // Capturamos el byte de la línea TX
        uart_capture_byte();

        #(1000);
        $stop;
    end

endmodule

