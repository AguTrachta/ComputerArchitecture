`timescale 1ns / 1ps

module uart_rx #(
    parameter DBIT = 8,          // número de bits de datos
    parameter SB_TICK = 16       // ticks para stop bit (16=1 stop, 24=1.5, 32=2)
)(
    input  wire       clk, reset,
    input  wire       rx,
    input  wire       sample_tick,
    output reg        rx_done_tick,
    output wire [7:0] dout
);

    // Estados
    localparam [1:0]
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11;

    reg [1:0] state_reg, state_next;
    reg [3:0] tick_count_reg, tick_count_next; 
    reg [2:0] bit_count_reg, bit_count_next;  
    reg [7:0] rx_shift_reg, rx_shift_next;    

    // Registros de estado
    always @(posedge clk)
        if (reset) begin
            state_reg      <= IDLE;
            tick_count_reg <= 0;
            bit_count_reg  <= 0;
            rx_shift_reg   <= 0;
        end else begin
            state_reg      <= state_next;
            tick_count_reg <= tick_count_next;
            bit_count_reg  <= bit_count_next;
            rx_shift_reg   <= rx_shift_next;
        end

    // FSM + datapath
    always @* begin
        state_next      = state_reg;
        tick_count_next = tick_count_reg;
        bit_count_next  = bit_count_reg;
        rx_shift_next   = rx_shift_reg;
        rx_done_tick    = 1'b0;

        case (state_reg)
            IDLE: 
                if (~rx) begin
                    state_next      = START;
                    tick_count_next = 0;
                end
            START: 
                if (sample_tick)
                    if (tick_count_reg == 7) begin
                        state_next      = DATA;
                        tick_count_next = 0;
                        bit_count_next  = 0;
                    end else
                        tick_count_next = tick_count_reg + 1;
            DATA:
                if (sample_tick)
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        rx_shift_next   = {rx, rx_shift_reg[7:1]};
                        if (bit_count_reg == (DBIT-1))
                            state_next = STOP;
                        else
                            bit_count_next = bit_count_reg + 1;
                    end else
                        tick_count_next = tick_count_reg + 1;
            STOP:
                if (sample_tick)
                    if (tick_count_reg == (SB_TICK-1)) begin
                        state_next      = IDLE;
                        rx_done_tick    = 1'b1;
                    end else
                        tick_count_next = tick_count_reg + 1;
        endcase
    end

    assign dout = rx_shift_reg;

endmodule
