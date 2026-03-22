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
            try {
                const res = await Api.connect('COM3', 9600);
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnDisconnect.addEventListener('click', async () => {
            try {
                const res = await Api.disconnect();
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnProgram.addEventListener('click', async () => {
            const asm = document.getElementById('asm-editor').value;
            if (!asm.trim()) {
                ConsoleComponent.logWarn('No hay codigo ASM para programar.');
                return;
            }

            try {
                const res = await Api.programFPGA(asm);
                ConsoleComponent.logInfo(`${res.message} (${res.inst_count} instrucciones).`);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnClear.addEventListener('click', async () => {
            try {
                const res = await Api.clearImem();
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnRun.addEventListener('click', async () => {
            try {
                const res = await Api.run();
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnStop.addEventListener('click', async () => {
            try {
                const res = await Api.stop();
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnStep.addEventListener('click', async () => {
            try {
                const res = await Api.step();
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnDumpRegs.addEventListener('click', async () => {
            try {
                const res = await Api.dumpRegs();
                if (res.dump?.registers) {
                    window.RegistersComponent.updateRegs(res.dump.registers);
                }
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnDumpPipe.addEventListener('click', async () => {
            try {
                const res = await Api.dumpPipeline();
                if (res.dump) {
                    window.PipelineComponent.updatePipeline(res.dump);
                }
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnDumpMem.addEventListener('click', async () => {
            const offsetText = document.getElementById('mem-offset').value || '0';
            const parsedOffset = parseInt(offsetText, 0);
            const offset = Number.isNaN(parsedOffset) ? 0 : parsedOffset;

            try {
                const res = await Api.dumpMemory(offset);
                if (res.dump) {
                    window.MemoryComponent.updateMemory(res.dump);
                }
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        AppState.subscribe((event) => {
            if (['connection_changed', 'cpu_state_changed', 'capabilities_changed', 'status_synced'].includes(event)) {
                this.syncButtons();
            }
        });

        this.syncButtons();
    },

    syncButtons() {
        const connected = AppState.connection.connected;
        const state = AppState.cpu.state;
        const programLoaded = AppState.cpu.programLoaded;
        const capabilities = AppState.capabilities;
        const busy = ['PROGRAMMING', 'STEPPING', 'DUMPING'].includes(state);

        this.btnConnect.disabled = connected;
        this.btnDisconnect.disabled = !connected;
        this.btnProgram.disabled = !connected || state === 'RUNNING' || busy;
        this.btnClear.disabled = !connected || state === 'RUNNING' || !capabilities.can_clear_imem || busy;
        this.btnRun.disabled = !connected || !programLoaded || state === 'RUNNING' || busy;
        this.btnStop.disabled = state !== 'RUNNING';
        this.btnStep.disabled = !connected || !programLoaded || state === 'RUNNING' || busy;
        this.btnDumpRegs.disabled = !connected || !capabilities.can_dump_regs || busy;
        this.btnDumpPipe.disabled = !connected || !capabilities.can_dump_pipeline || busy;
        this.btnDumpMem.disabled = !connected || !capabilities.can_dump_memory || busy;
    }
};
