`timescale 1ns / 1ps

module uart_tx #(
    parameter DBIT = 8,
    parameter SB_TICK = 16
)(
    input  wire       clk, reset,
    input  wire       tx_start, sample_tick,
    input  wire [7:0] din,
    output reg        tx_done_tick,
    output wire       tx
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
    reg [7:0] tx_shift_reg, tx_shift_next;
    reg       tx_reg, tx_next;

    // Estado
    always @(posedge clk)
        if (reset) begin
            state_reg      <= IDLE;
            tick_count_reg <= 0;
            bit_count_reg  <= 0;
            tx_shift_reg   <= 0;
            tx_reg         <= 1'b1;
        end else begin
            state_reg      <= state_next;
            tick_count_reg <= tick_count_next;
            bit_count_reg  <= bit_count_next;
            tx_shift_reg   <= tx_shift_next;
            tx_reg         <= tx_next;
        end

    // FSM + datapath
    always @* begin
        state_next      = state_reg;
        tick_count_next = tick_count_reg;
        bit_count_next  = bit_count_reg;
        tx_shift_next   = tx_shift_reg;
        tx_next         = tx_reg;
        tx_done_tick    = 1'b0;

        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;
                if (tx_start) begin
                    state_next      = START;
                    tick_count_next = 0;
                    tx_shift_next   = din;
                end
            end
            START: begin
                tx_next = 1'b0;
                if (sample_tick)
                    if (tick_count_reg == 15) begin
                        state_next      = DATA;
                        tick_count_next = 0;
                        bit_count_next  = 0;
                    end else
                        tick_count_next = tick_count_reg + 1;
            end
            DATA: begin
                tx_next = tx_shift_reg[0];
                if (sample_tick)
                    if (tick_count_reg == 15) begin
                        tick_count_next = 0;
                        tx_shift_next   = tx_shift_reg >> 1;
                        if (bit_count_reg == (DBIT-1))
                            state_next = STOP;
                        else
                            bit_count_next = bit_count_reg + 1;
                    end else
                        tick_count_next = tick_count_reg + 1;
            end
            STOP: begin
                tx_next = 1'b1;
                if (sample_tick)
                    if (tick_count_reg == (SB_TICK-1)) begin
                        state_next   = IDLE;
                        tx_done_tick = 1'b1;
                    end else
                        tick_count_next = tick_count_reg + 1;
            end
        endcase
    end

    assign tx = tx_reg;

endmodule
