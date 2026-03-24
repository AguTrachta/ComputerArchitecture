`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Pallardó Tech
// Engineers: Agustín Trachta, Agustín Pallardó
// 
// Create Date: 02/28/2026 05:02:48 PM
// Design Name: RISC-V_Pipeline
// Module Name: top
// Project Name: TP3
// Target Devices: Basys-3 (XC7A35T)
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

module top #(
    parameter NB_OP = 6,
    parameter DMEM_BYTES = 4096,
    parameter ADDR_W = 10,  // 2^10 words = 1024 instrucciones --> instr_mem
    //parameter CLK_FREQ  = 100_000_000, // System Clock --> Revisar si UART falla
    parameter CLK_FREQ  = 90_000_000, // System Clock --> Revisar si UART falla
    parameter BAUD_RATE = 9600, // --> UART baud rate
    parameter UART_BITS = 8,
    parameter FIFO_SIZE = 16,
    parameter TX_FIFO_SIZE = 256, // Jugar con esta si se puede, aumentar el tamaño de la fifo hace que el pipeline se libere antes y llegue a idle a seguir esperando comandos mientras envía la respuesta
    parameter SB_TICK = 16 // ticks para stop bit (16=1 stop, 24=1.5, 32=2)
)(
    input wire i_clk,
    input wire i_reset,
    
    input wire rx,
    output wire tx,
    
    // LEDS DE ESTADO
    output wire led_state_idle,
    output wire led_state_running,
    output wire led_state_programming,
    output wire led_state_dumping
);

    // CLOCK GENERATOR
    wire clk;
    wire locked;
    wire reset;

    assign reset = i_reset | ~locked;
    
    clk_wiz_0 instance_name
    (
        // Clock out ports
        .CLK_90MHZ(clk),     // output CLK_90MHZ
        // Status and control signals
        .reset(i_reset), // input reset
        .locked(locked),       // output locked
       // Clock in ports
        .clk_in1(i_clk)      // input clk_in1
    );


    // ============================================================
    // Wire Declarations
    // ============================================================

    // IF stage outputs
    wire [31:0] if_pc;
    wire [31:0] if_pc_plus4;
    wire [31:0] if_instr;

    // IF/ID register outputs
    wire [31:0] ifid_pc;
    wire [31:0] ifid_pc_plus4;
    wire [31:0] ifid_instr;
    wire ifid_valid;

    // ID stage outputs
    wire [31:0] id_rs1_data;
    wire [31:0] id_rs2_data;
    wire [31:0] id_imm;
    wire [4:0] id_rs1_idx;
    wire [4:0] id_rs2_idx;
    wire [4:0] id_rd_idx;
    wire [NB_OP-1:0] id_alu_op;
    wire [2:0] id_funct3_wire;

    // ID stage control outputs
    wire id_reg_write;
    wire id_mem_read;
    wire id_mem_write;
    wire id_mem_to_reg;
    wire id_alu_src;
    wire id_branch;
    wire id_jump;

    // Control de hazards / flush separados
    wire stall_if; // para IF stage
    wire stall_id; // para ID stage
    wire flush_ifid; // para IF/ID register
    wire flush_idex_hazard; // para ID/EX register (flush por hazard, no por control)
    wire flush_idex; // para ID/EX register (flush general, por control o hazard)

    // Branch compare / target en ID
    wire [31:0] branch_cmp_a; // rs1_data ya forwardeado hacia el comparador de branch en ID
    wire [31:0] branch_cmp_b; // rs2_data ya forwardeado hacia el comparador de branch en ID
    wire [31:0] branch_target_id; // target calculado en ID (PC + inmm) para usar en caso de branch tomado
    wire        branch_eq_id; // resultado de la comparación de igualdad para branches BEQ/BNE en ID
    wire        branch_taken_id; // señal que indica si el branch se toma o no, calculada en ID combinando el resultado de la comparación (branch_eq_id) con el tipo de branch (id_funct3_wire)
    wire        ifid_is_branch; // señal que indica si la instrucción en IF/ID es un branch, para que el hazard unit pueda detectar hazards relacionados con branches

    // Forwarding hacia comparador de branch en ID
    wire branch_fwd_a_exmem; // rs1_data forwardeado desde EX/MEM hacia el comparador de branch en ID
    wire branch_fwd_a_memwb; // rs1_data forwardeado desde MEM/WB hacia el comparador de branch en ID
    wire branch_fwd_b_exmem; // rs2_data forwardeado desde EX/MEM hacia el comparador de branch en ID
    wire branch_fwd_b_memwb; // rs2_data forwardeado desde MEM/WB hacia el comparador de branch en ID

    // ID/EX register outputs
    wire [31:0] idex_pc_plus4;
    wire [31:0] idex_rs1_data;
    wire [31:0] idex_rs2_data;
    wire [31:0] idex_imm;
    wire [4:0] idex_rs1_idx;
    wire [4:0] idex_rs2_idx;
    wire [4:0] idex_rd_idx;
    wire [NB_OP-1:0] idex_alu_op;
    wire [2:0] idex_funct3;

    // ID/EX control outputs
    wire idex_reg_write;
    wire idex_mem_read;
    wire idex_mem_write;
    wire idex_mem_to_reg;
    wire idex_alu_src;
    // wire idex_branch; // WARNING LINTER: not used
    wire idex_jump;
    wire idex_valid;
    
    // Forwarding control
    wire [1:0] forward_a_sel, forward_b_sel;
    
    // Operandos ya forwardeados hacia EX
    wire [31:0] ex_operand_a;
    wire [31:0] ex_rs2_forwarded_in;   // rs2 ya forwardeado (para ALU y stores)
    
    // EX stage outputs
    wire ex_valid;
    wire [31:0] ex_alu_result;
    wire [31:0] ex_rs2_forwarded;
    wire [4:0] ex_rd_idx;
    wire [2:0] ex_funct3;
    wire ex_reg_write;
    wire ex_mem_read;
    wire ex_mem_write;
    wire ex_mem_to_reg;

    // EX/MEM register outputs
    wire exmem_valid;
    wire [31:0] exmem_alu_result;
    wire [31:0] exmem_rs2_forwarded;
    wire [4:0] exmem_rd_idx;
    wire [2:0] exmem_funct3;
    wire exmem_reg_write;
    wire exmem_mem_read;
    wire exmem_mem_write;
    wire exmem_mem_to_reg;

    // MEM stage signals
    wire [31:0] mem_addr;
    wire mem_write_enable;
    wire [3:0] mem_byte_enable;
    wire [31:0] dmem_read_data;
    
    // MEM helpers para C2 / C3
    wire [31:0] mem_write_data;
    wire [31:0] mem_load_data;

    // MEM/WB register outputs
    wire memwb_valid;
    wire [31:0] memwb_alu_result;
    wire [4:0] memwb_rd_idx;
    wire memwb_reg_write;
    wire memwb_mem_to_reg;

    // WB stage outputs
    wire wb_we;
    wire [4:0] wb_rd_idx;
    wire [31:0] wb_write_data;
    wire [31:0] memwb_mem_rdata;

    // ------------------------------------------------------------
    // Soporte para instrucciones de salto
    // ------------------------------------------------------------
    //
    // En esta etapa agregamos soporte para:
    //
    //   - JAL   : salta a PC + imm y escribe rd = PC + 4
    //   - JALR  : salta a rs1 + imm (con bit 0 forzado a 0)
    //             y escribe rd = PC + 4
    //
    // Además, por equivalencia de pseudoinstrucciones:
    //
    //   - J   = JAL  x0, target
    //   - JR  = JALR x0, rs1, 0
    //
    // Como el salto se resuelve en ID, necesitamos:
    //   1) detectar si la instrucción actual es JAL o JALR
    //   2) calcular el target en ID
    //   3) redirigir el PC desde ID
    //   4) dejar que la propia instrucción siga viva en el pipeline,
    //      porque JAL/JALR sí escriben en WB (rd = PC+4)
    //
    // Para soportar esto también se transporta PC+4 por:
    //   ID/EX -> EX/MEM -> MEM/WB
    //
    // y se agrega soporte en WB para que el dato escrito pueda ser:
    //   - ALU result
    //   - MEM read data
    //   - PC + 4   (caso JAL/JALR)
    // ------------------------------------------------------------
    
    wire ifid_is_jal;
    wire ifid_is_jalr;
    wire ifid_is_jump;
    
    wire id_halt;

    wire [31:0] jalr_base_id;
    wire [31:0] jump_target_id;
    wire        jump_taken_id;

    wire [31:0] redirect_target_id;
    wire        redirect_taken_id;

    // Forwarding del registro base de JALR hacia ID
    wire jalr_base_fwd_exmem;
    wire jalr_base_fwd_memwb;

    // Transporte de PC+4 y flag Jump por el pipeline
    wire [31:0] ex_pc_plus4;
    wire        ex_jump;

    wire [31:0] exmem_pc_plus4;
    wire        exmem_jump;

    wire [31:0] memwb_pc_plus4;
    wire        memwb_jump;

    // Valor "arquitectónico" forwardeable desde EX/MEM.
    // Si EX/MEM contiene un jump, el valor correcto para forwardear es PC+4.
    // Si no, el valor correcto es el resultado de ALU.
    wire [31:0] exmem_forward_value;

    // MEM "directo"
    /*
    * CAMBIOS: agregué mem_write_data y mem_byte_enable, y usé exmem_funct3 para decidir qué bytes escribir en memoria. Esto es necesario para soportar SB y SH correctamente.
     * Para SB, se coloca el byte de rs2 en la posición indicada por addr[1:0] y se habilita solo ese byte lane.
     * Para SH, se habilitan los dos byte lanes correspondientes a la mitad de palabra (dependiendo de addr[1:0]) y se coloca rs2 en la posición correcta.
     * Para SW, se habilitan los 4 byte lanes y se coloca rs2 normalmente.
     * Además, mem_write_enable ahora también verifica que al menos un byte lane esté habilitado para evitar escrituras inválidas en caso de direcciones mal alineadas.
     * Esto asegura que las instrucciones de store funcionen correctamente según su tipo (SB, SH, SW) y la dirección de memoria.
    */

    /*
    Cómo se calculan mem_write_data y mem_byte_enable
    -------------------------------------------------
    La memoria escribe de a 32 bits, pero una instrucción store no siempre
    quiere escribir los 4 bytes completos.

    Por eso necesitamos dos cosas:
    1) mem_write_data:
       es el dato acomodado en el byte lane correcto dentro de la palabra.
    2) mem_byte_enable:
       indica qué bytes de esa palabra realmente se van a escribir.

    Se usa:
    - exmem_funct3 para saber si la instrucción es SB, SH o SW
    - mem_addr[1:0] para saber en qué posición dentro de la palabra cae el dato

    Casos:

    1) SB (store byte)
       - Solo se escribe 1 byte
       - Ese byte puede ir en cualquiera de las 4 posiciones de la palabra
       - Entonces:
           mem_write_data  = exmem_rs2_forwarded << (8 * mem_addr[1:0])
           mem_byte_enable = 4'b0001 << mem_addr[1:0]

       Ejemplo:
       si mem_addr[1:0] = 2'b10, el byte se coloca en el tercer byte lane
       y mem_byte_enable = 4'b0100

    2) SH (store halfword)
       - Se escriben 2 bytes consecutivos
       - Solo está bien alineado si mem_addr[1:0] es:
           2'b00  -> halfword bajo
           2'b10  -> halfword alto
       - Entonces:
           si mem_addr[1:0] == 2'b00:
               mem_write_data  = exmem_rs2_forwarded
               mem_byte_enable = 4'b0011

           si mem_addr[1:0] == 2'b10:
               mem_write_data  = exmem_rs2_forwarded << 16
               mem_byte_enable = 4'b1100

           en otro caso:
               dirección mal alineada
               mem_byte_enable = 4'b0000   // no se escribe nada

    3) SW (store word)
       - Se escriben los 4 bytes completos
       - Entonces:
           mem_write_data  = exmem_rs2_forwarded
           mem_byte_enable = 4'b1111
    */
    assign mem_addr         = exmem_alu_result;
    reg  [31:0] mem_write_data_r;

    localparam [2:0] F3_SB = 3'b000;
    localparam [2:0] F3_SH = 3'b001;
    localparam [2:0] F3_SW = 3'b010;

    always @(*) begin
        mem_write_data_r = 32'b0;

        case (exmem_funct3)
            F3_SB: begin
                // coloca rs2[7:0] en el byte lane indicado por addr[1:0]
                mem_write_data_r = exmem_rs2_forwarded << (8 * mem_addr[1:0]);
            end

            F3_SH: begin
                case (mem_addr[1:0])
                    2'b00: mem_write_data_r = exmem_rs2_forwarded;
                    2'b10: mem_write_data_r = exmem_rs2_forwarded << 16;
                    default: mem_write_data_r = 32'b0; // halfword mal alineado
                endcase
            end

            default: begin
                // SW
                mem_write_data_r = exmem_rs2_forwarded;
            end
        endcase
    end

    // mem_write_data se asigna a mem_write_data_r, que se calcula según el tipo de store (SB, SH, SW) 
    // y la dirección de memoria para colocar los datos en la posición correcta y con el byte enable adecuado.
    assign mem_write_data = mem_write_data_r;

    // mem_byte_enable se calcula según exmem_funct3 y mem_addr[1:0] para habilitar los byte lanes correctos en memoria según el tipo de store.
    assign mem_byte_enable =
    (exmem_funct3 == F3_SB) ? (4'b0001 << mem_addr[1:0]) :
    (exmem_funct3 == F3_SH) ? ((mem_addr[1:0] == 2'b00) ? 4'b0011 :
                               (mem_addr[1:0] == 2'b10) ? 4'b1100 :
                                                          4'b0000) :
                              4'b1111;

    // mem_write_enable se activa solo si exmem_mem_write está activo, la instrucción es válida (exmem_valid) 
    // y al menos un byte lane está habilitado (para evitar escrituras inválidas en caso de direcciones mal alineadas).
    assign mem_write_enable = exmem_mem_write & exmem_valid & (|mem_byte_enable);

    // WB hacia el regfile
    wire        dbg_pipeline_en;
    //assign wb_we     = memwb_reg_write & memwb_valid;
    //assign wb_we = memwb_reg_write & memwb_valid & dbg_pipeline_en;
    assign wb_we = memwb_reg_write & memwb_valid & dbg_pipeline_en & (memwb_rd_idx != 5'd0);
    assign wb_rd_idx = memwb_rd_idx;

    // ============================================================
    // Instances
    // ============================================================

    // ============================================================
    // DEBUG UNIT
    // ============================================================
    
    // Debug unit <-> UART FIFOs
    wire        dbg_rx_rd_en;
    wire [7:0]  dbg_tx_data;
    wire        dbg_tx_wr_en;
    
    // Debug unit <-> CPU / IMEM
    //wire        dbg_pipeline_en;
    wire        dbg_reset_exec;
    
    wire        dbg_prog_we;
    wire [31:0] dbg_prog_addr;
    wire [31:0] dbg_prog_wdata;
    
    //wire        cpu_end;
    //assign cpu_end = ifid_valid && (ifid_instr == 32'hffffffff); // HALT
    //assign cpu_end = id_halt;
    
    // Reset de ejecución del micro
    wire cpu_reset;
    assign cpu_reset = reset | dbg_reset_exec;
    
    //wire [7:0] tx_data_dbg;
    wire tx_empty;
    
    // FIFO Interface
    //wire       rd_uart;        // leer dato recibido
    wire [UART_BITS-1:0] r_data;         // dato leído
    wire       rx_empty;       // FIFO Rx vacía
    //wire       wr_uart;        // escribir dato a transmitir
    wire       tx_full;        // FIFO Tx llena
    
    // Dump Regs --> Debug Unit
    // idx para indicar el registro, data lo que contiene
    wire [4:0]  dbg_reg_idx;
    wire [31:0] dbg_reg_data;
    
    // Para DUMP DATA MEMORY
    wire [31:0] dmem_read_data_pipe; // de donde voy a tomar los datos
    wire        dbg_mem_dump_en; // Flag para avisar que estoy dumpeando memoria
    wire [9:0]  dbg_mem_idx;  // addr para memoria
    //wire [31:0] dbg_mem_data; // datos de lectura
    
    
    
    // ------------------------------------------------------------
    // Mapeo de señales del pipeline para CMD_DUMP_LATCHES
    // ------------------------------------------------------------
    // Cada índice representa una palabra de 32 bits enviada al host.
    // Señales angostas van extendidas con ceros.
    //
    //  0: IF/ID stall   REVISAR
    //  1: IF/ID flush   REVISAR
    //  2: IF/ID pc
    //  3: IF/ID pc+4
    //  4: IF/ID instr
    //  5: ID/EX rs1_data
    //  6: ID/EX rs2_data
    //  7: ID/EX imm
    //  8: ID/EX alu_op
    //  9: ID/EX RegWrite
    // 10: ID/EX MemRead
    // 11: ID/EX MemWrite
    // 12: ID/EX MemToReg
    // 13: ID/EX ALUSrc
    // 14: ID/EX Jump
    // 15: EX/MEM alu_result
    // 16: EX/MEM reg_write
    // 17: EX/MEM mem_write
    // 18: EX/MEM mem_to_reg
    // 19: EX/MEM jump
    // 20: MEM/WB rd_idx
    // 21: MEM/WB mem_rdata
    // 22: MEM/WB reg_write
    // 23: MEM/WB mem_to_reg
    // 24: MEM/WB jump
    // ------------------------------------------------------------
    
    wire [4:0]  dbg_latch_idx;
    wire [31:0] dbg_latch_data;
    reg  [31:0] dbg_latch_data_r;
    
    assign dbg_latch_data = dbg_latch_data_r;

    always @(*) begin
        case (dbg_latch_idx)
            5'd0:  dbg_latch_data_r = {31'd0, (stall_id | ~dbg_pipeline_en)};
            5'd1:  dbg_latch_data_r = {31'd0, flush_ifid};
            5'd2:  dbg_latch_data_r = ifid_pc;
            5'd3:  dbg_latch_data_r = ifid_pc_plus4;
            5'd4:  dbg_latch_data_r = ifid_instr;

            5'd5:  dbg_latch_data_r = idex_rs1_data;
            5'd6:  dbg_latch_data_r = idex_rs2_data;
            5'd7:  dbg_latch_data_r = idex_imm;
            5'd8:  dbg_latch_data_r = {{(32-NB_OP){1'b0}}, idex_alu_op};
            5'd9:  dbg_latch_data_r = {31'd0, idex_reg_write};
            5'd10: dbg_latch_data_r = {31'd0, idex_mem_read};
            5'd11: dbg_latch_data_r = {31'd0, idex_mem_write};
            5'd12: dbg_latch_data_r = {31'd0, idex_mem_to_reg};
            5'd13: dbg_latch_data_r = {31'd0, idex_alu_src};
            5'd14: dbg_latch_data_r = {31'd0, idex_jump};

            5'd15: dbg_latch_data_r = exmem_alu_result;
            5'd16: dbg_latch_data_r = {31'd0, exmem_reg_write};
            5'd17: dbg_latch_data_r = {31'd0, exmem_mem_write};
            5'd18: dbg_latch_data_r = {31'd0, exmem_mem_to_reg};
            5'd19: dbg_latch_data_r = {31'd0, exmem_jump};

            5'd20: dbg_latch_data_r = {27'd0, memwb_rd_idx};
            5'd21: dbg_latch_data_r = memwb_mem_rdata;
            5'd22: dbg_latch_data_r = {31'd0, memwb_reg_write};
            5'd23: dbg_latch_data_r = {31'd0, memwb_mem_to_reg};
            5'd24: dbg_latch_data_r = {31'd0, memwb_jump};

            default: dbg_latch_data_r = 32'd0;
            
        endcase
    end
    
    
    
    /* debug_unit ...
     *
     */
    
    debug_unit #(
        // Falta PROG_COUNT_W
        .IMEM_ADDR_W(ADDR_W),
        .DMEM_BYTES(DMEM_BYTES)
    ) dbg_u (
        .clk(clk),
        .reset(reset),
    
        // Control CPU
        .o_pipeline_en(dbg_pipeline_en),
        .o_reset_exec(dbg_reset_exec),
        //.i_cpu_end(cpu_end),   // Intento de HALT
        .i_halt(id_halt),
        
        // Programación IMEM
        .o_prog_we(dbg_prog_we),
        .o_prog_addr(dbg_prog_addr),
        .o_prog_wdata(dbg_prog_wdata),
    
        // RX FIFO
        .i_rx_data(r_data),
        .i_rx_empty(rx_empty),
        .o_rx_rd_en(dbg_rx_rd_en),
    
        // TX FIFO
        .o_tx_data(dbg_tx_data),
        .o_tx_wr_en(dbg_tx_wr_en),
        .i_tx_full(tx_full),
        
        // ID
        .o_dbg_reg_idx(dbg_reg_idx),
        .i_dbg_reg_data(dbg_reg_data),
        
        // Data Memory
        .o_dbg_mem_dump_en(dbg_mem_dump_en),
        .i_dbg_mem_data(dmem_read_data),
        .o_dbg_mem_idx(dbg_mem_idx),
        
        // Latches del pipeline
        .o_dbg_latch_idx(dbg_latch_idx),
        .i_dbg_latch_data(dbg_latch_data),
        
        // LEDS
        .o_state_idle(led_state_idle),
        .o_state_running(led_state_running),
        .o_state_programming(led_state_programming),
        .o_state_dumping(led_state_dumping)
    );
    
    // ------------------- UART -------------------
    
    // Señales de muestreo
    wire sample_tick;
    // Señales RX
    wire [UART_BITS-1:0] rx_dout;  // Bus receptor - fifo
    wire       rx_done_tick;
    // Señales TX
    wire [UART_BITS-1:0] tx_din;  // Bus fifo - transmisor
    wire       tx_start, tx_done_tick;
    
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
    uart_rx #(
        .DBIT(UART_BITS), 
        .SB_TICK(SB_TICK)
    ) rx_unit (
        .clk(clk), 
        .reset(reset),
        .rx(rx),
        .sample_tick(sample_tick),
        .rx_done_tick(rx_done_tick),
        .dout(rx_dout)
    );

    fifo #(
        .W(UART_BITS), // Ancho fifo
        .N(FIFO_SIZE)  // Profundidad fifo
    ) fifo_rx (
        .clk(clk), 
        .reset(reset),
        .wr(rx_done_tick),       // escribir en FIFO cuando llega dato
        .rd(dbg_rx_rd_en),            // leer nuevo cuando interfaz está lista
        .w_data(rx_dout),
        .r_data(r_data),     // dato leído por sistema                              //
        .full(),                 // no usamos "full" en RX          // .full(rx_full)
        .empty(rx_empty)         // indica si FIFO está vacía
    );

    //-----------------------
    // UART Transmitter + FIFO
    //-----------------------
    fifo #(
        .W(UART_BITS), // Ancho fifo
        .N(TX_FIFO_SIZE)  // Profundidad fifo
    ) fifo_tx (
        .clk(clk), 
        .reset(reset),
        .wr(dbg_tx_wr_en),            // sistema escribe dato a enviar                   //
        .rd(tx_done_tick),       // UART Tx lee cuando termina
        .w_data(dbg_tx_data),     // Resultado directo de la alu
        .r_data(tx_din),
        .full(tx_full),          // FIFO llena → no se puede escribir
        .empty(tx_empty)         // señal interna
    );

    assign tx_start = ~tx_empty;  // UART Tx arranca si FIFO no vacía

    uart_tx #(
        .DBIT(UART_BITS), 
        .SB_TICK(SB_TICK)
    ) tx_unit (
        .clk(clk), 
        .reset(reset),
        .tx_start(tx_start),
        .sample_tick(sample_tick),
        .din(tx_din),
        .tx_done_tick(tx_done_tick),
        .tx(tx)
    );
    
    

    // -------------------- IF --------------------

    /* if_stage ...
     *
     */
    if_stage #(
        .ADDR_W(ADDR_W)
    ) if_s (
        .clk(clk),
        .reset(cpu_reset),
        //.pc_write_en(~stall_if),
        .pc_write_en((~stall_if) & dbg_pipeline_en),
        // .flush(1'b0),  // no usamos flush interno de IF por ahora    // WARNING LINTER: not used
        .pc_next_external(redirect_target_id),
        .pc_sel_external(redirect_taken_id),
        
        .prog_we(dbg_prog_we),
        .prog_addr(dbg_prog_addr),
        .prog_wdata(dbg_prog_wdata),
        
        .if_pc(if_pc),
        .if_pc_plus4(if_pc_plus4),
        .if_instr(if_instr)
    );

    // ---------------- IF/ID reg ------------------

    /* if_id_reg ...
     *
     */
    if_id_reg latch_if_id (
        .clk(clk),
        .reset(cpu_reset),
        //.stall(stall_id),
        .stall(stall_id | ~dbg_pipeline_en),
        .flush(flush_ifid),
        .if_pc(if_pc),
        .if_pc_plus4(if_pc_plus4),
        .if_instr(if_instr),
        .id_pc(ifid_pc),
        .id_pc_plus4(ifid_pc_plus4),
        .id_instr(ifid_instr),
        .id_valid(ifid_valid)
    );

    // -------------------- ID --------------------

    hazard_unit u_hzd (
        .ifid_rs1       (id_rs1_idx),
        .ifid_rs2       (id_rs2_idx),
        .ifid_is_branch (ifid_valid && id_branch),
        .ifid_is_jalr   (ifid_is_jalr),

        .idex_rd        (idex_rd_idx),
        .idex_RegWrite  (idex_reg_write),
        .idex_MemRead   (idex_mem_read),

        .exmem_rd       (exmem_rd_idx),
        .exmem_MemRead  (exmem_mem_read),

        .stall_if       (stall_if),
        .stall_id       (stall_id),
        .flush_idex     (flush_idex_hazard)
    );

    // ------------------------------------------------------------
    // Detección temprana de jumps en ID
    // ------------------------------------------------------------
    //
    // ifid_is_jal:
    //   se activa si la instrucción actualmente en IF/ID es JAL
    //
    // ifid_is_jalr:
    //   se activa si la instrucción actualmente en IF/ID es JALR
    //
    // ifid_is_jump:
    //   señal genérica que indica que la instrucción en ID provoca
    //   una redirección incondicional del PC
    //
    // Esto se usa para:
    //   - calcular target en ID
    //   - generar redirect_taken_id
    //   - activar hazards especiales de JALR
    // ------------------------------------------------------------
    assign ifid_is_jal  = ifid_valid && (ifid_instr[6:0] == 7'b1101111);
    assign ifid_is_jalr = ifid_valid && (ifid_instr[6:0] == 7'b1100111);
    assign ifid_is_jump = ifid_is_jal || ifid_is_jalr;

    // /* control_unit ...
    //  *
    //  */
    // control_unit cu (
    //     .instr    (ifid_instr),
    //     .RegWrite (id_reg_write),
    //     .MemRead  (id_mem_read),
    //     .MemWrite (id_mem_write),
    //     .MemToReg (id_mem_to_reg),
    //     .ALUSrc   (id_alu_src),
    //     .Branch   (id_branch),
    //     .Jump     (id_jump)
    // );
    


    /* id_stage ...
     *
     */
    id_stage #(
        .NB_OP(NB_OP)
    ) id_s (
        .clk(clk),
        .reset(cpu_reset),
        //.stall_id(stall_id),      // WARNING LINTER: not used
        //.flush_idex(flush_idex),  // WARNING LINTER: not used

        //.id_pc(ifid_pc),          // WARNING LINTER: not used
        .id_pc_plus4(ifid_pc_plus4),
        .id_instr(ifid_instr),
        //.id_valid(ifid_valid),    // WARNING LINTER: not used

        .wb_we(wb_we),
        .wb_rd(wb_rd_idx),
        .wb_wdata(wb_write_data),

        .idex_pc_plus4(),  // ignoramos esta salida (la verdadera viene del latch ID/EX)
        .idex_rs1_data(id_rs1_data),
        .idex_rs2_data(id_rs2_data),
        .idex_imm(id_imm),
        .idex_rs1(id_rs1_idx),
        .idex_rs2(id_rs2_idx),
        .idex_rd(id_rd_idx),
        .idex_alu_op(id_alu_op),
        .idex_funct3(id_funct3_wire),

        // REVISAR ESTOS, ESTUVE METIENDO MANO. TODO. TOCHECK. TOTEST

        .id_RegWrite(id_reg_write),
        .id_MemRead (id_mem_read),
        .id_MemWrite(id_mem_write),
        .id_MemToReg(id_mem_to_reg),
        .id_ALUSrc  (id_alu_src),
        .id_Branch  (id_branch),
        .id_Jump    (id_jump),
        .id_halt    (id_halt),
        
        // Debug Unit
        .i_dbg_reg_idx(dbg_reg_idx),
        .o_dbg_reg_data(dbg_reg_data)
    );

    // ---------------- ID/EX reg ------------------

    /* id_ex_reg ...
     *
     */
    id_ex_reg #(
        .NB_OP(NB_OP)
    ) latch_id_ex (
        .clk(clk),
        .reset(cpu_reset),
        //.stall(stall_id),
        .stall(stall_id | ~dbg_pipeline_en),
        .flush(flush_idex),

        .id_pc_plus4 (ifid_pc_plus4),
        .id_rs1_data (id_rs1_data),
        .id_rs2_data (id_rs2_data),
        .id_imm      (id_imm),
        .id_rs1      (id_rs1_idx),
        .id_rs2      (id_rs2_idx),
        .id_rd       (id_rd_idx),
        .id_alu_op   (id_alu_op),
        .id_funct3   (id_funct3_wire),

        .id_RegWrite (id_reg_write),
        .id_MemRead  (id_mem_read),
        .id_MemWrite (id_mem_write),
        .id_MemToReg (id_mem_to_reg),
        .id_ALUSrc   (id_alu_src),
        .id_Branch   (id_branch),
        .id_Jump     (id_jump),
        .id_valid    (ifid_valid),

        .idex_pc_plus4(idex_pc_plus4),
        .idex_rs1_data(idex_rs1_data),
        .idex_rs2_data(idex_rs2_data),
        .idex_imm     (idex_imm),
        .idex_rs1     (idex_rs1_idx),
        .idex_rs2     (idex_rs2_idx),
        .idex_rd      (idex_rd_idx),
        .idex_alu_op  (idex_alu_op),
        .idex_funct3  (idex_funct3), 

        .idex_RegWrite(idex_reg_write),
        .idex_MemRead (idex_mem_read),
        .idex_MemWrite(idex_mem_write),
        .idex_MemToReg(idex_mem_to_reg),
        .idex_ALUSrc  (idex_alu_src),
        // .idex_Branch  (idex_branch), // WARNING LINTER: not used
        .idex_Branch  (),               // WARNING LINTER: not used
        .idex_Jump    (idex_jump),
        .idex_valid   (idex_valid)
    );

    // -------------------- EX --------------------

    /* ex_stage ...
     *
     */
     
    forwarding_unit u_fwd (
      .exmem_RegWrite (exmem_reg_write),
      .exmem_rd       (exmem_rd_idx),
      .memwb_RegWrite (memwb_reg_write),
      .memwb_rd       (memwb_rd_idx),
    
      .idex_rs1       (idex_rs1_idx),
      .idex_rs2       (idex_rs2_idx),
    
      .fwdA           (forward_a_sel),
      .fwdB           (forward_b_sel)
    );

    /* ============================================================
     * Forwarding hacia operandos de la ALU (stage EX)
     * ============================================================
     *
     * Dependiendo de forward_a_sel o forward_b_sel, el operando se
     * toma desde:
     *
     * 00 → valor normal leído del register file
     * 01 → resultado que está en WB
     * 10 → resultado que está en EX/MEM
     *
     * Esto evita hazards del tipo:
     *
     *   add x1, x2, x3
     *   sub x4, x1, x5
     *
     * donde `sub` necesita el resultado de `add` antes de que sea
     * escrito en el register file.
     */

    // ------------------------------------------------------------
    // Valor forwardeable desde EX/MEM
    // ------------------------------------------------------------
    //
    // Para la mayoría de las instrucciones, el valor arquitectónico
    // que se forwardea desde EX/MEM es exmem_alu_result.
    //
    // Pero para JAL / JALR, el resultado arquitectónico NO es el
    // resultado de ALU, sino:
    //
    //   rd = PC + 4
    //
    // Por eso, cuando la instrucción en EX/MEM es un jump,
    // el valor correcto para forwarding es exmem_pc_plus4.
    //
    // Esto permite que una instrucción posterior pueda usar
    // correctamente el valor producido por un JAL/JALR sin esperar
    // a que llegue al register file.
    // ------------------------------------------------------------
    assign exmem_forward_value = exmem_jump ? exmem_pc_plus4 : exmem_alu_result;

    // Forward A (rs1)
    assign ex_operand_a =
      (forward_a_sel == 2'b10) ? exmem_forward_value :   // desde EX/MEM
      (forward_a_sel == 2'b01) ? wb_write_data    :   // desde WB (dato real)
                                idex_rs1_data;       // normal

    // Forward B base (rs2) -> importante para stores también
    assign ex_rs2_forwarded_in =
      (forward_b_sel == 2'b10) ? exmem_forward_value :
      (forward_b_sel == 2'b01) ? wb_write_data    :
                                idex_rs2_data;
    
    /* ============================================================
     * Forwarding para comparación de branch (stage ID)
     * ============================================================
     *
     * Como los branches se resuelven en ID, el comparador necesita
     * valores actualizados de rs1 y rs2.
     *
     * Si esos registros están siendo producidos por instrucciones
     * más adelante en el pipeline, se forwardean directamente
     * hacia el comparador del branch.
     */

    localparam [2:0] F3_BEQ = 3'b000;
    localparam [2:0] F3_BNE = 3'b001;

    assign ifid_is_branch = ifid_valid && id_branch;

    // Forward desde EX/MEM hacia el comparador del branch
    // Solo válido si la instrucción NO es un load.
    // (Si fuera load, el dato todavía no está disponible y el
    // hazard unit debe generar un stall.)
    assign branch_fwd_a_exmem =
        ifid_is_branch &&
        exmem_reg_write &&
        !exmem_mem_read &&
        (exmem_rd_idx != 5'd0) &&
        (exmem_rd_idx == id_rs1_idx);

    assign branch_fwd_b_exmem =
        ifid_is_branch &&
        exmem_reg_write &&
        !exmem_mem_read &&
        (exmem_rd_idx != 5'd0) &&
        (exmem_rd_idx == id_rs2_idx);

    // Forward desde MEM/WB hacia el comparador del branch
    // Aquí el dato ya está completamente disponible.
    assign branch_fwd_a_memwb =
        ifid_is_branch &&
        memwb_reg_write &&
        (memwb_rd_idx != 5'd0) &&
        (memwb_rd_idx == id_rs1_idx);

    assign branch_fwd_b_memwb =
        ifid_is_branch &&
        memwb_reg_write &&
        (memwb_rd_idx != 5'd0) &&
        (memwb_rd_idx == id_rs2_idx);

    /* ============================================================
     * Operandos finales usados por el comparador de branch
     * ============================================================
     *
     * Se selecciona el valor más reciente disponible para cada
     * registro del branch.
     *
     * Prioridad:
     *   1) EX/MEM (resultado más nuevo)
     *   2) MEM/WB
     *   3) valor leído del register file
     */
    assign branch_cmp_a =
        branch_fwd_a_exmem ? exmem_forward_value :
        branch_fwd_a_memwb ? wb_write_data    :
                            id_rs1_data;

    assign branch_cmp_b =
        branch_fwd_b_exmem ? exmem_forward_value :
        branch_fwd_b_memwb ? wb_write_data    :
                            id_rs2_data;
                            
    assign branch_eq_id = (branch_cmp_a == branch_cmp_b);

    // target = PC de la instrucción branch + imm_B
    assign branch_target_id = ifid_pc + id_imm;

    // Predict not taken:
    // solo redirigimos si en ID ya sabemos que se toma
    assign branch_taken_id =
        ifid_is_branch &&
        !stall_id &&
        (
            ((id_funct3_wire == F3_BEQ) &&  branch_eq_id) ||
            ((id_funct3_wire == F3_BNE) && !branch_eq_id)
        );

    /* ============================================================
    * Forwarding y cálculo de base para JALR (stage ID)
    * ============================================================
    *
    * JALR calcula su target como:
    *
    *   target = (rs1 + imm) & ~1
    *
    * Como el salto se resuelve en ID, el valor de rs1 debe estar
    * disponible en esa misma etapa.
    *
    * Problema:
    *   rs1 puede depender de una instrucción anterior que todavía
    *   no escribió en el register file.
    *
    * Ejemplos:
    *
    *   add  x5, x1, x2
    *   jalr x7, x5, 0
    *
    * o
    *
    *   lw   x5, 0(x10)
    *   jalr x7, x5, 0
    *
    * En esos casos:
    *   - si el valor ya está en EX/MEM y no es un load,
    *     puede forwardearse directamente a ID
    *   - si el valor está en MEM/WB, también puede forwardearse
    *   - si el valor todavía no está disponible, el hazard unit
    *     debe insertar stall(s)
    *
    * jalr_base_id es entonces el valor real y actualizado de rs1
    * usado para calcular el target del salto en ID.
    * ============================================================ */

    assign jalr_base_fwd_exmem =
        ifid_is_jalr &&
        exmem_reg_write &&
        !exmem_mem_read &&
        (exmem_rd_idx != 5'd0) &&
        (exmem_rd_idx == id_rs1_idx);

    assign jalr_base_fwd_memwb =
        ifid_is_jalr &&
        memwb_reg_write &&
        (memwb_rd_idx != 5'd0) &&
        (memwb_rd_idx == id_rs1_idx);

    assign jalr_base_id =
        jalr_base_fwd_exmem ? exmem_forward_value :
        jalr_base_fwd_memwb ? wb_write_data       :
                            id_rs1_data;

    /* ============================================================
    * Cálculo del target y redirección del PC para jumps
    * ============================================================
    *
    * JAL:
    *   target = PC de la instrucción + imm_J
    *
    * JALR:
    *   target = rs1 + imm_I
    *   y luego se fuerza el bit 0 a cero:
    *
    *     (rs1 + imm) & 32'hFFFF_FFFE
    *
    * Esto último sigue la especificación de RISC-V para JALR.
    *
    * jump_taken_id:
    *   indica que la instrucción actual en ID es un salto válido
    *   y que no está siendo frenada por un stall.
    *
    * redirect_taken_id:
    *   señal general de redirección de PC.
    *   Se activa si:
    *   - un branch condicional resultó tomado, o
    *   - un jump incondicional debe redirigir el PC
    *
    * redirect_target_id:
    *   target efectivo a cargar en el PC.
    *   Si el evento es un jump, usamos jump_target_id.
    *   Si no, usamos branch_target_id.
    *
    * flush_ifid:
    *   mata la instrucción mal fetcheada que estaba entrando desde IF.
    *
    * flush_idex:
    *   solo se activa:
    *   - por hazard, o
    *   - por branch tomado
    *
    * En el caso de jump, no es necesario hacer flush en ID/EX porque la propia 
    * instrucción de salto sigue siendo válida y debe llegar a EX para escribir el valor correcto en rd (PC+4).
    * ============================================================ */

    assign jump_target_id =
        ifid_is_jal  ? (ifid_pc + id_imm) :
        ifid_is_jalr ? ((jalr_base_id + id_imm) & 32'hFFFF_FFFE) :
                    32'b0;

    assign jump_taken_id =
        ifid_is_jump &&
        !stall_id;

    assign redirect_taken_id =
        branch_taken_id || jump_taken_id;

    assign redirect_target_id =
        jump_taken_id ? jump_target_id : branch_target_id;

    //assign flush_ifid = redirect_taken_id;
    //assign flush_idex = flush_idex_hazard | branch_taken_id;
    assign flush_ifid = dbg_pipeline_en & redirect_taken_id;
    assign flush_idex = dbg_pipeline_en & (flush_idex_hazard | branch_taken_id);

    ex_stage #(
        .NB_OP(NB_OP)
    ) ex_s (
        .idex_pc_plus4(idex_pc_plus4),
        .idex_rs1_data(ex_operand_a),
        .idex_rs2_data(ex_rs2_forwarded_in),
        .idex_imm(idex_imm),
        .idex_rd(idex_rd_idx),
        .idex_alu_op(idex_alu_op),
        .idex_funct3(idex_funct3),
        .idex_RegWrite(idex_reg_write),
        .idex_MemRead(idex_mem_read),
        .idex_MemWrite(idex_mem_write),
        .idex_MemToReg(idex_mem_to_reg),
        .idex_ALUSrc(idex_alu_src),
        .idex_Jump(idex_jump),
        .idex_valid(idex_valid),

        .ex_pc_plus4(ex_pc_plus4),
        .ex_valid(ex_valid),
        .ex_alu_out(ex_alu_result),
        .ex_rs2_fwd(ex_rs2_forwarded),
        .ex_rd(ex_rd_idx),
        .ex_funct3(ex_funct3),
        .ex_RegWrite(ex_reg_write),
        .ex_MemRead(ex_mem_read),
        .ex_MemWrite(ex_mem_write),
        .ex_MemToReg(ex_mem_to_reg),
        .ex_Jump(ex_jump)
    );

    // ---------------- EX/MEM reg ------------------

    /* ex_mem_reg ...
     *
     */
    ex_mem_reg latch_ex_mem (
        .clk(clk),
        .reset(cpu_reset),
        //.en(1'b1),
        .en(dbg_pipeline_en),
        .ex_valid_in(ex_valid),
        .ex_pc_plus4_in(ex_pc_plus4),
        .ex_alu_out_in(ex_alu_result),
        .ex_rs2_fwd_in(ex_rs2_forwarded),
        .ex_rd_in(ex_rd_idx),
        .ex_funct3_in(ex_funct3),
        .ex_RegWrite_in(ex_reg_write),
        .ex_MemRead_in(ex_mem_read),
        .ex_MemWrite_in(ex_mem_write),
        .ex_MemToReg_in(ex_mem_to_reg),
        .ex_Jump_in(ex_jump),

        .exmem_valid(exmem_valid),
        .exmem_pc_plus4(exmem_pc_plus4),
        .exmem_alu_out(exmem_alu_result),
        .exmem_rs2_fwd(exmem_rs2_forwarded),
        .exmem_rd(exmem_rd_idx),
        .exmem_funct3(exmem_funct3),
        .exmem_RegWrite(exmem_reg_write),
        .exmem_MemRead(exmem_mem_read),
        .exmem_MemWrite(exmem_mem_write),
        .exmem_MemToReg(exmem_mem_to_reg),
        .exmem_Jump(exmem_jump)
    );

    // --------------------- MEM --------------------
    
    // Para cargas, extraemos el byte/halfword correcto en la etapa WB
    // ya que BRAM de 1 ciclo entrega el dato en WB
    reg  [31:0] formatted_mem_rdata;
    wire [2:0] memwb_funct3;

    localparam [2:0] F3_LB  = 3'b000;
    localparam [2:0] F3_LH  = 3'b001;
    localparam [2:0] F3_LW  = 3'b010;
    localparam [2:0] F3_LBU = 3'b100;
    localparam [2:0] F3_LHU = 3'b101;

    reg [31:0] dmem_read_data_hold; // Mantiene útimo valor
    
    assign dmem_read_data_pipe = dbg_mem_dump_en ? dmem_read_data_hold : dmem_read_data;
    
    always @(posedge clk) begin
        if (reset) begin
            dmem_read_data_hold <= 32'b0;
        end else if (!dbg_mem_dump_en) begin
            dmem_read_data_hold <= dmem_read_data;
        end
    end
    
    always @(*) begin
        formatted_mem_rdata = dmem_read_data_pipe; // default = LW

        case (memwb_funct3)

            // LB: selecciona el byte indicado y hace sign-extension
            F3_LB: begin
                case (memwb_alu_result[1:0])
                    2'b00: formatted_mem_rdata = {{24{dmem_read_data_pipe[7]}},   dmem_read_data_pipe[7:0]};
                    2'b01: formatted_mem_rdata = {{24{dmem_read_data_pipe[15]}},  dmem_read_data_pipe[15:8]};
                    2'b10: formatted_mem_rdata = {{24{dmem_read_data_pipe[23]}},  dmem_read_data_pipe[23:16]};
                    2'b11: formatted_mem_rdata = {{24{dmem_read_data_pipe[31]}},  dmem_read_data_pipe[31:24]};
                endcase
            end

            // LBU: selecciona el byte indicado y hace zero-extension
            F3_LBU: begin
                case (memwb_alu_result[1:0])
                    2'b00: formatted_mem_rdata = {24'b0, dmem_read_data_pipe[7:0]};
                    2'b01: formatted_mem_rdata = {24'b0, dmem_read_data_pipe[15:8]};
                    2'b10: formatted_mem_rdata = {24'b0, dmem_read_data_pipe[23:16]};
                    2'b11: formatted_mem_rdata = {24'b0, dmem_read_data_pipe[31:24]};
                endcase
            end

            // LH: selecciona el halfword indicado y hace sign-extension
            F3_LH: begin
                case (memwb_alu_result[1:0])
                    2'b00: formatted_mem_rdata = {{16{dmem_read_data_pipe[15]}}, dmem_read_data_pipe[15:0]};
                    2'b10: formatted_mem_rdata = {{16{dmem_read_data_pipe[31]}}, dmem_read_data_pipe[31:16]};
                    default: formatted_mem_rdata = 32'b0; // halfword desalineado
                endcase
            end

            // LHU: selecciona el halfword indicado y hace zero-extension
            F3_LHU: begin
                case (memwb_alu_result[1:0])
                    2'b00: formatted_mem_rdata = {16'b0, dmem_read_data_pipe[15:0]};
                    2'b10: formatted_mem_rdata = {16'b0, dmem_read_data_pipe[31:16]};
                    default: formatted_mem_rdata = 32'b0;
                endcase
            end

            default: begin
                formatted_mem_rdata = dmem_read_data_pipe; // LW
            end
        endcase
    end

    assign memwb_mem_rdata = formatted_mem_rdata;
    wire [31:0] mem_load_data = 32'b0; // unused


    wire [31:0] a_addr;
    wire        a_we;
    wire  [3:0] a_byte_en;
    //wire [31:0] a_rdata;
    
    assign a_addr       = dbg_mem_dump_en ? {20'b0, dbg_mem_idx, 2'b00} : mem_addr;
    assign a_we         = dbg_mem_dump_en ? 1'b0                        : mem_write_enable;
    assign a_byte_en    = dbg_mem_dump_en ? 4'b0000                     : mem_byte_enable;
    //assign dbg_mem_data = dmem_read_data;


    /* data_mem ...
     *
     */
    data_mem #(
        .DEPTH_BYTES(DMEM_BYTES)
    ) u_dmem (
        .clk     (clk),
        .reset   (reset),
        .addr    (a_addr),
        .wdata   (mem_write_data),
        .we      (a_we),
        .byte_en (a_byte_en),
        .rdata   (dmem_read_data)
    );

    // ----------------- MEM/WB reg ------------------

    mem_wb_reg #(
        .NB_OP(NB_OP)
    ) latch_mem_wb (
        .clk         (clk),
        .reset       (cpu_reset),
        //.en          (1'b1),
        .en(dbg_pipeline_en),
        .mem_valid_in(exmem_valid),
        .pc_plus4_in (exmem_pc_plus4),
        .alu_out_in  (exmem_alu_result),
        .rd_in       (exmem_rd_idx),
        .mem_rdata_in(32'b0), // Unused, BRAM already registers read data
        .RegWrite_in (exmem_reg_write),
        .MemToReg_in (exmem_mem_to_reg),
        .Jump_in     (exmem_jump),
        .funct3_in   (exmem_funct3),

        .wb_valid    (memwb_valid),
        .wb_pc_plus4 (memwb_pc_plus4),
        .wb_alu_out  (memwb_alu_result),
        .wb_rd       (memwb_rd_idx),
        .wb_mem_rdata(), // Unused, memwb_mem_rdata assigned combinatorially above
        .wb_RegWrite (memwb_reg_write),
        .wb_MemToReg (memwb_mem_to_reg),
        .wb_Jump     (memwb_jump),
        .wb_funct3   (memwb_funct3)
    );

    // --------------------- WB ---------------------
        
    /* ============================================================
    * Writeback mux
    * ============================================================
    *
    * Selecciona qué valor vuelve al register file.
    *
    * Casos:
    *
    * 1) Jump = 1
    *    Para JAL / JALR, el resultado arquitectónico es:
    *
    *      rd = PC + 4
    *
    *    Por eso, si Jump está activo, wb_wdata toma pc_plus4.
    *
    * 2) Jump = 0 y MemToReg = 1
    *    Caso loads:
    *
    *      rd = dato leído de memoria
    *
    * 3) Jump = 0 y MemToReg = 0
    *    Caso ALU / inmediatas / comparaciones / etc.:
    *
    *      rd = resultado de ALU
    * ============================================================ */    
    wb_mux u_wb (
        .mem_rdata (memwb_mem_rdata),
        .alu_out   (memwb_alu_result),
        .pc_plus4  (memwb_pc_plus4),
        .MemToReg  (memwb_mem_to_reg),
        .Jump      (memwb_jump),
        .wb_wdata  (wb_write_data)
    );
    
endmodule