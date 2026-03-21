/**
 * ws.js
 * Real WebSocket connection for real-time events.
 */

window.WsClient = {
    connected: false,
    socket: null,
    
    connect() {
        if (this.socket && this.socket.readyState === WebSocket.OPEN) return;

        const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsHost = window.location.origin.includes('5500') || window.location.origin.includes('8000') 
            ? 'localhost:8080' : window.location.host;
            
        this.socket = new WebSocket(`${wsProtocol}//${wsHost}/ws`);
        
        this.socket.onopen = () => {
            this.connected = true;
            ConsoleComponent.logInfo("WebSocket conectado con el backend.");
        };

        this.socket.onclose = () => {
            this.connected = false;
            ConsoleComponent.logWarn("WebSocket desconectado del backend.");
            setTimeout(() => {
                if (window.AppState.connection.connected) {
                    this.connect(); // Try to reconnect if app thinks it's still connected
                }
            }, 3000);
        };

        this.socket.onerror = (error) => {
            ConsoleComponent.logError("WebSocket Error.");
        };

        this.socket.onmessage = (msgEvent) => {
            try {
                const event = JSON.parse(msgEvent.data);
                this.routeEvent(event);
            } catch (e) {
                console.error("Failed to parse WS message", e);
            }
        };
    },
    
    disconnect() {
        if (this.socket) {
            this.socket.close();
            this.socket = null;
        }
        this.connected = false;
    },

    // Route event exactly as the simulate wrapper did
    routeEvent(event) {
        if (!event || !event.type) return;
        
        switch (event.type) {
            case 'regs_dump':
                window.RegistersComponent.updateRegs(event.payload.registers || []);
                break;
            case 'pipeline_dump':
                window.PipelineComponent.updatePipeline(event.payload || {});
                break;
            case 'uart_tx':
                window.ConsoleComponent.logTx(event.payload.text || "N/A");
                break;
            case 'uart_rx':
                window.ConsoleComponent.logRx(event.payload.text || "N/A");
                break;
            case 'backend_state':
                if (event.payload.state) {
                    window.AppState.setCpuState(event.payload.state);
                }
                break;
            case 'connection_status':
                if (event.payload && typeof event.payload.connected === 'boolean') {
                    // Si el backend avisa que se desconectó el UART
                    window.AppState.setConnection(event.payload.connected, event.payload.port, event.payload.baudrate);
                }
                break;
            case 'error':
                window.ConsoleComponent.logError(`Backend Error: ${event.payload.message || 'Unknown payload'}`);
                break;
        }
    }
};
