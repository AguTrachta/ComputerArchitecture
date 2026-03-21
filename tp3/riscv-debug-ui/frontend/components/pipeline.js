/**
 * components/pipeline.js
 */
window.PipelineComponent = {
    init() {
        this.container = document.getElementById('pipeline-container');
        // Define all pipeline stages in order requested by user
        this.orderedStages = [
            "Global",
            "IF",
            "IF/ID",
            "ID",
            "ID/EX",
            "EX",
            "EX/MEM",
            "MEM",
            "MEM/WB",
            "WB"
        ];
        
        // Define which ones should be opened by default
        this.defaultOpenStages = ["Global", "IF/ID", "ID/EX", "EX/MEM", "MEM/WB"];
    },

    updatePipeline(data) {
        if (!this.container) return;
        this.container.innerHTML = '';

        const stages = data.stages || {};
        
        this.orderedStages.forEach(stageName => {
            const payload = stages[stageName] || { "estado": "N/A" };
            
            const isOpen = this.defaultOpenStages.includes(stageName) ? 'open' : '';
            
            let fieldsHtml = '';
            for (const [key, value] of Object.entries(payload)) {
                fieldsHtml += `
                    <div class="pipe-field">
                        <span class="pipe-field-label">${key}</span>
                        <span>${value}</span>
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
    }
};
