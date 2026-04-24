/**
 * components/console.js
 */
window.ConsoleComponent = {
    init() {
        this.output = document.getElementById('console-output');
        this.input = document.getElementById('console-input');
        this.btnSend = document.getElementById('btn-console-send');

        this.btnSend.addEventListener('click', () => {
            const text = this.input.value;
            if (text.trim()) {
                this.logTx(text);
                this.input.value = '';
            }
        });
    },

    appendLog(msg, typeClass) {
        if (!this.output) return;
        const div = document.createElement('div');
        div.className = `log-entry ${typeClass}`;
        div.textContent = `[${new Date().toLocaleTimeString()}] ${msg}`;
        this.output.appendChild(div);
        this.output.scrollTop = this.output.scrollHeight;
    },

    logInfo(msg) { this.appendLog(`INFO: ${msg}`, 'info'); },
    logWarn(msg) { this.appendLog(`WARN: ${msg}`, 'warn'); },
    logError(msg) { this.appendLog(`ERROR: ${msg}`, 'error'); },
    logSuccess(msg) { this.appendLog(`OK: ${msg}`, 'success'); },
    logTx(msg) { this.appendLog(`TX: ${msg}`, 'tx'); },
    logRx(msg) { this.appendLog(`RX: ${msg}`, 'rx'); }
};
