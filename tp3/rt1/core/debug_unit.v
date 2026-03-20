`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/15/2026 12:10:06 PM
// Design Name: 
// Module Name: debug_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module debug_unit #(
    parameter IMEM_ADDR_W   = 10,
    parameter PROG_COUNT_W  = 16
)(
    input  wire clk,
    input  wire reset,
    
    // Control del CPU
    output wire o_pipeline_en, // Valid para el funcionamiento del pipeline
    output wire o_reset_exec, // Reset del pipeline
    //input  wire i_cpu_end, // atarlo a 1'b0 por ahora
    input  wire i_halt,
    
    // Control Instruction Memory
    output wire        o_prog_we, // Write Enable de la memoria
    output wire [31:0] o_prog_addr, // Dirección de programación de la memoria de instrucciones (BUS DE DATOS)
    output wire [31:0] o_prog_wdata, // Datos a escribir a la memoria (BUS DE DATOS)
    
    // Interfaz con FIFO RX
    input  wire [7:0]  i_rx_data,
    input  wire        i_rx_empty,
    output wire        o_rx_rd_en,
    
    // Interfaz con FIFO TX
    output wire [7:0]  o_tx_data,
    output wire        o_tx_wr_en,
    input  wire        i_tx_full,
    
    // REGs of ID 
    output wire [4:0]  o_dbg_reg_idx,
    input  wire [31:0] i_dbg_reg_data
    );
    
    
    // ============================================================
    // Estados
    // ============================================================
    
    localparam [4:0]
    // Debug unit
        ST_IDLE            = 5'd0, // Esperando algun comando
        ST_DECODE_CMD      = 5'd1, // Decodificando el comando
        ST_ERROR           = 5'd2, // Error ???
    // Memoria de programa
        ST_PROG_CLEAR      = 5'd3, // Limpiar memoria con NOP
        ST_PROG_BEGIN      = 5'd4, // Grabar memoria
        ST_PROG_LEN_HI     = 5'd5,
        ST_PROG_LEN_LO     = 5'd6,
        ST_PROG_B0         = 5'd7,
        ST_PROG_B1         = 5'd8,
        ST_PROG_B2         = 5'd9,
        ST_PROG_B3         = 5'd10,
        ST_PROG_WRITE_WORD = 5'd11,
        ST_PROG_END        = 5'd12,
    // Ejecucion
        ST_RUN_CONTINUOUS  = 5'd13, // Ejecuta programa normalmente
        ST_STEP_ARM        = 5'd14,  // REVISAR SI ESTE SIRVE PARA FRENAR AL SIGUIENTE CLK Y DUMPEAR (si se complementa con exec)
        ST_STEP_EXEC       = 5'd15, // Ejecuta un step del programa
        ST_RESET_EXEC      = 5'd16,
        ST_DRAIN           = 5'd17, // Detectó HALT, espero a vaciar pipeline
    // Dumps
        ST_DUMP_LATCHES    = 5'd18, // Dump de latches
        ST_DUMP_MEM        = 5'd19, // Dump de memoria de datos
        ST_DUMP_DONE       = 5'd20,
    // Subestados --> DUMP REGS
            ST_DUMP_REGS_HDR      = 5'd21,
            ST_DUMP_REGS_SET_IDX  = 5'd22,
            ST_DUMP_REGS_LATCH    = 5'd23,
            ST_DUMP_REGS_SEND_B3  = 5'd24,
            ST_DUMP_REGS_SEND_B2  = 5'd25,
            ST_DUMP_REGS_SEND_B1  = 5'd26,
            ST_DUMP_REGS_SEND_B0  = 5'd27,
            ST_DUMP_REGS_NEXT     = 5'd28;
    
    // Estados FSM
    reg [4:0] state, next_state;
    reg [1:0] reset_exec_cnt, next_reset_exec_cnt;
    reg [1:0] drain_cnt, next_drain_cnt;
    
    
    // ============================================================
    // Comandos UART
    // ============================================================
    
    localparam [7:0]
        CMD_NONE         = 8'h00,
        CMD_PROG_BEGIN   = 8'h10, // payload: 2 bytes = cantidad de palabras
        CMD_PROG_END     = 8'h11, // REVISAR
        CMD_RUN          = 8'h20,
        CMD_STEP         = 8'h21,
        CMD_STOP         = 8'h22,
        CMD_DUMP_REGS    = 8'h30,
        CMD_DUMP_LATCHES = 8'h31,
        CMD_DUMP_MEM     = 8'h32,
        CMD_CLEAR_IMEM   = 8'h40;

    localparam [31:0] NOP = 32'h00000013;
    
    // ACKs
    localparam [7:0]
        RESP_OK_CLEAR    = 8'hC0,
        RESP_OK_PROG     = 8'hC1,
        RESP_OK_STEP     = 8'hC2,
        RESP_OK_STOP     = 8'hC3,
        RESP_OK_RUN_END  = 8'hC4,
        
        // Trama DUMP_REGS:
        // [RESP_DUMP_REGS] + 32 registros x 4 bytes (MSB primero)
        // Total = 1 + 32*4 = 129 bytes
        RESP_DUMP_REGS   = 8'hD0,
        RESP_DUMP_LATCH  = 8'hD1,
        RESP_DUMP_MEM    = 8'hD2,
        RESP_DUMP_DONE   = 8'hD5,
        RESP_ERR         = 8'hEE;
    
    localparam IMEM_DEPTH = (1 << IMEM_ADDR_W);
    
    // Registros para comandos
    reg [7:0] cmd_reg, next_cmd_reg;
    
    // Buffer de recepción desacoplado de la FIFO RX
    reg [7:0] rx_byte_reg;
    reg       rx_byte_valid;
    reg       rx_pop_pending;

    reg       next_rx_byte_valid;
    reg       next_rx_pop_pending;
    reg       next_rx_consume;
    
    // Registros para ID
    reg [4:0]  dbg_reg_idx_r, next_dbg_reg_idx_r;
    reg [31:0] dbg_reg_data_latched, next_dbg_reg_data_latched;
    
    
    
    // ============================================================
    // Registros FSM
    // ============================================================

    // Programación de IMEM
    //reg [1:0]  byte_count, next_byte_count;          // cuenta bytes de una palabra
    reg [31:0] word_buffer, next_word_buffer;
    reg [31:0] prog_addr_reg, next_prog_addr_reg;

    reg [PROG_COUNT_W-1:0] prog_words_total,   next_prog_words_total;
    reg [PROG_COUNT_W-1:0] prog_words_written, next_prog_words_written;
    //reg [1:0]              prog_len_byte_cnt,  next_prog_len_byte_cnt;

    // Clear de IMEM
    reg [IMEM_ADDR_W-1:0] clear_idx, next_clear_idx;

    // Salidas registradas
    reg        pipeline_en_r, next_pipeline_en_r;
    reg        reset_exec_r,  next_reset_exec_r;

    reg        prog_we_r,     next_prog_we_r;
    reg [31:0] prog_addr_r,   next_prog_addr_r;
    reg [31:0] prog_wdata_r,  next_prog_wdata_r;

    reg        rx_rd_en_r,    next_rx_rd_en_r;
    reg [7:0]  tx_data_r,     next_tx_data_r;
    reg        tx_wr_en_r,    next_tx_wr_en_r;
    
    
    
    // Registro de estado y registros internos
    always @(posedge clk) begin
        if (reset) begin
            state              <= ST_IDLE;
            cmd_reg            <= CMD_NONE;

            //byte_count         <= 2'd0;
            word_buffer        <= 32'd0;
            prog_addr_reg      <= 32'd0;

            prog_words_total   <= {PROG_COUNT_W{1'b0}};
            prog_words_written <= {PROG_COUNT_W{1'b0}};
            //prog_len_byte_cnt  <= 2'd0;

            clear_idx          <= {IMEM_ADDR_W{1'b0}};

            pipeline_en_r      <= 1'b0;
            reset_exec_r       <= 1'b1;

            prog_we_r          <= 1'b0;
            prog_addr_r        <= 32'd0;
            prog_wdata_r       <= 32'd0;

            rx_rd_en_r         <= 1'b0;
            tx_data_r          <= 8'd0;
            tx_wr_en_r         <= 1'b0;
            
            rx_byte_reg        <= 8'd0;
            rx_byte_valid      <= 1'b0;
            rx_pop_pending     <= 1'b0;
            
            reset_exec_cnt     <= 2'd0;
            drain_cnt          <= 2'd0;
            
            // Para ID
            dbg_reg_idx_r         <= 5'd0;
            dbg_reg_data_latched  <= 32'd0;
        end else begin
            state              <= next_state;
            cmd_reg            <= next_cmd_reg;

            //byte_count         <= next_byte_count;
            word_buffer        <= next_word_buffer;
            prog_addr_reg      <= next_prog_addr_reg;

            prog_words_total   <= next_prog_words_total;
            prog_words_written <= next_prog_words_written;
            //prog_len_byte_cnt  <= next_prog_len_byte_cnt;

            clear_idx          <= next_clear_idx;

            pipeline_en_r      <= next_pipeline_en_r;
            reset_exec_r       <= next_reset_exec_r;

            prog_we_r          <= next_prog_we_r;
            prog_addr_r        <= next_prog_addr_r;
            prog_wdata_r       <= next_prog_wdata_r;

            rx_rd_en_r         <= next_rx_rd_en_r;
            tx_data_r          <= next_tx_data_r;
            tx_wr_en_r         <= next_tx_wr_en_r;
            
            reset_exec_cnt     <= next_reset_exec_cnt;
            drain_cnt           <= next_drain_cnt;
            
            // Para ID
            dbg_reg_idx_r         <= next_dbg_reg_idx_r;
            dbg_reg_data_latched  <= next_dbg_reg_data_latched;
                        
            // Captura diferida desde FIFO RX
            rx_pop_pending <= next_rx_pop_pending;

            // Si en este ciclo estaba pendiente una lectura,
            // capturo i_rx_data ahora y lo dejo válido
            if (rx_pop_pending) begin
                rx_byte_reg   <= i_rx_data;
                rx_byte_valid <= 1'b1;
            end else if (next_rx_consume) begin
                rx_byte_valid <= 1'b0;
            end else begin
                rx_byte_valid <= next_rx_byte_valid;
            end
        end
    end
    
    
    
    // Lógica combinacional
    always @(*) begin
        // Defaults
        next_state              = state;
        next_cmd_reg            = cmd_reg;

        //next_byte_count         = byte_count;
        next_word_buffer        = word_buffer;
        next_prog_addr_reg      = prog_addr_reg;

        next_prog_words_total   = prog_words_total;
        next_prog_words_written = prog_words_written;
        //next_prog_len_byte_cnt  = prog_len_byte_cnt;

        next_clear_idx          = clear_idx;

        next_pipeline_en_r      = pipeline_en_r;
        next_reset_exec_r       = reset_exec_r;

        next_prog_we_r          = 1'b0;      // pulso de 1 ciclo
        next_prog_addr_r        = prog_addr_r;
        next_prog_wdata_r       = prog_wdata_r;

        next_rx_rd_en_r         = 1'b0;      // pulso de 1 ciclo
        next_tx_data_r          = tx_data_r;
        next_tx_wr_en_r         = 1'b0;      // pulso de 1 ciclo
        
        next_rx_byte_valid   = rx_byte_valid;
        next_rx_pop_pending  = rx_pop_pending;
        next_rx_consume      = 1'b0;
        
        next_reset_exec_cnt    = reset_exec_cnt;
        next_drain_cnt         = drain_cnt;
        
        // Para ID
        next_dbg_reg_idx_r        = dbg_reg_idx_r;
        next_dbg_reg_data_latched = dbg_reg_data_latched;
        
        
        // si estaba pendiente una lectura, al próximo ciclo
        // ya no debe seguir pendiente
        if (rx_pop_pending) begin
            next_rx_pop_pending = 1'b0;
        end
        
        case (state)
        
            // ----------------------------------------------------
            // Debug unit
            // ----------------------------------------------------
            ST_IDLE: begin // Esperamos a recibir algo
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;

                if (rx_byte_valid) begin
                    next_cmd_reg    = rx_byte_reg;
                    next_rx_consume = 1'b1;
                    next_state      = ST_DECODE_CMD;
                end else if (!rx_byte_valid && !rx_pop_pending && !i_rx_empty) begin
                    next_rx_rd_en_r      = 1'b1;
                    next_rx_pop_pending  = 1'b1;
                end
            end
            
            
            
            ST_DECODE_CMD: begin // Lógica para decodificar el comando recibido
                case (cmd_reg)
                    CMD_CLEAR_IMEM:   next_state = ST_PROG_CLEAR;
                    CMD_PROG_BEGIN:   next_state = ST_PROG_BEGIN;
                    CMD_RUN:          next_state = ST_RUN_CONTINUOUS;
                    CMD_STEP:         next_state = ST_STEP_ARM;
                    CMD_DUMP_REGS:    next_state = ST_DUMP_REGS_HDR; //ST_DUMP_REGS;
                    CMD_DUMP_LATCHES: next_state = ST_DUMP_LATCHES;
                    CMD_DUMP_MEM:     next_state = ST_DUMP_MEM;
                    CMD_STOP:         next_state = ST_IDLE; // Revisar si conviene aplicar esto solo cuando esté en ST_RUN_CONTINUOUS.
//                    CMD_STOP: begin
//                        if (!i_tx_full) begin
//                            next_tx_data_r  = RESP_OK_STOP;
//                            next_tx_wr_en_r = 1'b1;
//                            next_state      = ST_IDLE;
//                        end
//                    end
                    default: next_state = ST_ERROR;
                endcase
            end
            
            
            
            // ----------------------------------------------------
            // Memoria de programa
            // ----------------------------------------------------
            ST_PROG_CLEAR: begin // Llenar la memoria de programa con NOPs
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b1;

                next_prog_we_r     = 1'b1;
                next_prog_addr_r   = {20'd0, clear_idx, 2'b00};
                next_prog_wdata_r  = NOP;

                if (clear_idx == IMEM_DEPTH-1) begin
                    next_clear_idx = {IMEM_ADDR_W{1'b0}};
                    if (!i_tx_full) begin
                        next_tx_data_r  = RESP_OK_CLEAR;
                        next_tx_wr_en_r = 1'b1;
                        next_state      = ST_IDLE;
                    end
                end else begin
                    next_clear_idx = clear_idx + 1'b1;
                end
            end
            
            
            
            ST_PROG_BEGIN: begin // Inicio de programación
                next_pipeline_en_r      = 1'b0;
                next_reset_exec_r       = 1'b1;
            
                next_prog_addr_reg      = 32'd0;
                next_prog_words_total   = {PROG_COUNT_W{1'b0}};
                next_prog_words_written = {PROG_COUNT_W{1'b0}};
                next_word_buffer        = 32'd0;
            
                next_state = ST_PROG_LEN_HI;
            end
            
            
            
            ST_PROG_LEN_HI: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b1;
            
                if (rx_byte_valid) begin
                    next_prog_words_total = {rx_byte_reg, 8'd0};
                    next_rx_consume       = 1'b1;
                    next_state            = ST_PROG_LEN_LO;
                end else if (!rx_byte_valid && !rx_pop_pending && !i_rx_empty) begin
                    next_rx_rd_en_r      = 1'b1;
                    next_rx_pop_pending  = 1'b1;
                end
            end
            
            
            
            ST_PROG_LEN_LO: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b1;
            
                if (rx_byte_valid) begin
                    next_prog_words_total = {prog_words_total[15:8], rx_byte_reg};
                    next_word_buffer      = 32'd0;
                    next_rx_consume       = 1'b1;
                    next_state            = ST_PROG_B0;
                end else if (!rx_byte_valid && !rx_pop_pending && !i_rx_empty) begin
                    next_rx_rd_en_r      = 1'b1;
                    next_rx_pop_pending  = 1'b1;
                end
            end
            
            
            
            ST_PROG_B0: begin
                if (rx_byte_valid) begin
                    next_word_buffer[31:24] = rx_byte_reg;
                    next_rx_consume         = 1'b1;
                    next_state              = ST_PROG_B1;
                end else if (!rx_byte_valid && !rx_pop_pending && !i_rx_empty) begin
                    next_rx_rd_en_r      = 1'b1;
                    next_rx_pop_pending  = 1'b1;
                end
            end
            
            
            
            ST_PROG_B1: begin
                if (rx_byte_valid) begin
                    next_word_buffer[23:16] = rx_byte_reg;
                    next_rx_consume         = 1'b1;
                    next_state              = ST_PROG_B2;
                end else if (!rx_byte_valid && !rx_pop_pending && !i_rx_empty) begin
                    next_rx_rd_en_r      = 1'b1;
                    next_rx_pop_pending  = 1'b1;
                end
            end
            
            
            
            ST_PROG_B2: begin
                if (rx_byte_valid) begin
                    next_word_buffer[15:8] = rx_byte_reg;
                    next_rx_consume        = 1'b1;
                    next_state             = ST_PROG_B3;
                end else if (!rx_byte_valid && !rx_pop_pending && !i_rx_empty) begin
                    next_rx_rd_en_r      = 1'b1;
                    next_rx_pop_pending  = 1'b1;
                end
            end
            
            
            
            ST_PROG_B3: begin
                if (rx_byte_valid) begin
                    next_word_buffer[7:0] = rx_byte_reg;
                    next_rx_consume       = 1'b1;
                    next_state            = ST_PROG_WRITE_WORD;
                end else if (!rx_byte_valid && !rx_pop_pending && !i_rx_empty) begin
                    next_rx_rd_en_r      = 1'b1;
                    next_rx_pop_pending  = 1'b1;
                end
            end
            
            
            
            ST_PROG_WRITE_WORD: begin // Escribir palabra armada en IMEM
                next_prog_we_r    = 1'b1;
                next_prog_addr_r  = prog_addr_reg;
                next_prog_wdata_r = word_buffer;
            
                next_prog_addr_reg      = prog_addr_reg + 32'd4;
                next_prog_words_written = prog_words_written + 1'b1;
            
                if (prog_words_written == (prog_words_total - 1'b1)) begin
                    next_state = ST_PROG_END;
                end else begin
                    next_word_buffer = 32'd0;
                    next_state = ST_PROG_B0;
                end
            end
            
            
            
            ST_PROG_END: begin // Fin de programación
                if (!i_tx_full) begin
                    next_tx_data_r       = RESP_OK_PROG;
                    next_tx_wr_en_r      = 1'b1;
                    next_reset_exec_cnt  = 2'd0;
                    next_state           = ST_RESET_EXEC;
                end
            end
            
            
            
            // ----------------------------------------------------
            // Ejecucion
            // ----------------------------------------------------
            ST_RUN_CONTINUOUS: begin // Run continuo
                next_reset_exec_r  = 1'b0;
                next_pipeline_en_r = 1'b1;

                // Si HALT fue detectado en ID, dejamos de fetchear nuevas
                // instrucciones y pasamos a drenar el pipeline.
                if (i_halt) begin
                    //next_pipeline_en_r = 1'b0;
                    next_pipeline_en_r = 1'b1;
                    next_drain_cnt     = 2'd0;
                    next_state         = ST_DRAIN;

                end else if (rx_byte_valid) begin
                    if (rx_byte_reg == CMD_STOP) begin // Si viene un CMD_STOP por UART
                        next_rx_consume    = 1'b1;
                        next_pipeline_en_r = 1'b0;
                        if (!i_tx_full) begin
                            next_tx_data_r  = RESP_OK_STOP;
                            next_tx_wr_en_r = 1'b1;
                            next_state      = ST_IDLE;
                        end
                    end
                end else if (!rx_byte_valid && !rx_pop_pending && !i_rx_empty) begin
                    next_rx_rd_en_r     = 1'b1;
                    next_rx_pop_pending = 1'b1;
                end
            end
            
            
            
            ST_STEP_ARM: begin // Step de 1 ciclo
                next_reset_exec_r  = 1'b0;
                next_pipeline_en_r = 1'b1;
                next_state         = ST_STEP_EXEC;
            end

            ST_STEP_EXEC: begin
                next_pipeline_en_r = 1'b0;
                if (!i_tx_full) begin
                    next_tx_data_r  = RESP_OK_STEP;
                    next_tx_wr_en_r = 1'b1;
                    next_state      = ST_IDLE;
                end
            end
            
            
            
            ST_RESET_EXEC: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b1;
            
                if (reset_exec_cnt == 2'd2) begin
                    next_reset_exec_r   = 1'b0;
                    next_reset_exec_cnt = 2'd0;
                    next_state          = ST_IDLE;
                end else begin
                    next_reset_exec_cnt = reset_exec_cnt + 1'b1;
                end
            end
            
            
            
            ST_DRAIN: begin
                next_reset_exec_r = 1'b0;

                // En drain no queremos fetchear nuevas instrucciones,
                // pero sí dejar avanzar lo que ya estaba en el pipeline.
                next_pipeline_en_r = 1'b1;

                // Esperamos 3 ciclos:
                // 0 -> 1
                // 1 -> 2
                // 2 -> terminar
                if (drain_cnt == 2'd2) begin
                //if (drain_cnt == 2'd3) begin
                    next_pipeline_en_r = 1'b0;
                    if (!i_tx_full) begin
                        next_tx_data_r  = RESP_OK_RUN_END;
                        next_tx_wr_en_r = 1'b1;
                        next_drain_cnt  = 2'd0;
                        next_state      = ST_IDLE;
                    end
                end else begin
                    next_drain_cnt = drain_cnt + 1'b1;
                end
            end
            
            
                        
            // ----------------------------------------------------
            // Dumps
            // ----------------------------------------------------
            
            
            
            ST_DUMP_LATCHES: begin // Latches
                next_pipeline_en_r = 1'b0;
                if (!i_tx_full) begin
                    next_tx_data_r  = RESP_DUMP_LATCH;
                    next_tx_wr_en_r = 1'b1;
                    next_state      = ST_DUMP_DONE;
                end
            end
            
            
            
            ST_DUMP_MEM: begin // Memoria de datos
                next_pipeline_en_r = 1'b0;
                if (!i_tx_full) begin
                    next_tx_data_r  = RESP_DUMP_MEM;
                    next_tx_wr_en_r = 1'b1;
                    next_state      = ST_DUMP_DONE;
                end
            end
            
            
            
            ST_DUMP_DONE: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;
                
                if (!i_tx_full) begin
                    next_tx_data_r  = RESP_DUMP_DONE;
                    next_tx_wr_en_r = 1'b1;
                    next_state         = ST_IDLE;
                end
            end
            
            
            
            // ----------------------------------------------------
            // Error
            // ----------------------------------------------------
            ST_ERROR: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;
                if (!i_tx_full) begin
                    next_tx_data_r  = RESP_ERR;
                    next_tx_wr_en_r = 1'b1;
                    next_state      = ST_IDLE;
                end
            end
            
            
            
            // ---------
            // DUMP REGS
            // ---------
            
            
            
            ST_DUMP_REGS_HDR: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;
            
                if (!i_tx_full) begin
                    next_tx_data_r          = RESP_DUMP_REGS;
                    next_tx_wr_en_r         = 1'b1;
                    next_dbg_reg_idx_r      = 5'd0;
                    next_dbg_reg_data_latched = 32'd0;
                    next_state              = ST_DUMP_REGS_SET_IDX;
                end
            end
            
            
            
            ST_DUMP_REGS_SET_IDX: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;
            
                next_dbg_reg_idx_r = dbg_reg_idx_r; // Revisar si esta línea estí bien, o directamente si el estado es necesario
                next_state         = ST_DUMP_REGS_LATCH;
            end
            
            
            
            ST_DUMP_REGS_LATCH: begin
                next_pipeline_en_r        = 1'b0;
                next_reset_exec_r         = 1'b0;
            
                next_dbg_reg_data_latched = i_dbg_reg_data;
                next_state                = ST_DUMP_REGS_SEND_B3;
            end
            
            
            
            ST_DUMP_REGS_SEND_B3: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;
            
                if (!i_tx_full) begin
                    next_tx_data_r  = dbg_reg_data_latched[31:24];
                    next_tx_wr_en_r = 1'b1;
                    next_state      = ST_DUMP_REGS_SEND_B2;
                end
            end
            
            
            
            ST_DUMP_REGS_SEND_B2: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;
            
                if (!i_tx_full) begin
                    next_tx_data_r  = dbg_reg_data_latched[23:16];
                    next_tx_wr_en_r = 1'b1;
                    next_state      = ST_DUMP_REGS_SEND_B1;
                end
            end
            
            
            
            ST_DUMP_REGS_SEND_B1: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;
            
                if (!i_tx_full) begin
                    next_tx_data_r  = dbg_reg_data_latched[15:8];
                    next_tx_wr_en_r = 1'b1;
                    next_state      = ST_DUMP_REGS_SEND_B0;
                end
            end
            
            
            
            ST_DUMP_REGS_SEND_B0: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;
            
                if (!i_tx_full) begin
                    next_tx_data_r  = dbg_reg_data_latched[7:0];
                    next_tx_wr_en_r = 1'b1;
                    next_state      = ST_DUMP_REGS_NEXT;
                end
            end
            
            
            
            ST_DUMP_REGS_NEXT: begin
                next_pipeline_en_r = 1'b0;
                next_reset_exec_r  = 1'b0;
            
                if (dbg_reg_idx_r == 5'd31) begin
                    next_state = ST_DUMP_DONE;
                end else begin
                    next_dbg_reg_idx_r = dbg_reg_idx_r + 1'b1;
                    next_state         = ST_DUMP_REGS_SET_IDX;
                end
            end
            
            

            default: begin
                next_state = ST_IDLE;
            end
            
        endcase
    end
    
    
    
    assign o_pipeline_en = pipeline_en_r;
    assign o_reset_exec  = reset_exec_r;

    assign o_prog_we     = prog_we_r;
    assign o_prog_addr   = prog_addr_r;
    assign o_prog_wdata  = prog_wdata_r;

    assign o_rx_rd_en    = rx_rd_en_r;
    assign o_tx_data     = tx_data_r;
    assign o_tx_wr_en    = tx_wr_en_r;
    
    // ID
    assign o_dbg_reg_idx = dbg_reg_idx_r;
    
    
endmodule
