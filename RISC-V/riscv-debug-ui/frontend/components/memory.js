window.MemoryComponent = {
    PAGE_SIZE: 32,
    currentPage: 0,
    totalPages: 32,
    loading: false,

    init() {
        this.tableBody = document.querySelector('#mem-table tbody');
        this.btnPrev = document.getElementById('btn-mem-prev');
        this.btnNext = document.getElementById('btn-mem-next');
        this.btnFirst = document.getElementById('btn-mem-first');
        this.btnRefresh = document.getElementById('btn-mem-refresh');
        this.pageLabel = document.getElementById('mem-page-label');
        this.loadingOverlay = document.getElementById('mem-loading');
        this.progressText = document.getElementById('mem-progress-text');

        this.btnPrev.addEventListener('click', () => this.goTo(this.currentPage - 1));
        this.btnNext.addEventListener('click', () => this.goTo(this.currentPage + 1));
        this.btnFirst.addEventListener('click', () => this.goTo(0));
        this.btnRefresh.addEventListener('click', () => this.goTo(this.currentPage));

        AppState.subscribe((event) => {
            if (['connection_changed', 'cpu_state_changed', 'capabilities_changed', 'status_synced'].includes(event)) {
                this._updateControls();
            }
        });

        this._renderEmpty();
        this._updateControls();
    },

    async goTo(page) {
        if (this.loading || !this._canRequestDump()) return;

        const target = Math.max(0, Math.min(page, this.totalPages - 1));

        this._setLoading(true);
        try {
            const res = await Api.dumpMemory(target, this.PAGE_SIZE);
            if (res?.dump) {
                this.updateMemory(res.dump, {
                    page: res.page ?? target,
                    totalPages: res.total_pages ?? this.totalPages
                });
                ConsoleComponent.logSuccess(`Mem pag. ${this.currentPage + 1}/${this.totalPages} OK`);
            }
        } catch (err) {
            ConsoleComponent.logError(err.message);
        } finally {
            this._setLoading(false);
        }
    },

    updateFromWsEvent(dump) {
        this.updateMemory(dump);
    },

    updateMemory(dump, { page, totalPages } = {}) {
        if (typeof page === 'number') {
            this.currentPage = page;
        }
        if (typeof totalPages === 'number' && totalPages > 0) {
            this.totalPages = totalPages;
        }

        this._updateControls();

        if (dump?.rows?.length) {
            this._renderRows(dump.rows);
            return;
        }

        this._renderEmpty();
    },

    _setLoading(on) {
        this.loading = on;
        if (this.loadingOverlay) {
            this.loadingOverlay.style.display = on ? 'flex' : 'none';
        }
        if (this.progressText) {
            const bytes = this.PAGE_SIZE * 4;
            this.progressText.textContent = on ? `Recibiendo ${bytes} bytes...` : '';
        }
        this._updateControls();
    },

    _updateControls() {
        const canRequestDump = this._canRequestDump();

        if (this.pageLabel) {
            this.pageLabel.textContent = `Pag ${this.currentPage + 1} / ${this.totalPages}`;
        }

        if (this.btnPrev) this.btnPrev.disabled = !canRequestDump || this.loading || this.currentPage <= 0;
        if (this.btnNext) this.btnNext.disabled = !canRequestDump || this.loading || this.currentPage >= this.totalPages - 1;
        if (this.btnFirst) this.btnFirst.disabled = !canRequestDump || this.loading || this.currentPage <= 0;
        if (this.btnRefresh) this.btnRefresh.disabled = !canRequestDump || this.loading;
    },

    _canRequestDump() {
        const connected = Boolean(AppState?.connection?.connected);
        const canDump = Boolean(AppState?.capabilities?.can_dump_memory);
        const state = AppState?.cpu?.state || 'DISCONNECTED';
        return connected && canDump && !['RUNNING', 'PROGRAMMING', 'STEPPING', 'DUMPING'].includes(state);
    },

    _renderRows(rows) {
        if (!this.tableBody) return;

        this.tableBody.innerHTML = '';
        (rows || []).forEach((row) => {
            const vals = Array.isArray(row.values)
                ? row.values
                : ['--------', '--------', '--------', '--------'];

            const isNonZero = vals.some((value) => value !== '0x00000000' && value !== '--------');
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
                <td colspan="5">Sin datos - usa los controles de pagina para leer memoria</td>
            </tr>`;
        if (this.pageLabel) this.pageLabel.textContent = 'Pag - / -';
    }
};
