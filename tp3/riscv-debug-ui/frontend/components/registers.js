/**
 * components/registers.js
 */
window.RegistersComponent = {
    init() {
        this.tableBody = document.querySelector('#regs-table tbody');
        // Initial mock data
        this.updateRegs([
            { name: "x0", alias: "zero", hex: "0x00000000", dec: 0 },
            { name: "x1", alias: "ra", hex: "0x00000000", dec: 0 }
        ]);
    },

    updateRegs(registers) {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '';
        
        registers.forEach(reg => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${reg.name}</strong></td>
                <td>${reg.alias}</td>
                <td class="code-text">${reg.hex}</td>
                <td>${reg.dec}</td>
            `;
            this.tableBody.appendChild(tr);
        });
    }
};
