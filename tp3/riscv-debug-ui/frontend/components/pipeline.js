window.PipelineComponent = {
    init() {
        this.container = document.getElementById('pipeline-container');
        this.fallbackStages = [
            "Global",
            "IF/ID",
            "ID/EX",
            "EX/MEM",
            "MEM/WB",
            "Forwarding",
            "WB (Commit)"
        ];

        this.updatePipeline({
            valid: false,
            stage_order: this.fallbackStages,
            stages: {
                Global: {
                    estado: "Esperando dump de latches"
                }
            }
        });
    },

    updatePipeline(data = {}) {
        if (!this.container) return;

        this.container.innerHTML = "";

        const stages = data.stages || {};
        const orderedStages =
            Array.isArray(data.stage_order) && data.stage_order.length
                ? data.stage_order
                : (Object.keys(stages).length ? Object.keys(stages) : this.fallbackStages);

        const fragment = document.createDocumentFragment();

        orderedStages.forEach(stageName => {
            const payload = stages[stageName] || {
                estado: data.valid === false ? "No disponible" : "Sin datos"
            };

            const section = document.createElement("section");
            section.className = "pipe-stage";
            section.setAttribute("aria-label", stageName);

            const title = document.createElement("div");
            title.className = "pipe-stage-title";
            title.textContent = stageName;

            const content = document.createElement("div");
            content.className = "pipe-content";

            Object.entries(payload).forEach(([key, value]) => {
                const field = document.createElement("div");
                field.className = "pipe-field";

                const label = document.createElement("span");
                label.className = "pipe-field-label";
                label.textContent = key;

                const valueNode = document.createElement("span");
                valueNode.className = "pipe-field-value";
                valueNode.textContent = this.formatFieldValue(value);

                field.appendChild(label);
                field.appendChild(valueNode);
                content.appendChild(field);
            });

            section.appendChild(title);
            section.appendChild(content);
            fragment.appendChild(section);
        });

        this.container.appendChild(fragment);
    },

    formatFieldValue(value) {
        if (value === null || value === undefined) return "-";
        if (typeof value === "boolean") return value ? "true" : "false";
        if (Array.isArray(value)) return value.join(", ");
        if (typeof value === "object") return JSON.stringify(value);
        return String(value);
    }
};