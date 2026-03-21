/**
 * api.js
 * Real REST API integration for RISC-V Debug UI.
 */
const BASE_URL = window.location.origin.includes('5500') || window.location.origin.includes('8000') 
    ? 'http://localhost:8080' : ''; // Relative if served from fastAPI directly

const req = async (endpoint, method = 'GET', body = null) => {
    try {
        const options = {
            method,
            headers: { 'Content-Type': 'application/json' }
        };
        if (body) options.body = JSON.stringify(body);
        
        // Appends to the base URL assuming `/api/...` or root paths
        let path = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
        
        const response = await fetch(`${BASE_URL}${path}`, options);
        if(!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
        return await response.json();
    } catch (e) {
        ConsoleComponent.logError(`API Error en ${endpoint}: ${e.message}`);
        throw e;
    }
};

window.Api = {
    // 13.1 Conexión
    async getPorts() {
        return await req('/ports', 'GET');
    },
    async connect(port, baudrate) {
        ConsoleComponent.logInfo(`[API] Connecting to ${port}@${baudrate}...`);
        const res = await req(`/connect?port=${port}&baudrate=${baudrate}`, 'POST');
        if (res.success) {
            AppState.setConnection(true, port, baudrate);
        }
        return res;
    },
    async disconnect() {
        ConsoleComponent.logInfo(`[API] Disconnecting...`);
        const res = await req('/disconnect', 'POST');
        if (res.success) {
            AppState.setConnection(false);
        }
        return res;
    },

    // 13.2 Programa
    async validateProgram(asm) {
        return await req('/api/program/validate', 'POST', { asm });
    },
    async assembleProgram(asm) {
        return await req('/api/program/assemble', 'POST', { asm });
    },
    async programFPGA() {
        AppState.setCpuState('PROGRAMMING');
        const res = await req('/api/program/load', 'POST');
        AppState.setCpuState('PROGRAMMED');
        return res;
    },
    async clearImem() {
        return await req('/api/program/clear-imem', 'POST');
    },

    // 13.3 Control
    async run() {
        return await req('/api/control/run', 'POST');
    },
    async stop() {
        return await req('/api/control/stop', 'POST');
    },
    async step() {
        return await req('/api/control/step', 'POST');
    },

    // 13.4 Dumps
    async dumpRegs() {
        return await req('/api/dump/regs', 'POST');
    },
    async dumpPipeline() {
        return await req('/api/dump/pipeline', 'POST');
    },
    async dumpMemory() {
        return await req('/api/dump/memory', 'POST');
    }
};
