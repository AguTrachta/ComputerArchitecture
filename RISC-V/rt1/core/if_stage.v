module if_stage #(
    // Este parámetro hay que agregarlo al top y a la debug unit, es para el tamaño de mem de instr.
    parameter ADDR_W = 10  // 2^10 words = 1024 instrucciones
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        pc_write_en,
    // input  wire        flush,        // WARNING LINTER: not used
    input  wire [31:0] pc_next_external,   // viene de EX (branch/jump)
    input  wire        pc_sel_external,    // 1 = usar pc_next_external

    output wire [31:0] if_pc,
    output wire [31:0] if_pc_plus4,
    output wire [31:0] if_instr,
    
    // Control desde debug unit:
    input  wire        prog_we,
    input  wire [31:0] prog_addr,
    input  wire [31:0] prog_wdata
);

    // ============================
    // PC
    // ============================
    wire [31:0] pc;
    wire [31:0] pc_plus4 = pc + 32'd4;

    assign if_pc        = pc;
    assign if_pc_plus4  = pc_plus4;
    
    // Salta si pc_sel_external es 1, si no continua con pc+4
    wire [31:0] real_pc_next = pc_sel_external ? pc_next_external :
                                                   pc_plus4;

    pc pc_i (
        .clk(clk),
        .reset(reset),
        .pc_write_en(pc_write_en),
        .pc_next(real_pc_next),
        .pc(pc)
    );

    // ============================
    // Instruction Memory
    // ============================
    instr_mem #(
        .ADDR_W(ADDR_W)
    )imem_i (
        .clk(clk),
        .addr(pc),
        .instr(if_instr),
        .prog_we(prog_we),
        .prog_addr(prog_addr),
        .prog_wdata(prog_wdata)
    );

endmodule
