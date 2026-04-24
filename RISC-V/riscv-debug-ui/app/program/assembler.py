from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


REGISTER_NAMES = {
    **{f"x{i}": i for i in range(32)},
}

R_TYPE = {
    "add": (0x00, 0x0),
    "sub": (0x20, 0x0),
    "sll": (0x00, 0x1),
    "slt": (0x00, 0x2),
    "sltu": (0x00, 0x3),
    "xor": (0x00, 0x4),
    "srl": (0x00, 0x5),
    "sra": (0x20, 0x5),
    "or": (0x00, 0x6),
    "and": (0x00, 0x7),
}

I_TYPE_ARITH = {
    "addi": 0x0,
    "slti": 0x2,
    "sltiu": 0x3,
    "xori": 0x4,
    "ori": 0x6,
    "andi": 0x7,
}

I_TYPE_SHIFT = {
    "slli": (0x00, 0x1),
    "srli": (0x00, 0x5),
    "srai": (0x20, 0x5),
}

LOADS = {
    "lb": 0x0,
    "lh": 0x1,
    "lw": 0x2,
    "lbu": 0x4,
    "lhu": 0x5,
}

STORES = {
    "sb": 0x0,
    "sh": 0x1,
    "sw": 0x2,
}

BRANCHES = {
    "beq": 0x0,
    "bne": 0x1,
    "blt": 0x4,
    "bge": 0x5,
    "bltu": 0x6,
    "bgeu": 0x7,
}

MEMORY_OPERAND_RE = re.compile(r"^(?P<imm>[-+]?(?:0[xX][0-9A-Fa-f]+|0[bB][01]+|\d+))\((?P<base>[A-Za-z0-9_]+)\)$")


class AssemblerError(ValueError):
    def __init__(self, errors: list[str]):
        super().__init__("\n".join(errors))
        self.errors = errors


@dataclass(slots=True)
class ParsedInstruction:
    line_no: int
    mnemonic: str
    operands: list[str]
    address: int
    source: str


@dataclass(slots=True)
class AssemblyResult:
    words: list[int]
    warnings: list[str]

    @property
    def hex_lines(self) -> str:
        return "\n".join(f"{index * 4:08x}: {word:08x}" for index, word in enumerate(self.words))


@dataclass(slots=True)
class ToolchainConfig:
    gcc: str
    objcopy: str


class Assembler:
    max_words = 1024
    gcc_candidates = (
        "riscv32-unknown-elf-gcc",
        "riscv64-unknown-elf-gcc",
        "riscv32-none-elf-gcc",
        "riscv64-none-elf-gcc",
    )
    objcopy_candidates = (
        "riscv32-unknown-elf-objcopy",
        "riscv64-unknown-elf-objcopy",
        "riscv32-none-elf-objcopy",
        "riscv64-none-elf-objcopy",
        "objcopy",
    )

    def __init__(self) -> None:
        self.toolchain = self._detect_toolchain()

    def validate(self, asm: str) -> AssemblyResult:
        return self.assemble(asm)

    def assemble(self, asm: str) -> AssemblyResult:
        if self.toolchain is not None:
            return self._assemble_with_gnu_toolchain(asm)
        return self._assemble_builtin(asm)

    def _assemble_builtin(self, asm: str) -> AssemblyResult:
        cleaned_lines = self._preprocess(asm)
        labels, instructions = self._first_pass(cleaned_lines)
        words = [self._encode_instruction(instruction, labels) for instruction in instructions]

        return self._build_result(words)

    def _build_result(self, words: list[int]) -> AssemblyResult:
        warnings: list[str] = []
        if len(words) > self.max_words:
            warnings.append(
                f"El programa ocupa {len(words)} instrucciones y excede el limite de IMEM de {self.max_words}."
            )

        return AssemblyResult(words=words, warnings=warnings)

    def _detect_toolchain(self) -> ToolchainConfig | None:
        gcc = self._resolve_command("RISCV_GNU_GCC", self.gcc_candidates)
        objcopy = self._resolve_command("RISCV_OBJCOPY", self.objcopy_candidates)
        if gcc and objcopy:
            return ToolchainConfig(gcc=gcc, objcopy=objcopy)
        return None

    def _resolve_command(self, env_var: str, candidates: tuple[str, ...]) -> str | None:
        override = os.getenv(env_var)
        if override:
            return override

        for candidate in candidates:
            resolved = shutil.which(candidate)
            if resolved:
                return resolved

        return None

    def _assemble_with_gnu_toolchain(self, asm: str) -> AssemblyResult:
        source = self._prepare_source_for_external(asm)

        with tempfile.TemporaryDirectory(prefix="riscv-debug-ui-asm-") as tmpdir:
            tmp_path = Path(tmpdir)
            source_path = tmp_path / "program.S"
            object_path = tmp_path / "program.o"
            binary_path = tmp_path / "program.bin"
            source_path.write_text(source, encoding="utf-8", newline="\n")

            compile_cmd = [
                self.toolchain.gcc,
                "-march=rv32i",
                "-mabi=ilp32",
                "-nostdlib",
                "-x",
                "assembler",
                "-c",
                str(source_path),
                "-o",
                str(object_path),
            ]
            compile_result = subprocess.run(
                compile_cmd,
                capture_output=True,
                text=True,
                check=False,
                timeout=15,
            )
            if compile_result.returncode != 0:
                raise AssemblerError([self._format_toolchain_error("gcc", compile_result)])

            objcopy_cmd = [
                self.toolchain.objcopy,
                "-O",
                "binary",
                "--only-section=.text",
                str(object_path),
                str(binary_path),
            ]
            objcopy_result = subprocess.run(
                objcopy_cmd,
                capture_output=True,
                text=True,
                check=False,
                timeout=15,
            )
            if objcopy_result.returncode != 0:
                raise AssemblerError([self._format_toolchain_error("objcopy", objcopy_result)])

            raw = binary_path.read_bytes()
            if len(raw) % 4 != 0:
                raise AssemblerError(
                    [f"La salida binaria del toolchain GNU tiene {len(raw)} bytes y no es multiplo de 4."]
                )

            words = [
                int.from_bytes(raw[offset : offset + 4], byteorder="little", signed=False)
                for offset in range(0, len(raw), 4)
            ]
            return self._build_result(words)

    def _prepare_source_for_external(self, asm: str) -> str:
        lines = []
        halt_pattern = re.compile(
            r"^(\s*(?:[A-Za-z_][A-Za-z0-9_]*:\s*)?)halt(\s*(?://.*|[#;].*))?$",
            re.IGNORECASE,
        )

        for raw_line in asm.splitlines():
            converted = halt_pattern.sub(r"\1.word 0xFFFFFFFF\2", raw_line)
            lines.append(converted)

        return ".option norvc\n.text\n" + "\n".join(lines) + "\n"

    def _format_toolchain_error(self, tool_name: str, result: subprocess.CompletedProcess[str]) -> str:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        detail = stderr or stdout or f"{tool_name} termino con codigo {result.returncode}."
        return f"Fallo el backend GNU ({tool_name}): {detail}"

    def _preprocess(self, asm: str) -> list[tuple[int, str]]:
        result: list[tuple[int, str]] = []
        for line_no, raw_line in enumerate(asm.splitlines(), start=1):
            line = raw_line.split("//", 1)[0]
            line = line.split("#", 1)[0]
            line = line.split(";", 1)[0]
            line = line.strip()
            if line:
                result.append((line_no, line))
        return result

    def _first_pass(self, lines: list[tuple[int, str]]) -> tuple[dict[str, int], list[ParsedInstruction]]:
        labels: dict[str, int] = {}
        instructions: list[ParsedInstruction] = []
        address = 0

        for line_no, line in lines:
            rest = line
            while ":" in rest:
                label, remainder = rest.split(":", 1)
                label_name = label.strip()
                if not label_name:
                    raise AssemblerError([f"Linea {line_no}: etiqueta vacia."])
                if label_name in labels:
                    raise AssemblerError([f"Linea {line_no}: la etiqueta '{label_name}' esta repetida."])
                labels[label_name] = address
                rest = remainder.strip()
                if not rest:
                    break

            if not rest:
                continue

            parts = rest.split(None, 1)
            mnemonic = parts[0].lower()
            operands = []
            if len(parts) == 2:
                operands = [operand.strip() for operand in parts[1].split(",") if operand.strip()]

            instructions.append(
                ParsedInstruction(
                    line_no=line_no,
                    mnemonic=mnemonic,
                    operands=operands,
                    address=address,
                    source=line,
                )
            )
            address += 4

        return labels, instructions

    def _encode_instruction(self, instruction: ParsedInstruction, labels: dict[str, int]) -> int:
        mnemonic = instruction.mnemonic
        operands = instruction.operands

        if mnemonic == ".word":
            self._require_operand_count(instruction, 1)
            return self._parse_immediate(operands[0], instruction.line_no) & 0xFFFFFFFF

        if mnemonic == "nop":
            return self._encode_i(0x13, 0x0, 0, 0, 0)

        if mnemonic == "halt":
            return 0xFFFFFFFF

        if mnemonic == "mv":
            self._require_operand_count(instruction, 2)
            rd = self._parse_register(operands[0], instruction.line_no)
            rs = self._parse_register(operands[1], instruction.line_no)
            return self._encode_i(0x13, 0x0, rd, rs, 0)

        if mnemonic == "j":
            self._require_operand_count(instruction, 1)
            offset = self._resolve_branch_target(operands[0], labels, instruction.address, instruction.line_no)
            return self._encode_j(0x6F, 0, offset, instruction.line_no)

        if mnemonic == "jr":
            self._require_operand_count(instruction, 1)
            rs1 = self._parse_register(operands[0], instruction.line_no)
            return self._encode_i(0x67, 0x0, 0, rs1, 0)

        if mnemonic == "ret":
            return self._encode_i(0x67, 0x0, 0, 1, 0)

        if mnemonic in R_TYPE:
            self._require_operand_count(instruction, 3)
            rd = self._parse_register(operands[0], instruction.line_no)
            rs1 = self._parse_register(operands[1], instruction.line_no)
            rs2 = self._parse_register(operands[2], instruction.line_no)
            funct7, funct3 = R_TYPE[mnemonic]
            return self._encode_r(0x33, funct3, funct7, rd, rs1, rs2)

        if mnemonic in I_TYPE_ARITH:
            self._require_operand_count(instruction, 3)
            rd = self._parse_register(operands[0], instruction.line_no)
            rs1 = self._parse_register(operands[1], instruction.line_no)
            imm = self._parse_immediate(operands[2], instruction.line_no)
            return self._encode_i(0x13, I_TYPE_ARITH[mnemonic], rd, rs1, imm, instruction.line_no)

        if mnemonic in I_TYPE_SHIFT:
            self._require_operand_count(instruction, 3)
            rd = self._parse_register(operands[0], instruction.line_no)
            rs1 = self._parse_register(operands[1], instruction.line_no)
            shamt = self._parse_immediate(operands[2], instruction.line_no)
            funct7, funct3 = I_TYPE_SHIFT[mnemonic]
            if shamt < 0 or shamt > 31:
                raise AssemblerError([f"Linea {instruction.line_no}: shamt fuera de rango (0..31)."])
            imm = (funct7 << 5) | shamt
            return self._encode_i(0x13, funct3, rd, rs1, imm, instruction.line_no, signed=False)

        if mnemonic in LOADS:
            self._require_operand_count(instruction, 2)
            rd = self._parse_register(operands[0], instruction.line_no)
            imm, rs1 = self._parse_memory_operand(operands[1], instruction.line_no)
            return self._encode_i(0x03, LOADS[mnemonic], rd, rs1, imm, instruction.line_no)

        if mnemonic in STORES:
            self._require_operand_count(instruction, 2)
            rs2 = self._parse_register(operands[0], instruction.line_no)
            imm, rs1 = self._parse_memory_operand(operands[1], instruction.line_no)
            return self._encode_s(0x23, STORES[mnemonic], rs1, rs2, imm, instruction.line_no)

        if mnemonic in BRANCHES:
            self._require_operand_count(instruction, 3)
            rs1 = self._parse_register(operands[0], instruction.line_no)
            rs2 = self._parse_register(operands[1], instruction.line_no)
            offset = self._resolve_branch_target(operands[2], labels, instruction.address, instruction.line_no)
            return self._encode_b(0x63, BRANCHES[mnemonic], rs1, rs2, offset, instruction.line_no)

        if mnemonic == "lui":
            self._require_operand_count(instruction, 2)
            rd = self._parse_register(operands[0], instruction.line_no)
            imm = self._parse_immediate(operands[1], instruction.line_no)
            if imm < 0 or imm > 0xFFFFF:
                raise AssemblerError([f"Linea {instruction.line_no}: inmediato U-type fuera de rango (0..0xFFFFF)."])
            return self._encode_u(0x37, rd, imm)

        if mnemonic == "auipc":
            self._require_operand_count(instruction, 2)
            rd = self._parse_register(operands[0], instruction.line_no)
            imm = self._parse_immediate(operands[1], instruction.line_no)
            if imm < 0 or imm > 0xFFFFF:
                raise AssemblerError([f"Linea {instruction.line_no}: inmediato U-type fuera de rango (0..0xFFFFF)."])
            return self._encode_u(0x17, rd, imm)

        if mnemonic == "jal":
            if len(operands) == 1:
                rd = 1
                target = operands[0]
            elif len(operands) == 2:
                rd = self._parse_register(operands[0], instruction.line_no)
                target = operands[1]
            else:
                self._require_operand_count(instruction, 1)
                raise AssertionError("unreachable")
            offset = self._resolve_branch_target(target, labels, instruction.address, instruction.line_no)
            return self._encode_j(0x6F, rd, offset, instruction.line_no)

        if mnemonic == "jalr":
            if len(operands) == 2:
                rd = 1
                mem_operand = operands[1]
                if "(" in operands[1]:
                    rd = self._parse_register(operands[0], instruction.line_no)
                    imm, rs1 = self._parse_memory_operand(mem_operand, instruction.line_no)
                else:
                    rs1 = self._parse_register(operands[1], instruction.line_no)
                    rd = self._parse_register(operands[0], instruction.line_no)
                    imm = 0
            elif len(operands) == 3:
                rd = self._parse_register(operands[0], instruction.line_no)
                if "(" in operands[1]:
                    raise AssemblerError(
                        [f"Linea {instruction.line_no}: usa 'jalr rd, imm(rs1)' o 'jalr rd, rs1, imm'."]
                    )
                rs1 = self._parse_register(operands[1], instruction.line_no)
                imm = self._parse_immediate(operands[2], instruction.line_no)
            else:
                raise AssemblerError([f"Linea {instruction.line_no}: cantidad de operandos invalida para 'jalr'."])
            return self._encode_i(0x67, 0x0, rd, rs1, imm, instruction.line_no)

        raise AssemblerError([f"Linea {instruction.line_no}: instruccion no soportada '{mnemonic}'."])

    def _parse_register(self, token: str, line_no: int) -> int:
        key = token.strip().lower()
        if key not in REGISTER_NAMES:
            raise AssemblerError([f"Linea {line_no}: registro desconocido '{token}'. Usa x0..x31."])
        return REGISTER_NAMES[key]

    def _parse_immediate(self, token: str, line_no: int) -> int:
        try:
            return int(token, 0)
        except ValueError as exc:
            raise AssemblerError([f"Linea {line_no}: inmediato invalido '{token}'."]) from exc

    def _parse_memory_operand(self, token: str, line_no: int) -> tuple[int, int]:
        match = MEMORY_OPERAND_RE.match(token.replace(" ", ""))
        if not match:
            raise AssemblerError([f"Linea {line_no}: operando de memoria invalido '{token}'."])
        imm = self._parse_immediate(match.group("imm"), line_no)
        base = self._parse_register(match.group("base"), line_no)
        return imm, base

    def _resolve_branch_target(
        self, token: str, labels: dict[str, int], current_address: int, line_no: int
    ) -> int:
        if token in labels:
            return labels[token] - current_address
        return self._parse_immediate(token, line_no)

    def _require_operand_count(self, instruction: ParsedInstruction, expected: int) -> None:
        if len(instruction.operands) != expected:
            raise AssemblerError(
                [
                    f"Linea {instruction.line_no}: '{instruction.mnemonic}' esperaba {expected} operandos "
                    f"y recibio {len(instruction.operands)}."
                ]
            )

    def _encode_r(self, opcode: int, funct3: int, funct7: int, rd: int, rs1: int, rs2: int) -> int:
        return (
            ((funct7 & 0x7F) << 25)
            | ((rs2 & 0x1F) << 20)
            | ((rs1 & 0x1F) << 15)
            | ((funct3 & 0x7) << 12)
            | ((rd & 0x1F) << 7)
            | (opcode & 0x7F)
        )

    def _encode_i(
        self,
        opcode: int,
        funct3: int,
        rd: int,
        rs1: int,
        imm: int,
        line_no: int | None = None,
        *,
        signed: bool = True,
    ) -> int:
        if signed:
            self._validate_signed_range(imm, 12, line_no)
        elif imm < 0 or imm > 0xFFF:
            raise AssemblerError([f"Linea {line_no}: inmediato fuera de rango (0..4095)."])

        imm12 = imm & 0xFFF
        return (
            (imm12 << 20)
            | ((rs1 & 0x1F) << 15)
            | ((funct3 & 0x7) << 12)
            | ((rd & 0x1F) << 7)
            | (opcode & 0x7F)
        )

    def _encode_s(self, opcode: int, funct3: int, rs1: int, rs2: int, imm: int, line_no: int) -> int:
        self._validate_signed_range(imm, 12, line_no)
        imm12 = imm & 0xFFF
        return (
            (((imm12 >> 5) & 0x7F) << 25)
            | ((rs2 & 0x1F) << 20)
            | ((rs1 & 0x1F) << 15)
            | ((funct3 & 0x7) << 12)
            | ((imm12 & 0x1F) << 7)
            | (opcode & 0x7F)
        )

    def _encode_b(self, opcode: int, funct3: int, rs1: int, rs2: int, offset: int, line_no: int) -> int:
        self._validate_branch_offset(offset, 13, line_no)
        imm = offset & 0x1FFF
        bit12 = (imm >> 12) & 0x1
        bit11 = (imm >> 11) & 0x1
        bits10_5 = (imm >> 5) & 0x3F
        bits4_1 = (imm >> 1) & 0xF
        return (
            (bit12 << 31)
            | (bits10_5 << 25)
            | ((rs2 & 0x1F) << 20)
            | ((rs1 & 0x1F) << 15)
            | ((funct3 & 0x7) << 12)
            | (bits4_1 << 8)
            | (bit11 << 7)
            | (opcode & 0x7F)
        )

    def _encode_u(self, opcode: int, rd: int, imm20: int) -> int:
        return ((imm20 & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

    def _encode_j(self, opcode: int, rd: int, offset: int, line_no: int) -> int:
        self._validate_branch_offset(offset, 21, line_no)
        imm = offset & 0x1FFFFF
        bit20 = (imm >> 20) & 0x1
        bits10_1 = (imm >> 1) & 0x3FF
        bit11 = (imm >> 11) & 0x1
        bits19_12 = (imm >> 12) & 0xFF
        return (
            (bit20 << 31)
            | (bits10_1 << 21)
            | (bit11 << 20)
            | (bits19_12 << 12)
            | ((rd & 0x1F) << 7)
            | (opcode & 0x7F)
        )

    def _validate_signed_range(self, value: int, bits: int, line_no: int | None) -> None:
        lower_bound = -(1 << (bits - 1))
        upper_bound = (1 << (bits - 1)) - 1
        if value < lower_bound or value > upper_bound:
            raise AssemblerError([f"Linea {line_no}: inmediato fuera de rango ({lower_bound}..{upper_bound})."])

    def _validate_branch_offset(self, value: int, bits: int, line_no: int) -> None:
        if value % 2 != 0:
            raise AssemblerError([f"Linea {line_no}: el offset debe ser multiplo de 2."])
        lower_bound = -(1 << (bits - 1))
        upper_bound = (1 << (bits - 1)) - 1
        if value < lower_bound or value > upper_bound:
            raise AssemblerError(
                [f"Linea {line_no}: offset fuera de rango para {bits} bits ({lower_bound}..{upper_bound})."]
            )


assembler = Assembler()
