`timescale 1ns/1ps

module tb_top_id();

    // ===============================
    // Señales para el DUT
    // ===============================
    reg clk;
    reg reset;
    reg stall;
    reg flush;
    
    // variable para probar STALL
    reg [4:0] old_rd;


    // Instanciamos el top de ID
    top_id dut (
        .clk   (clk),
        .reset (reset),
        .stall (stall),
        .flush (flush)
    );

    // ===============================
    // Clock 100 MHz
    // ===============================
    initial clk = 0;
    always #5 clk = ~clk;

    // ===============================
    // TASK: Aplicar nueva instrucción al ID
    // ===============================
    task load_instr(input [31:0] instr, input [31:0] pc);
    begin
        dut.id_instr    = instr;
        dut.id_pc       = pc;
        dut.id_pc_plus4 = pc + 32'd4;
        dut.id_valid    = 1'b1;
        @(posedge clk);
        #1;   // dejamos que se propaguen las señales
    end
    endtask

    // ===============================
    // Inicio del test
    // ===============================
    initial begin
        $display("\n======================================");
        $display("==== INICIO tb_top_id (ID Stage)  ====");
        $display("======================================\n");

        // Inicialización
        reset = 1;
        stall = 0;
        flush = 0;

        @(posedge clk);
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        #1;

        // -------------------------------------------------
        // 1) Escribimos valores en el regfile mediante WB
        // -------------------------------------------------
        $display("[TB] Escribiendo x1 = 10, x2 = 20 en WB...");
        dut.wb_we    = 1;
        dut.wb_rd    = 5'd1;
        dut.wb_wdata = 32'd10;
        @(posedge clk);

        dut.wb_rd    = 5'd2;
        dut.wb_wdata = 32'd20;
        @(posedge clk);

        dut.wb_we    = 0;
        @(posedge clk);
        #1;

        // Chequeamos que el regfile tenga los valores correctos
        if (dut.id_rs1_data !== 0) begin
            $display("[WARN] regfile no está leyendo, se validará más adelante con instrucciones.");
        end

        // -------------------------------------------------
        // 2) Test R-type: ADD x3,x1,x2   → instr = 0x002081B3
        // -------------------------------------------------
        $display("\n[TB] Probando instrucción R-type: ADD x3,x1,x2");

        load_instr(32'h0020_81B3, 32'h0000_0000);

        // Chequeo de registros
        if (dut.id_rs1 !== 5'd1) $fatal("ERROR: rs1 esperado 1, obt %0d", dut.id_rs1);
        if (dut.id_rs2 !== 5'd2) $fatal("ERROR: rs2 esperado 2, obt %0d", dut.id_rs2);
        if (dut.id_rd  !== 5'd3) $fatal("ERROR: rd esperado 3, obt %0d", dut.id_rd);

        // Chequeo de valores del regfile
        if (dut.id_rs1_data !== 32'd10) $fatal("ERROR: rs1_data esperado=10, obt=%0d", dut.id_rs1_data);
        if (dut.id_rs2_data !== 32'd20) $fatal("ERROR: rs2_data esperado=20, obt=%0d", dut.id_rs2_data);

        // Inmediato = 0 para R-type
        if (dut.id_imm !== 32'd0) $fatal("ERROR: imm esperado 0 para R-type");

        // Señales de control
        if (!dut.id_RegWrite) $fatal("ERROR: RegWrite debe ser 1 para ADD");
        if (dut.id_ALUSrc)    $fatal("ERROR: ALUSrc debe ser 0 para ADD");

        $display("[OK] R-type decodificado correctamente.");

        // -------------------------------------------------
        // 3) Test I-type: ADDI x1,x0,5   → instr = 0x00500093
        // -------------------------------------------------
        $display("\n[TB] Probando ADDI x1,x0,5");

        load_instr(32'h0050_0093, 32'h0000_0004);

        if (dut.id_rs1  !== 5'd0) $fatal("ERROR: rs1 esperado 0, obt %0d", dut.id_rs1);
        if (dut.id_rd   !== 5'd1) $fatal("ERROR: rd esperado 1, obt %0d", dut.id_rd);
        if (dut.id_imm  !== 32'd5) $fatal("ERROR: imm esperado=5, obt=%0d", dut.id_imm);

        if (!dut.id_RegWrite) $fatal("ERROR: RegWrite debe ser 1 para ADDI");
        if (!dut.id_ALUSrc)   $fatal("ERROR: ALUSrc debe ser 1 para ADDI");

        $display("[OK] ADDI decodificado correctamente.");

        // -------------------------------------------------
        // 4) Test LW
        // -------------------------------------------------
        $display("\n[TB] Probando LW x4, 8(x1)");

        // LW → opcode 0000011 (no nos importa el encod exacto para este test)
        load_instr(32'h0080_2303, 32'h0000_0008);  

        if (!dut.id_MemRead)  $fatal("ERROR: MemRead debe ser 1 en LW");
        if (!dut.id_MemToReg) $fatal("ERROR: MemToReg debe ser 1 en LW");
        if (!dut.id_ALUSrc)   $fatal("ERROR: ALUSrc debe ser 1 en LW");

        $display("[OK] LW control OK.");

        // -------------------------------------------------
        // 5) Test SW
        // -------------------------------------------------
        $display("\n[TB] Probando SW x2, 12(x1)");

        // SW → opcode 0100011
        load_instr(32'h00C1_A023, 32'h0000_000C);

        if (!dut.id_MemWrite) $fatal("ERROR: MemWrite debe ser 1 en SW");
        if (dut.id_RegWrite)  $fatal("ERROR: RegWrite debe ser 0 en SW");

        $display("[OK] SW control OK.");

        // -------------------------------------------------
        // 6) Test BEQ
        // -------------------------------------------------
        $display("\n[TB] Probando BEQ x1,x2,label");

        load_instr(32'h0020_8C63, 32'h0000_0010);

        if (!dut.id_Branch)   $fatal("ERROR: Branch debe ser 1 en BEQ");
        if (dut.id_RegWrite)  $fatal("ERROR: RegWrite debe ser 0 en BEQ");

        $display("[OK] BEQ control OK.");

        // -------------------------------------------------
        // 7) Test JAL
        // -------------------------------------------------
        $display("\n[TB] Probando JAL x1, offset");

        load_instr(32'h0040_00EF, 32'h0000_0014);

        if (!dut.id_Jump)     $fatal("ERROR: Jump debe ser 1 en JAL");
        if (!dut.id_RegWrite) $fatal("ERROR: RegWrite = 1 en JAL (rd=link)");

        $display("[OK] JAL control OK.");

        // -------------------------------------------------
        // 8) Test FLUSH (inserta burbuja)
        // -------------------------------------------------
        $display("\n[TB] Probando FLUSH...");

        // nos aseguramos de no estar en stall
        stall = 0;

        // alineamos con el reloj
        flush = 0;
        @(posedge clk);
        #1;

        // activamos flush durante un ciclo completo
        flush = 1;
        @(posedge clk);   // en este flanco el latch debe ver flush=1
        #1;               // dejamos que se apliquen los <=

        // chequeos
        if (dut.idex_valid    !== 1'b0)
            $fatal("ERROR: flush debe apagar idex_valid (=%0b)", dut.idex_valid);

        if (dut.idex_RegWrite !== 1'b0)
            $fatal("ERROR: flush debe limpiar control (RegWrite=%0b)", dut.idex_RegWrite);

        $display("[OK] Flush funcionando correctamente.");

        // volvemos a 0
        flush = 0;
        @(posedge clk);
        #1;

        // -------------------------------------------------
        // 9) Test STALL (congela ID/EX)
        // -------------------------------------------------
        $display("\n[TB] Probando STALL...");
    
        // cargamos una instrucción
        load_instr(32'h0020_81B3, 32'h0000_0000); // ADD
    
        @(posedge clk);
        #1;
    
        // guardamos RD original ANTES del stall
        old_rd = dut.idex_rd;
    
        // aplicamos STALL
        stall = 1;
    
        // cambiamos instrucción (NO debería copiarse al latch)
        load_instr(32'h0050_0093, 32'h0000_0004);  // ADDI
    
        @(posedge clk);
        #1;
    
        // chequeo: rd debe ser el viejo
        if (dut.idex_rd !== old_rd)
            $fatal("ERROR: stall debe mantener idex_rd anterior (old=%0d, new=%0d)", old_rd, dut.idex_rd);
    
        // liberar stall
        stall = 0;
    
        $display("[OK] Stall funcionando correctamente.");


        // -------------------------------------------------
        // FIN DEL TEST
        // -------------------------------------------------
        $display("\n======================================");
        $display("====   tb_top_id FINALIZADO OK    ====");
        $display("======================================\n");

        $finish;

    end

endmodule
