/**
 * state.js
 * Manages the frontend's reactive state for the MVP.
 */

window.AppState = {
    connection: {
        connected: false,
        port: 'COM3',
        baudrate: 9600
    },
    cpu: {
        state: 'IDLE',
        imemSize: '1024',
        pc: '0x00000000'
    },
    // Observers pattern
    listeners: [],
    
    // Subscribe to state changes
    subscribe(callback) {
        this.listeners.push(callback);
    },

    // Notify all listeners
    notify(event, payload) {
        this.listeners.forEach(cb => cb(event, payload));
    },

    // Update connection state
    setConnection(status, port, baud) {
        this.connection.connected = status;
        if (port) this.connection.port = port;
        if (baud) this.connection.baudrate = baud;
        this.notify('connection_changed', this.connection);
    },

    // Update CPU state
    setCpuState(state) {
        this.cpu.state = state;
        this.notify('cpu_state_changed', this.cpu);
    },
    
    setPc(pc) {
        this.cpu.pc = pc;
        this.notify('pc_changed', pc);
    }
};
