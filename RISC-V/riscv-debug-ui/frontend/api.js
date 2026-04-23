const buildApiCandidates = () => {
    if (window.location.protocol === 'file:') {
        return ['http://localhost:8080'];
    }

    const candidates = [''];
    if (window.location.port === '5500') {
        candidates.push('http://localhost:8080');
    } else if (window.location.port === '8000') {
        candidates.push('http://localhost:8080');
    }
    return candidates;
};

const extractErrorMessage = async (response) => {
    try {
        const data = await response.json();
        if (typeof data?.detail === 'string') return data.detail;
        if (Array.isArray(data?.detail?.errors)) return data.detail.errors.join(' | ');
        if (typeof data?.detail === 'object') return JSON.stringify(data.detail);
        return JSON.stringify(data);
    } catch (_error) {
        return `HTTP ${response.status}`;
    }
};

const req = async (endpoint, method = 'GET', body = null) => {
    const options = {
        method,
        headers: { 'Content-Type': 'application/json' }
    };

    if (body !== null) {
        options.body = JSON.stringify(body);
    }

    const path = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
    const candidates = buildApiCandidates();
    let lastError = null;

    for (const baseUrl of candidates) {
        try {
            const response = await fetch(`${baseUrl}${path}`, options);

            if (!response.ok) {
                const message = await extractErrorMessage(response);
                ConsoleComponent.logError(`API Error en ${endpoint}: ${message}`);
                throw new Error(message);
            }

            if (response.status === 204) return null;
            return await response.json();
        } catch (error) {
            lastError = error;
            const isNetworkError = error instanceof TypeError;
            if (!isNetworkError || baseUrl === candidates[candidates.length - 1]) {
                throw error;
            }
        }
    }

    throw lastError || new Error(`No se pudo alcanzar ${endpoint}.`);
};

const syncStatus = async () => {
    const status = await req('/status', 'GET');
    AppState.setStatus(status);
    return status;
};

window.Api = {
    async getPorts() {
        return await req('/ports', 'GET');
    },

    async getStatus() {
        return await syncStatus();
    },

    async connect(port, baudrate) {
        const res = await req(`/connect?port=${port}&baudrate=${baudrate}`, 'POST');
        await syncStatus();
        return res;
    },

    async disconnect() {
        const res = await req('/disconnect', 'POST');
        await syncStatus();
        return res;
    },

    async validateProgram(asm) {
        return await req('/api/program/validate', 'POST', { asm });
    },

    async assembleProgram(asm) {
        return await req('/api/program/assemble', 'POST', { asm });
    },

    async programFPGA(asm) {
        const res = await req('/api/program/load', 'POST', { asm });
        await syncStatus();
        return res;
    },

    async clearImem() {
        const res = await req('/api/program/clear-imem', 'POST');
        await syncStatus();
        return res;
    },

    async run() {
        const res = await req('/api/control/run', 'POST');
        if (res?.state) AppState.setCpuState(res.state);
        return res;
    },

    async stop() {
        const res = await req('/api/control/stop', 'POST');
        await syncStatus();
        return res;
    },

    async step() {
        const res = await req('/api/control/step', 'POST');
        await syncStatus();
        return res;
    },

    async dumpRegs() {
        return await req('/api/dump/regs', 'POST');
    },

    async dumpPipeline() {
        return await req('/api/dump/pipeline', 'POST');
    },

    async dumpMemory(page = 0, pageSize = 32) {
        return await req('/api/dump/memory', 'POST', { page, page_size: pageSize });
    }
};
