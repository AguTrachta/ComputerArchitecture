`timescale 1ns/1ps

module tb_top;

    localparam BAUD_RATE  = 19200;
    localparam BIT_PERIOD = (1_000_000_000 / BAUD_RATE); // ns

    reg clk, reset;
    reg rx;
    wire tx;

    // DUT: el sistema completo UART + ALU
    system_top dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx),
        .o_led_res()  // podés mirar el resultado en LEDs en HW, aquí lo ignoramos
    );

    // Clock 50 MHz
    initial begin
        clk = 0;
        forever #(10) clk = ~clk;
    end

    // Dump para GTKWave
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);
    end


    // --- Tarea: enviar operación y verificar resultado ---
    task run_alu_test;
        input [7:0] a, b;
        input [5:0] op;
        input [7:0] expected;
        reg   [7:0] result;
        begin
            $display(">>> PC manda op=%b A=%h B=%h", op, a, b);

            fork
                begin
                    uart_send_byte({2'b00, op});  // 6 bits de op en byte
                    uart_send_byte(a);
                    uart_send_byte(b);
                end
                begin
                    // Capturar resultado
                    uart_capture_byte(result);
                end
            join

            // Verificación
            if (result !== expected)
                $error("ERROR: op=%b A=%h B=%h -> Recibido=%h, Esperado=%h",
                        op, a, b, result, expected);
            else
                $display("OK: Resultado correcto %h", result);

            #(2000);  // espera entre tests
        end
    endtask

    // --- Tarea: enviar byte a FPGA (PC → RX)
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            rx = 0; #(BIT_PERIOD);              // start
            for (i=0; i<8; i=i+1) begin
                rx = data[i];
                #(BIT_PERIOD);
            end
            rx = 1; #(BIT_PERIOD);              // stop
        end
    endtask


    task uart_capture_byte;
        output [7:0] data;
        integer i;
        begin
            @(negedge tx); #(BIT_PERIOD/2);
            for (i=0; i<8; i=i+1) begin
                #(BIT_PERIOD);
                data[i] = tx;
            end
            #(BIT_PERIOD); // stop
            $display(">>> PC recibe desde TX: %h", data);
        end
    endtask

    initial begin
        reset = 1; rx = 1;
        #(200); reset = 0;

        // Pruebas
        run_alu_test(8'h05, 8'h03, 6'b100000, 8'h08); // ADD
        run_alu_test(8'h07, 8'h02, 6'b100010, 8'h05); // SUB
        run_alu_test(8'h0F, 8'hF0, 6'b100100, 8'h00); // AND
        run_alu_test(8'h0F, 8'hF0, 6'b100101, 8'hFF); // OR
        run_alu_test(8'h55, 8'hFF, 6'b100110, 8'hAA); // XOR
        run_alu_test(8'h80, 8'h01, 6'b000011, 8'hC0); // SRA (signed)
        run_alu_test(8'h80, 8'h01, 6'b000010, 8'h40); // SRL
        run_alu_test(8'h0F, 8'hF0, 6'b100111, 8'h00); // NOR
        $display(">>> Todas las pruebas completadas");
        $stop;
    end


endmodule
