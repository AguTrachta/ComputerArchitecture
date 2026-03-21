/**
 * app.js
 * Main entry point, setting up tabs and generic app logic.
 */

document.addEventListener('DOMContentLoaded', () => {
    // Initialize tabs
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabPanes = document.querySelectorAll('.tab-pane');
    
    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            // Remove active classes
            tabBtns.forEach(b => b.classList.remove('active'));
            tabPanes.forEach(p => p.style.display = 'none');
            
            // Add active to clicked
            btn.classList.add('active');
            const target = btn.getAttribute('data-target');
            document.getElementById(target).style.display = 'block';
        });
    });

    // Initialize components
    if(window.EditorComponent) window.EditorComponent.init();
    if(window.ControlsComponent) window.ControlsComponent.init();
    if(window.RegistersComponent) window.RegistersComponent.init();
    if(window.MemoryComponent) window.MemoryComponent.init();
    if(window.PipelineComponent) window.PipelineComponent.init();
    if(window.ConsoleComponent) window.ConsoleComponent.init();

    // Subscribe to state changes to update the top bar
    window.AppState.subscribe((event, payload) => {
        if (event === 'connection_changed') {
            const indConn = document.getElementById('ind-conn');
            if (payload.connected) {
                indConn.textContent = "CONNECTED";
                indConn.className = "indicator badge-success";
                WsClient.connect();
            } else {
                indConn.textContent = "DISCONNECTED";
                indConn.className = "indicator badge-danger";
                WsClient.disconnect();
            }
        }
        else if (event === 'cpu_state_changed') {
            const indCpu = document.getElementById('ind-cpu');
            indCpu.textContent = `CPU: ${payload.state}`;
            indCpu.className = payload.state === 'RUNNING' ? 'indicator badge-success' : 
                               payload.state === 'ERROR' ? 'indicator badge-danger' : 'indicator badge-warning';
            
            // Update summary tab state
            const stateText = document.querySelector('#tab-resumen .status-card:nth-child(1) .value');
            if(stateText) stateText.textContent = payload.state;
        }
        else if (event === 'pc_changed') {
            const pcText = document.querySelector('#tab-resumen .status-card:nth-child(2) .value');
            if(pcText) pcText.textContent = payload;
        }
    });
});
