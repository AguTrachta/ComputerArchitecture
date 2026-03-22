window.MemoryComponent = {
    PAGE_SIZE: 32,   // words per page (128 bytes → ~0.13s at 9600 baud)
    currentPage: 0,
    totalPages: 32,  // will be updated from server response
    loading: false,

    init() {
        this.tableBody   = document.querySelector('#mem-table tbody');
        this.btnPrev     = document.getElementById('btn-mem-prev');
        this.btnNext     = document.getElementById('btn-mem-next');
        this.btnFirst    = document.getElementById('btn-mem-first');
        this.btnRefresh  = document.getElementById('btn-mem-refresh');
        this.pageLabel   = document.getElementById('mem-page-label');
        this.loadingOverlay = document.getElementById('mem-loading');
        this.progressText   = document.getElementById('mem-progress-text');

        this.btnPrev.addEventListener('click', () => this.goTo(this.currentPage - 1));
        this.btnNext.addEventListener('click', () => this.goTo(this.currentPage + 1));
        this.btnFirst.addEventListener('click', () => this.goTo(0));
        this.btnRefresh.addEventListener('click', () => this.goTo(this.currentPage));

        this._renderEmpty();
    },

    async goTo(page) {
        if (this.loading) return;
        const target = Math.max(0, Math.min(page, this.totalPages - 1));

        this._setLoading(true);
        try {
            const res = await Api.dumpMemory(target, this.PAGE_SIZE);
            if (res?.dump) {
                this.currentPage = res.page ?? target;
                this.totalPages  = res.total_pages ?? this.totalPages;
                this._updateControls();
                this._renderRows(res.dump.rows);
                ConsoleComponent.logSuccess(`Mem pag. ${this.currentPage + 1}/${this.totalPages} OK`);
            }
        } catch (err) {
            ConsoleComponent.logError(err.message);
        } finally {
            this._setLoading(false);
        }
    },

    updateFromWsEvent(dump) {
        // Called from WS mem_dump events (e.g. after a step that triggers auto-dump)
        // Just re-request current page to keep the UI in sync
        this.goTo(this.currentPage);
    },

    _setLoading(on) {
        this.loading = on;
        if (this.loadingOverlay) {
            this.loadingOverlay.style.display = on ? 'flex' : 'none';
        }
        if (this.progressText) {
            const bytes = this.PAGE_SIZE * 4;
            this.progressText.textContent = on
                ? `Recibiendo ${bytes} bytes…`
                : '';
        }
        [this.btnPrev, this.btnNext, this.btnFirst, this.btnRefresh].forEach(b => {
            if (b) b.disabled = on;
        });
    },

    _updateControls() {
        if (this.pageLabel) {
            this.pageLabel.textContent = `Pág ${this.currentPage + 1} / ${this.totalPages}`;
        }
        if (this.btnPrev)  this.btnPrev.disabled  = (this.currentPage <= 0) || this.loading;
        if (this.btnNext)  this.btnNext.disabled  = (this.currentPage >= this.totalPages - 1) || this.loading;
        if (this.btnFirst) this.btnFirst.disabled = (this.currentPage <= 0) || this.loading;
    },

    _renderRows(rows) {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '';
        (rows || []).forEach(row => {
            const vals = Array.isArray(row.values)
                ? row.values
                : ['--------', '--------', '--------', '--------'];

            const isNonZero = vals.some(v => v !== '0x00000000' && v !== '--------');
            const tr = document.createElement('tr');
            if (isNonZero) tr.classList.add('mem-row-nonzero');

            tr.innerHTML = `
                <td class="mem-addr">${row.address || '0x00000000'}</td>
                <td>${vals[0] || '--------'}</td>
                <td>${vals[1] || '--------'}</td>
                <td>${vals[2] || '--------'}</td>
                <td>${vals[3] || '--------'}</td>
            `;
            this.tableBody.appendChild(tr);
        });
    },

    _renderEmpty() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = `
            <tr class="mem-empty-row">
                <td colspan="5">Sin datos — presioná ▶ para leer la primera página</td>
            </tr>`;
        if (this.pageLabel) this.pageLabel.textContent = `Pág - / -`;
    },
};
