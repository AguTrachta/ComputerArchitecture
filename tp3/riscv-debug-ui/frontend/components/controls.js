/**
 * components/controls.js
 */
window.ControlsComponent = {
    init() {
        this.btnConnect = document.getElementById('btn-connect');
        this.btnDisconnect = document.getElementById('btn-disconnect');
        this.btnProgram = document.getElementById('btn-program');
        this.btnClear = document.getElementById('btn-clear-imem');
        
        this.btnRun = document.getElementById('btn-run');
        this.btnStop = document.getElementById('btn-stop');
        this.btnStep = document.getElementById('btn-step');
        
        this.btnDumpRegs = document.getElementById('btn-dump-regs');
        this.btnDumpPipe = document.getElementById('btn-dump-pipe');
        this.btnDumpMem = document.getElementById('btn-dump-mem');

        this.btnConnect.addEventListener('click', async () => {
            await Api.connect('COM3', 9600);
            this.btnConnect.disabled = true;
            this.btnDisconnect.disabled = false;
        });

        this.btnDisconnect.addEventListener('click', async () => {
            await Api.disconnect();
            this.btnConnect.disabled = false;
            this.btnDisconnect.disabled = true;
        });

        this.btnProgram.addEventListener('click', async () => {
            await Api.programFPGA();
            ConsoleComponent.logInfo('FPGA Programada con éxito.');
        });

        this.btnRun.addEventListener('click', async () => {
            await Api.run();
            ConsoleComponent.logTx('CMD_RUN');
        });

        this.btnStop.addEventListener('click', async () => {
            await Api.stop();
            ConsoleComponent.logTx('CMD_STOP');
        });

        this.btnStep.addEventListener('click', async () => {
            await Api.step();
            ConsoleComponent.logTx('CMD_STEP');
            // Mock receiving data
            setTimeout(() => {
                WsClient.simulateEvent('regs_dump', {
                    registers: [
                        { name: "x0", alias: "zero", hex: "0x00000000", dec: 0 },
                        { name: "x1", alias: "ra", hex: "0x00000005", dec: 5 },
                        { name: "x2", alias: "sp", hex: "0x0000000A", dec: 10 }
                    ]
                });
                
                WsClient.simulateEvent('pipeline_dump', {
                    stages: {
                        Global: { pc: "0x00000004", stall: false },
                        IF: { "instr": "0x00000013" },
                        "IF/ID": { pc: "0x00000000", instr: "0x00500093" },
                        ID: { rs1: "0", rs2: "0", rd: "1" },
                        "ID/EX": { "rs1_val": "0x00", "rs2_val": "0x05", "imm": "0x05" },
                        EX: { "alu_out": "0x05" },
                        "EX/MEM": { "alu_out": "0x05", "mem_write": "0" },
                        MEM: { "mem_read_data": "0x00" },
                        "MEM/WB": { "alu_out": "0x05", "write_reg": "1" },
                        WB: { "reg_write_data": "0x05" }
                    }
                });
            }, 300);
        });

        this.btnDumpRegs.addEventListener('click', async () => {
            await Api.dumpRegs();
            ConsoleComponent.logTx('CMD_DUMP_REGS');
        });
    }
};
