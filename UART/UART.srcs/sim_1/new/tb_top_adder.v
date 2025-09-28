`timescale 1ns / 1ps

module tb_top_adder;

    // Parámetros del DUT
    localparam CLK_FREQ   = 50000000;
    localparam BAUD_RATE  = 9600;
    localparam BIT_PERIOD = (1_000_000_000 / BAUD_RATE); // ns por bit UART (~52 us a 19200)

    // Señales
    reg clk, reset;
    reg rx;
    wire tx;

    // DUT
    uart_top #(
        .DBIT(8),
        .SB_TICK(16),
        .FIFO_W(8),
        .FIFO_N(16),
        .BAUD_RATE(BAUD_RATE),
        .CLK_FREQ(CLK_FREQ)
    ) dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx)
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
    
        $dumpfile("tb_top_adder.vcd");   // archivo de dump
        $dumpvars(0, tb_top_adder);

        // Inicialización
        reset = 1;
        rx    = 1;  // línea idle en reposo

        #(100);
        reset = 0;

        // Simulación 1: Enviar un byte desde la "PC" a la FPGA
        #(1000);
        $display(">>> PC manda 0xA5 por RX");
        uart_send_byte(8'hA5);
        //#(20*BIT_PERIOD);
        uart_capture_byte();

        // Simulación 2: otro byte
        #(5000);
        $display(">>> PC manda 0x10 por RX");
        uart_send_byte(8'h10);
        //#(20*BIT_PERIOD);
        uart_capture_byte();

        // Simulación 3: otro byte
        #(5000);
        $display(">>> PC manda 0xFF por RX");
        uart_send_byte(8'hFF);
        //#(20*BIT_PERIOD);
        uart_capture_byte();

        #(10000);
        $stop;
    end
    
endmodule
