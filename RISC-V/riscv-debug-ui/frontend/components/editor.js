window.EditorComponent = {
    init() {
        this.asmEditor = document.getElementById('asm-editor');
        this.btnValidate = document.getElementById('btn-validate');
        this.btnTranslate = document.getElementById('btn-translate');
        this.hexOutput = document.getElementById('hex-output');
        this.hexViewer = document.getElementById('hex-viewer');

        this.btnValidate.addEventListener('click', async () => {
            const asm = this.asmEditor.value;
            if (!asm.trim()) return;

            try {
                const res = await Api.validateProgram(asm);
                if (res.errors?.length) {
                    ConsoleComponent.logError(res.errors.join(' | '));
                    return;
                }

                ConsoleComponent.logInfo(
                    `Programa valido: ${res.inst_count} instrucciones, ${res.imem_usage}/${res.imem_limit} bytes.`
                );

                if (res.warnings?.length) {
                    ConsoleComponent.logWarn(res.warnings.join(' | '));
                }
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.btnTranslate.addEventListener('click', async () => {
            const asm = this.asmEditor.value;
            if (!asm.trim()) return;

            try {
                const res = await Api.assembleProgram(asm);
                this.hexOutput.textContent = res.hex;
                this.hexViewer.open = true;
                ConsoleComponent.logInfo(`Traducido a HEX (${res.inst_count} words, ${res.imem_usage} bytes).`);
            } catch (error) {
                ConsoleComponent.logError(error.message);
            }
        });

        this.asmEditor.value = `main:
    addi x1, x0, 5
    addi x2, x0, 7
    add x3, x1, x2
    sub x4, x3, x1
    halt`;
    }
};
