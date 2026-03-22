window.AppState = {
    connection: {
        connected: false,
        port: 'N/A',
        baudrate: 9600
    },
    cpu: {
        state: 'DISCONNECTED',
        imemSize: 1024,
        pc: '0x00000000',
        programLoaded: false,
        loadedProgramWords: 0,
        stepsExecuted: 0
    },
    capabilities: {
        can_clear_imem: true,
        can_clear_dmem: false,
        can_dump_regs: true,
        can_dump_pipeline: true,
        can_dump_pipeline_full_payload: false,
        can_dump_memory: true,
        can_dump_memory_full_payload: false,
        can_reset_exec_independent: false
    },
    listeners: [],

    subscribe(callback) {
        this.listeners.push(callback);
    },

    notify(event, payload) {
        this.listeners.forEach(cb => cb(event, payload));
    },

    setConnection(status, port, baud) {
        this.connection.connected = Boolean(status);
        this.connection.port = port || (this.connection.connected ? this.connection.port : 'N/A');
        this.connection.baudrate = baud || this.connection.baudrate;
        this.notify('connection_changed', { ...this.connection });
    },

    setCpuState(state) {
        this.cpu.state = state;
        this.notify('cpu_state_changed', { ...this.cpu });
    },

    setPc(pc) {
        this.cpu.pc = pc;
        this.notify('pc_changed', pc);
    },

    setCapabilities(capabilities) {
        this.capabilities = {
            ...this.capabilities,
            ...(capabilities || {})
        };
        this.notify('capabilities_changed', { ...this.capabilities });
    },

    setStatus(status) {
        if (!status) return;

        this.connection.connected = Boolean(status.connected);
        this.connection.port = status.port || 'N/A';
        this.connection.baudrate = status.baudrate || 9600;

        this.cpu.state = status.state || 'DISCONNECTED';
        this.cpu.imemSize = status.imem_size || 1024;
        this.cpu.programLoaded = Boolean(status.program_loaded);
        this.cpu.loadedProgramWords = status.loaded_program_words || 0;
        this.cpu.stepsExecuted = status.steps_executed || 0;

        this.setCapabilities(status.capabilities);
        this.notify('connection_changed', { ...this.connection });
        this.notify('cpu_state_changed', { ...this.cpu });
        this.notify('status_synced', status);
    }
};
