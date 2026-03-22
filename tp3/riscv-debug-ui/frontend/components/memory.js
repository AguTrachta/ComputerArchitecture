window.MemoryComponent = {
    init() {
        this.tableBody = document.querySelector('#mem-table tbody');
        this.btnRead = document.getElementById('btn-read-mem');
        this.inputOffset = document.getElementById('mem-offset');

        this.btnRead.addEventListener('click', async () => {
            const parsedOffset = parseInt(this.inputOffset.value || '0', 0);
            const offset = Number.isNaN(parsedOffset) ? 0 : parsedOffset;

            try {
                const res = await Api.dumpMemory(offset);
                if (res.dump) {
                    this.updateMemory(res.dump);
                }
                ConsoleComponent.logInfo(res.message);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.updateMemory({
            valid: false,
            rows: [
                { address: '0x00000000', values: ['--------', '--------', '--------', '--------'] }
            ]
        });
    },

    updateMemory(dump) {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '';

        const rows = dump?.rows || [];
        rows.forEach((row) => {
            const values = Array.isArray(row.values) ? row.values : ['--------', '--------', '--------', '--------'];
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>${row.address || '0x00000000'}</td>
                <td>${values[0] || '--------'}</td>
                <td>${values[1] || '--------'}</td>
                <td>${values[2] || '--------'}</td>
                <td>${values[3] || '--------'}</td>
            `;
            this.tableBody.appendChild(tr);
        });
    }
};
