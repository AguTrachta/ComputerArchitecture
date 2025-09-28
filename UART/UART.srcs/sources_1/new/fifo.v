`timescale 1ns / 1ps

module fifo #(
    parameter W = 8,   // ancho de palabra
    parameter N = 16   // cantidad de palabras
)(
    input  wire         clk, reset,
    input  wire         wr, rd,
    input  wire [W-1:0] w_data,
    output wire [W-1:0] r_data,
    output wire         full, empty
);

    // Calcular cantidad de bits para punteros
    localparam ADDR_W = $clog2(N);

    // Memoria interna
    reg [W-1:0] array_reg [0:N-1];

    // Punteros y contador de elementos
    reg [ADDR_W-1:0] w_ptr_reg, w_ptr_next;
    reg [ADDR_W-1:0] r_ptr_reg, r_ptr_next;
    reg [ADDR_W:0]   count_reg, count_next;  // hasta N

    // Escritura síncrona
    always @(posedge clk) begin
        if (wr && !full)
            array_reg[w_ptr_reg] <= w_data;
    end

    // Registros de estado
    always @(posedge clk) begin
        if (reset) begin
            w_ptr_reg <= 0;
            r_ptr_reg <= 0;
            count_reg <= 0;
        end else begin
            w_ptr_reg <= w_ptr_next;
            r_ptr_reg <= r_ptr_next;
            count_reg <= count_next;
        end
    end

    // Lógica siguiente estado
    always @* begin
        w_ptr_next = w_ptr_reg;
        r_ptr_next = r_ptr_reg;
        count_next = count_reg;

        case ({wr && !full, rd && !empty})
            2'b01: begin // solo leer
                r_ptr_next = r_ptr_reg + 1;
                count_next = count_reg - 1;
            end
            2'b10: begin // solo escribir
                w_ptr_next = w_ptr_reg + 1;
                count_next = count_reg + 1;
            end
            2'b11: begin // leer y escribir simultáneamente
                w_ptr_next = w_ptr_reg + 1;
                r_ptr_next = r_ptr_reg + 1;
                // count no cambia
            end
            2'b00: begin
                // nada
            end
        endcase
    end

    // Salidas
    assign full  = (count_reg == N);
    assign empty = (count_reg == 0);
    assign r_data = array_reg[r_ptr_reg];

endmodule
