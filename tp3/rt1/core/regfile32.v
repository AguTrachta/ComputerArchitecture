// regfile.v - 32 registros de 8 bits (x0 = 0)
module regfile32 #(
    parameter DATA_W = 32,
    parameter NREGS  = 32
)(
    input  wire               clk,
    input  wire               reset,
    // read ports
    input  wire [4:0]         raddr1,
    input  wire [4:0]         raddr2,
    output wire [DATA_W-1:0]  rdata1,
    output wire [DATA_W-1:0]  rdata2,
    // write port
    input  wire               we,
    input  wire [4:0]         waddr,
    input  wire [DATA_W-1:0]  wdata
);
    reg [DATA_W-1:0] regs [0:NREGS-1];
    integer i;

    // x0 = 0 (write ignorado a x0)
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < NREGS; i = i + 1)
            regs[i] <= 0;
        end else if (we && (waddr != 5'd0))
            regs[waddr] <= wdata;
        // (opcional) inicialización: no necesaria funcionalmente
    end

    assign rdata1 = (raddr1 == 5'd0) ? {DATA_W{1'b0}} : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? {DATA_W{1'b0}} : regs[raddr2];
endmodule
