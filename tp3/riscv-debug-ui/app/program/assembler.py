class Assembler:
    def assemble(self, asm: str) -> list[int]:
        """
        Para este MVP, utilizamos un Pseudo-Assembler. 
        En implementaciones finales apuntará a un binario cross-compilador (ej riser-v gcc).
        """
        words = []
        for line in asm.split('\n'):
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('//') or line.endswith(':'):
                continue
            # Por defecto devolvemos la instruccion ADDI x0, x0, 0 (NOP = 0x00000013) en hex
            words.append(0x00000013)
        return words

assembler = Assembler()
