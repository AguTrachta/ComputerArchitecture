document.addEventListener('DOMContentLoaded', async () => {
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabPanes = document.querySelectorAll('.tab-pane');

    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            tabBtns.forEach(button => button.classList.remove('active'));
            tabPanes.forEach(pane => {
                pane.classList.remove('active');
                pane.style.display = 'none';
            });

            btn.classList.add('active');
            const target = btn.getAttribute('data-target');
            const targetPane = document.getElementById(target);
            if (targetPane) {
                targetPane.classList.add('active');
                targetPane.style.display = 'flex';
            }
        });
    });

    if (window.EditorComponent) window.EditorComponent.init();
    if (window.ControlsComponent) window.ControlsComponent.init();
    if (window.RegistersComponent) window.RegistersComponent.init();
    if (window.MemoryComponent) window.MemoryComponent.init();
    if (window.PipelineComponent) window.PipelineComponent.init();
    if (window.ConsoleComponent) window.ConsoleComponent.init();

    const updateIndicators = () => {
        const port = document.getElementById('ind-port');
        const baud = document.getElementById('ind-baud');
        const conn = document.getElementById('ind-conn');
        const cpu = document.getElementById('ind-cpu');
        const imem = document.getElementById('ind-imem');
        const stateText = document.querySelector('#tab-resumen .status-card:nth-child(1) .value');
        const pcText = document.querySelector('#tab-resumen .status-card:nth-child(2) .value');

        port.textContent = AppState.connection.port || 'N/A';
        baud.textContent = `${AppState.connection.baudrate} baud`;
        imem.textContent = `IMEM ${AppState.cpu.imemSize}`;

        conn.textContent = AppState.connection.connected ? 'CONNECTED' : 'DISCONNECTED';
        conn.className = AppState.connection.connected ? 'indicator badge-success' : 'indicator badge-danger';

        cpu.textContent = `CPU: ${AppState.cpu.state}`;
        cpu.className = AppState.cpu.state === 'RUNNING'
            ? 'indicator badge-success'
            : AppState.cpu.state === 'ERROR'
                ? 'indicator badge-danger'
                : 'indicator badge-warning';

        if (stateText) stateText.textContent = AppState.cpu.state;
        if (pcText) pcText.textContent = AppState.cpu.pc;
    };

    AppState.subscribe((event, payload) => {
        if (event === 'connection_changed') {
            updateIndicators();
            if (payload.connected) {
                WsClient.connect();
            } else {
                WsClient.disconnect();
            }
            return;
        }

        if (event === 'cpu_state_changed' || event === 'pc_changed' || event === 'status_synced') {
            updateIndicators();

            if (event === 'status_synced') {
                if (payload.last_register_dump?.registers) {
                    window.RegistersComponent.updateRegs(payload.last_register_dump.registers);
                }
                if (payload.last_pipeline_dump) {
                    window.PipelineComponent.updatePipeline(payload.last_pipeline_dump);
                }
                if (payload.last_memory_dump) {
                    window.MemoryComponent.updateMemory(payload.last_memory_dump);
                }
            }
        }
    });

    updateIndicators();

    try {
        await Api.getStatus();
    } catch (error) {
        ConsoleComponent.logWarn(`No se pudo leer /status: ${error.message}`);
    }
});
