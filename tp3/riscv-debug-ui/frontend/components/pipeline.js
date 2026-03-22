/**
 * components/pipeline.js
 */
window.PipelineComponent = {
    init() {
        this.container = document.getElementById('pipeline-container');
        this.fallbackStages = ["Global", "IF/ID", "ID/EX", "EX/MEM", "MEM/WB"];
        this.defaultOpenStages = ["Global", "IF/ID", "ID/EX", "EX/MEM", "MEM/WB"];
        this.updatePipeline({
            valid: false,
            stage_order: this.fallbackStages,
            stages: {
                Global: {
                    estado: 'Esperando dump de latches'
                }
            }
        });
    },

    updatePipeline(data) {
        if (!this.container) return;
        this.container.innerHTML = '';

        const stages = data?.stages || {};
        const orderedStages = Array.isArray(data?.stage_order) && data.stage_order.length
            ? data.stage_order
            : (Object.keys(stages).length ? Object.keys(stages) : this.fallbackStages);

        orderedStages.forEach(stageName => {
            const payload = stages[stageName] || { estado: data?.valid === false ? 'No disponible' : 'Sin datos' };
            const isOpen = this.defaultOpenStages.includes(stageName) ? 'open' : '';

            let fieldsHtml = '';
            for (const [key, value] of Object.entries(payload)) {
                fieldsHtml += `
                    <div class="pipe-field">
                        <span class="pipe-field-label">${key}</span>
                        <span>${this.formatFieldValue(value)}</span>
                    </div>
                `;
            }

            const html = `
                <details class="pipe-stage" ${isOpen}>
                    <summary>${stageName}</summary>
                    <div class="pipe-content">
                        ${fieldsHtml}
                    </div>
                </details>
            `;
            
            // Append as element
            const template = document.createElement('template');
            template.innerHTML = html.trim();
            this.container.appendChild(template.content.firstChild);
        });
    },

    formatFieldValue(value) {
        if (value === null || value === undefined) return '-';
        if (typeof value === 'boolean') return value ? 'true' : 'false';
        if (Array.isArray(value)) return value.join(', ');
        if (typeof value === 'object') return JSON.stringify(value);
        return String(value);
    }
};
