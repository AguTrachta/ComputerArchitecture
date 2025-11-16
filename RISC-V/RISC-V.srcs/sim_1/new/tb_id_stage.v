`timescale 1ns / 1ps

module tb_id_stage(

    );
    
    // Parámetro de ALU op
    localparam NB_OP = 6;

    // Códigos de ALU (mismos que en tu decoder)
    localparam ADD = 6'b100000;
    // (si querés después agregás SUB, AND, etc.)

    // Señales del DUT
    reg         clk;
    reg         reset;
    reg         stall_id;
    reg         flush_idex;
    reg  [31:0] id_pc;
    reg  [31:0] id_pc_plus4;
    reg  [31:0] id_instr;
    reg         id_valid;

    reg         wb_we;
    reg  [4:0]  wb_rd;
    reg  [31:0] wb_wdata;

    wire [31:0] idex_pc_plus4;
    wire [31:0] idex_rs1_data;
    wire [31:0] idex_rs2_data;
    wire [31:0] idex_imm;
    wire [4:0]  idex_rs1;
    wire [4:0]  idex_rs2;
    wire [4:0]  idex_rd;
    wire [NB_OP-1:0] idex_alu_op;

    // Instancia del DUT
    id_stage #(
        .NB_OP(NB_OP)
    ) dut (
        .clk          (clk),
        .reset        (reset),
        .stall_id     (stall_id),
        .flush_idex   (flush_idex),
        .id_pc        (id_pc),
        .id_pc_plus4  (id_pc_plus4),
        .id_instr     (id_instr),
        .id_valid     (id_valid),
        .wb_we        (wb_we),
        .wb_rd        (wb_rd),
        .wb_wdata     (wb_wdata),
        .idex_pc_plus4(idex_pc_plus4),
        .idex_rs1_data(idex_rs1_data),
        .idex_rs2_data(idex_rs2_data),
        .idex_imm     (idex_imm),
        .idex_rs1     (idex_rs1),
        .idex_rs2     (idex_rs2),
        .idex_rd      (idex_rd),
        .idex_alu_op  (idex_alu_op)
    );

    // Clock simple
    initial clk = 0;
    always #5 clk = ~clk; // periodo 10ns → 100 MHz

    initial begin
        // Inicialización
        reset       = 0;
        stall_id    = 0;
        flush_idex  = 0;
        id_pc       = 32'h0000_0000;
        id_pc_plus4 = 32'h0000_0004;
        id_instr    = 32'h0000_0013; // NOP tipo ADDI x0,x0,0 si querés
        id_valid    = 1'b1;

        wb_we       = 0;
        wb_rd       = 0;
        wb_wdata    = 0;

        // Esperar un par de ciclos
        @(posedge clk);
        @(posedge clk);

        // ----------------------------------------------------
        // 1) Escribimos x1 = 10 y x2 = 20 en el register file
        //    usando la interfaz de WB
        // ----------------------------------------------------
        $display("Escribiendo x1 = 10, x2 = 20 en regfile...");

        // x1 = 10
        wb_we    = 1'b1;    // Habilito para escribir
        wb_rd    = 5'd1;    // Posición 1
        wb_wdata = 32'd10;  // Valor 10
        @(posedge clk);

        // x2 = 20
        wb_rd    = 5'd2;    // Posición 2
        wb_wdata = 32'd20;  // Valor 20
        @(posedge clk);

        wb_we = 1'b0;       // Apago la escritura
        @(posedge clk);

        // ----------------------------------------------------
        // 2) Test R-type: ADD x3, x1, x2
        //    opcode = 0110011, funct3=000, funct7=0000000
        //    rd = 3, rs1=1, rs2=2
        //    Instr: 32'h002081B3
        // ----------------------------------------------------
        $display("Probando R-type: ADD x3, x1, x2...");

        id_instr = 32'h0020_81B3;       // ADD x3,x1,x2
        id_pc_plus4 = 32'h0000_0008;    // Forzar manualmente a la siguiente posición

        #1; // dejar que se propaguen señales combinacionales

        // Checks
        
        // Verifica que el decoder haya sacado bien rs1 = x1 (registro 1)
        // Es decir, que los bits [19:15] de la instrucción se hayan interpretado como 5'd1
        if (idex_rs1 !== 5'd1)  $fatal("ERROR ADD: rs1 esperado=1, obt=%0d", idex_rs1);
        
        // Verifica que rs2 = x2 (registro 2)
        // Chequea el campo rs2 decodificado
        if (idex_rs2 !== 5'd2)  $fatal("ERROR ADD: rs2 esperado=2, obt=%0d", idex_rs2);
        
        // Verifica que rd = x3 (registro 3)
        // Es el destino de la instrucción ADD
        if (idex_rd  !== 5'd3)  $fatal("ERROR ADD: rd  esperado=3, obt=%0d", idex_rd);




        // Verifica que el register file haya devuelto el dato correcto para rs1
        // Antes en el test escribimos x1 = 10 → acá comprobamos que se lea 10
        if (idex_rs1_data !== 32'd10) $fatal("ERROR ADD: rs1_data esperado=10, obt=%0d", idex_rs1_data);
        // Verifica que el register file haya devuelto el dato correcto para rs2
        // Antes en el test escribimos x2 = 20 → acá comprobamos que se lea 20
        if (idex_rs2_data !== 32'd20) $fatal("ERROR ADD: rs2_data esperado=20, obt=%0d", idex_rs2_data);



        // Verifica que el inmediato sea 0
        // Para una instrucción R-type (ADD) no hay inmediato, así que imm debe ser 0
        if (idex_imm !== 32'd0)
            $fatal("ERROR ADD: imm esperado=0 (para R-type), obt=0x%08h", idex_imm);



        // Verifica que el código de operación de la ALU (alu_op)
        // sea el correspondiente a ADD (la constante localparam ADD)
        // Es decir, que el rv_decoder haya configurado bien alu_op
        if (idex_alu_op !== ADD)
            $fatal("ERROR ADD: alu_op esperado=ADD (%b), obt=%b", ADD, idex_alu_op);

        $display("OK: R-type ADD decodificado correctamente.\n");

        // ----------------------------------------------------
        // 3) Test I-type: ADDI x1, x0, 5
        //    opcode = 0010011, funct3=000, imm=5
        //    Instr: 32'h00500093
        // ----------------------------------------------------
        $display("Probando I-type: ADDI x1, x0, 5...");

        id_instr    = 32'h0050_0093; // ADDI x1,x0,5
        id_pc_plus4 = 32'h0000_000C;

        #1;

        // Verifico que la posición sea 0 porque es operador inmediato
        if (idex_rs1 !== 5'd0)  $fatal("ERROR ADDI: rs1 esperado=0, obt=%0d", idex_rs1);
        
        // Posición para almacenar es la 1
        if (idex_rd  !== 5'd1)  $fatal("ERROR ADDI: rd esperado=1, obt=%0d", idex_rd);

        if (idex_rs1_data !== 32'd0)
            $fatal("ERROR ADDI: rs1_data esperado=0 (x0), obt=%0d", idex_rs1_data);

        // Espero que el inmediato sea el asignado, 5
        if (idex_imm !== 32'd5)
            $fatal("ERROR ADDI: imm esperado=5, obt=%0d", idex_imm);

        // El operador debe ser ADD
        if (idex_alu_op !== ADD)
            $fatal("ERROR ADDI: alu_op esperado=ADD, obt=%b", idex_alu_op);

        $display("OK: I-type ADDI decodificado y immediate generado correctamente.\n");

        $display("==== tb_id_stage finalizado OK ====");
        $finish;
    end
    
endmodule
