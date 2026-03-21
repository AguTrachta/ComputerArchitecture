/**
 * components/memory.js
 */
window.MemoryComponent = {
    init() {
        this.tableBody = document.querySelector('#mem-table tbody');
        this.btnRead = document.getElementById('btn-read-mem');
        this.inputOffset = document.getElementById('mem-offset');

        this.btnRead.addEventListener('click', async () => {
            await Api.dumpMemory();
            ConsoleComponent.logTx(`CMD_DUMP_MEM ${this.inputOffset.value || '0x000'}`);
            this.generateMockMem();
        });
        
        this.generateMockMem();
    },

    generateMockMem() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '';
        
        let startAddr = parseInt(this.inputOffset.value || '0', 16);
        if (isNaN(startAddr)) startAddr = 0;

        for (let i = 0; i < 8; i++) {
            const rowAddr = (startAddr + i * 16).toString(16).padStart(8, '0');
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>0x${rowAddr}</td>
                <td>00000000</td>
                <td>00000000</td>
                <td>00000000</td>
                <td>00000000</td>
            `;
            this.tableBody.appendChild(tr);
        }
    }
};
