`timescale 1ns / 1ps
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
    input  wire [DATA_W-1:0]  wdata,
    // Debug Unit
    input  wire [4:0]         i_dbg_reg_idx,
    output wire [DATA_W-1:0]  o_dbg_reg_data
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
    end

    /*
    * Lectura con bypassing: si la instrucción en WB escribe a un registro que se está leyendo, 
    * se devuelve el valor de wdata en vez del valor almacenado.
    */

    /*
    Durante las pruebas apareció un caso en el que sub x4, x3, x1 no recibía correctamente el valor de x1. 
    El forwarding en EX resolvía x3, pero no podía resolver x1 porque ese dato ya no estaba disponible en EX/MEM o MEM/WB cuando la instrucción llegaba a EX. 
    El problema real era una lectura simultánea con escritura en el register file: ID intentaba leer x1 en el mismo ciclo en que WB lo escribía.
    */
    
    assign rdata1 = (raddr1 == 5'd0) ? {DATA_W{1'b0}} :
                    (we && (waddr != 5'd0) && (waddr == raddr1)) ? wdata :
                    regs[raddr1];

    assign rdata2 = (raddr2 == 5'd0) ? {DATA_W{1'b0}} :
                    (we && (waddr != 5'd0) && (waddr == raddr2)) ? wdata :
                    regs[raddr2];

    // Debug Unit
    assign o_dbg_reg_data = regs[i_dbg_reg_idx];

endmodule
