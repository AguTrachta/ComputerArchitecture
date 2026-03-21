/**
 * components/editor.js
 */
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
            const res = await Api.validateProgram(asm);
            ConsoleComponent.logInfo(`Programa válido: ${res.instCount} instrucciones.`);
        });

        this.btnTranslate.addEventListener('click', async () => {
            const asm = this.asmEditor.value;
            if (!asm.trim()) return;
            const res = await Api.assembleProgram(asm);
            this.hexOutput.textContent = res.hex;
            this.hexViewer.open = true; // Auto open details
            ConsoleComponent.logInfo(`Traducido a HEX (${res.hex.split('\n').length} words).`);
        });
        
        // Let's populate some mock ASM
        this.asmEditor.value = `main:
    add x1, x0, 5
    addi x2, x0, 10
    jal x3, target
    nop
target:
    sub x4, x2, x1`;
    }
};
