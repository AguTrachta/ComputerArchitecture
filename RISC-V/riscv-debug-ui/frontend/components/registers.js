window.RegistersComponent = {
    init() {
        this.tableBody = document.querySelector('#regs-table tbody');
        this.updateRegs(
            Array.from({ length: 32 }, (_, index) => ({
                name: `x${index}`,
                hex: '0x00000000',
                dec: 0
            }))
        );
    },

    updateRegs(registers) {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '';

        registers.forEach((reg) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${reg.name}</strong></td>
                <td class="code-text">${reg.hex}</td>
                <td>${reg.dec}</td>
            `;
            this.tableBody.appendChild(tr);
        });
    }
};
