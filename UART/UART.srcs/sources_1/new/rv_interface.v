// rv_interface.v - recibe 4 bytes (LSB-first), decodifica R-type, ejecuta ALU, WB y TX
module rv_interface #(
    parameter FIFO_W = 8,
    parameter NB_OP  = 6
)(
    input  wire clk, reset,

    // FIFO RX
    input  wire [FIFO_W-1:0] r_data,
    input  wire              rx_empty,
    output reg               rd_uart,

    // FIFO TX
    input  wire              tx_full,
    output reg               wr_uart,

    // Regfile
    output reg               rf_we,
    output reg  [4:0]        rf_waddr,
    output reg  [FIFO_W-1:0] rf_wdata,
    output reg  [4:0]        rf_raddr1,
    output reg  [4:0]        rf_raddr2,
    input  wire [FIFO_W-1:0] rf_rdata1,
    input  wire [FIFO_W-1:0] rf_rdata2,

    // ALU
    output wire [NB_OP-1:0]  o_op,
    input  wire [FIFO_W-1:0] alu_result_in
);
    // === Registros internos ===
    reg [31:0] instr;
    reg [2:0]  state, state_n;

    // === Decoder R-type ===
    wire [4:0] rs1, rs2, rd;
    wire       is_rtype;
    wire [NB_OP-1:0] alu_op;

    rv_decoder #(.NB_OP(NB_OP)) dec_i (
        .instr(instr),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .alu_op(alu_op),
        .is_rtype(is_rtype)
    );

    assign o_op = alu_op;

    // === FSM states ===
    localparam S_IDLE = 3'd0,
               S_I0   = 3'd1,
               S_I1   = 3'd2,
               S_I2   = 3'd3,
               S_I3   = 3'd4,
               S_EX   = 3'd5,
               S_WB   = 3'd6,
               S_TX   = 3'd7;

    // ===============================
    // 1) Registros de estado de la FSM
    // ===============================
    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= state_n;
        end
    end

    // =====================================================
    // 2) *** ACÁ VA EL BLOQUE QUE ARMA instr CON 4 BYTES ***
    //     Captura LSB-first: byte0->[7:0] ... byte3->[31:24]
    // =====================================================
    always @(posedge clk) begin
        if (reset) begin
            instr <= 32'd0;
        end else begin
            case (state)
                S_I0: if (!rx_empty && rd_uart) instr[7:0]    <= r_data;   // byte 0
                S_I1: if (!rx_empty && rd_uart) instr[15:8]   <= r_data;   // byte 1
                S_I2: if (!rx_empty && rd_uart) instr[23:16]  <= r_data;   // byte 2
                S_I3: if (!rx_empty && rd_uart) instr[31:24]  <= r_data;   // byte 3
                default: ;
            endcase
        end
    end

    // =====================================================
    // 3) Lógica combinacional de la FSM
    // =====================================================
    always @* begin
        // defaults
        state_n   = state;
        rd_uart   = 1'b0;
        wr_uart   = 1'b0;

        rf_we     = 1'b0;
        rf_waddr  = 5'd0;
        rf_wdata  = {FIFO_W{1'b0}};

        // direcciones de lectura (señaladas todo el tiempo)
        rf_raddr1 = rs1;
        rf_raddr2 = rs2;

        case (state)
            S_IDLE: begin
                if (!rx_empty) state_n = S_I0;
            end

            S_I0: begin
                if (!rx_empty) begin
                    rd_uart = 1'b1;
                    state_n = S_I1;
                end
            end

            S_I1: begin
                if (!rx_empty) begin
                    rd_uart = 1'b1;
                    state_n = S_I2;
                end
            end

            S_I2: begin
                if (!rx_empty) begin
                    rd_uart = 1'b1;
                    state_n = S_I3;
                end
            end

            S_I3: begin
                if (!rx_empty) begin
                    rd_uart = 1'b1;
                    state_n = S_EX;
                end
            end

            // Ejecución (ALU es combinacional afuera)
            S_EX: begin
                state_n = S_WB;
            end

            // Write-back a rd (si es R-type y rd!=x0)
            S_WB: begin
                if (is_rtype && (rd != 5'd0)) begin
                    rf_we    = 1'b1;
                    rf_waddr = rd;
                    rf_wdata = alu_result_in;   // <<< resultado real
                end
                state_n = S_TX;
            end

            // Enviar el resultado por TX (1 byte)
            S_TX: begin
                if (!tx_full) begin
                    wr_uart = ~tx_full;
                    state_n  = S_IDLE;
                end
            end
        endcase
    end
endmodule
