from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Any

from app.core.events import build_event, publish_event
from app.core.state import session_state
from app.models.dumps import (
    MemoryDumpPayload,
    MemoryDumpRow,
    PipelineDumpPayload,
    RegisterValue,
    RegistersDumpPayload,
)
from app.serial.serial_manager import serial_manager


REGISTER_ALIASES = (
    "zero",
    "ra",
    "sp",
    "gp",
    "tp",
    "t0",
    "t1",
    "t2",
    "s0",
    "s1",
    "a0",
    "a1",
    "a2",
    "a3",
    "a4",
    "a5",
    "a6",
    "a7",
    "s2",
    "s3",
    "s4",
    "s5",
    "s6",
    "s7",
    "s8",
    "s9",
    "s10",
    "s11",
    "t3",
    "t4",
    "t5",
    "t6",
)

ALU_OP_NAMES = {
    0b100000: "ADD",
    0b100010: "SUB",
    0b100100: "AND",
    0b100101: "OR",
    0b100110: "XOR",
    0b000011: "SRA",
    0b000010: "SRL",
    0b000001: "SLL",
    0b101010: "SLT",
    0b101011: "SLTU",
    0b001111: "LUI",
}

PIPELINE_STAGE_ORDER = ("Global", "IF/ID", "ID/EX", "EX/MEM", "MEM/WB")


@dataclass(slots=True)
class ParsedFrame:
    kind: str
    text: str
    raw_bytes: list[str]
    payload: Any = None


@dataclass(slots=True)
class PendingWaiter:
    kinds: set[str]
    future: asyncio.Future


class ProtocolManager:
    PIPELINE_DUMP_WORD_COUNT = 25
    MEMORY_DUMP_WORD_COUNT = 1024
    MEMORY_ROWS_PER_RESPONSE = 8

    CMD_PROG_BEGIN = 0x10
    CMD_PROG_END = 0x11
    CMD_RUN = 0x20
    CMD_STEP = 0x21
    CMD_STOP = 0x22
    CMD_DUMP_REGS = 0x30
    CMD_DUMP_PIPE = 0x31
    CMD_DUMP_MEM = 0x32
    CMD_CLEAR_IMEM = 0x40

    RESP_OK_CLEAR = 0xC0
    RESP_OK_PROG = 0xC1
    RESP_OK_STEP = 0xC2
    RESP_OK_STOP = 0xC3
    RESP_OK_RUN_END = 0xC4
    RESP_DUMP_REGS = 0xD0
    RESP_DUMP_LATCH = 0xD1
    RESP_DUMP_MEM = 0xD2
    RESP_DUMP_DONE = 0xD5
    RESP_ERR = 0xEE

    ACK_FRAMES = {
        RESP_OK_CLEAR: ("ack_clear", "RESP_OK_CLEAR"),
        RESP_OK_PROG: ("ack_program", "RESP_OK_PROG"),
        RESP_OK_STEP: ("ack_step", "RESP_OK_STEP"),
        RESP_OK_STOP: ("ack_stop", "RESP_OK_STOP"),
        RESP_OK_RUN_END: ("ack_run_end", "RESP_OK_RUN_END"),
        RESP_ERR: ("error", "RESP_ERR"),
    }

    def __init__(self) -> None:
        self._parser_state = "idle"
        self._payload = bytearray()
        self._command_lock = asyncio.Lock()
        self._waiters: list[PendingWaiter] = []
        self._pending_program_words = 0
        self._memory_dump_offset = 0

    def reset_runtime(self) -> None:
        self._parser_state = "idle"
        self._payload.clear()
        self._pending_program_words = 0
        self._memory_dump_offset = 0
        for waiter in self._waiters:
            if not waiter.future.done():
                waiter.future.cancel()
        self._waiters.clear()

    async def send_run(self) -> None:
        await self._send_command(bytes([self.CMD_RUN]), "CMD_RUN")

    async def send_stop(self) -> ParsedFrame:
        return await self._send_command(
            bytes([self.CMD_STOP]),
            "CMD_STOP",
            expected_kinds={"ack_stop"},
            timeout=2.0,
        )

    async def send_step(self) -> ParsedFrame:
        return await self._send_command(
            bytes([self.CMD_STEP]),
            "CMD_STEP",
            expected_kinds={"ack_step"},
            timeout=2.0,
        )

    async def clear_imem(self) -> ParsedFrame:
        return await self._send_command(
            bytes([self.CMD_CLEAR_IMEM]),
            "CMD_CLEAR_IMEM",
            expected_kinds={"ack_clear"},
            timeout=2.0,
        )

    async def dump_regs(self) -> ParsedFrame:
        return await self._send_command(
            bytes([self.CMD_DUMP_REGS]),
            "CMD_DUMP_REGS",
            expected_kinds={"regs_dump"},
            timeout=3.0,
        )

    async def dump_pipeline(self) -> ParsedFrame:
        return await self._send_command(
            bytes([self.CMD_DUMP_PIPE]),
            "CMD_DUMP_PIPE",
            expected_kinds={"pipeline_dump"},
            timeout=2.0,
        )

    async def dump_memory(self, offset: int = 0) -> ParsedFrame:
        self._memory_dump_offset = offset
        # Raw UART transfer time: (1 header + 1024 words * 4 bytes + 1 RESP_DUMP_DONE) * 10 bits / baudrate
        # The FPGA FSM also spends several clock cycles per word (SET_ADDR, WAIT, LATCH, NEXT states)
        # which can add significant latency at lower baud rates due to TX FIFO back-pressure.
        # We add a generous per-word overhead (0.001s / word) on top of raw transfer time
        # and raise the minimum floor to 30s to handle 9600 baud safely.
        raw_transfer_s = (1 + (self.MEMORY_DUMP_WORD_COUNT * 4) + 1) * 10 / max(session_state.baudrate, 1)
        fsm_overhead_s = self.MEMORY_DUMP_WORD_COUNT * 0.001  # ~1ms per word worst case
        timeout = max(30.0, raw_transfer_s + fsm_overhead_s + 2.0)
        return await self._send_command(
            bytes([self.CMD_DUMP_MEM]),
            "CMD_DUMP_MEM",
            expected_kinds={"memory_dump"},
            timeout=timeout,
        )

    async def program_words(self, words: list[int]) -> ParsedFrame:
        if len(words) > 0xFFFF:
            raise RuntimeError("La Debug Unit solo acepta hasta 65535 palabras por trama.")

        payload = bytearray([self.CMD_PROG_BEGIN, (len(words) >> 8) & 0xFF, len(words) & 0xFF])
        for word in words:
            payload.extend(word.to_bytes(4, byteorder="big", signed=False))

        self._pending_program_words = len(words)
        timeout = max(3.0, len(payload) * 10 / max(session_state.baudrate, 1) + 1.0)
        return await self._send_command(
            bytes(payload),
            f"CMD_PROG_BEGIN ({len(words)} words)",
            expected_kinds={"ack_program"},
            timeout=timeout,
        )

    async def _send_command(
        self,
        data: bytes,
        text: str,
        *,
        expected_kinds: set[str] | None = None,
        timeout: float = 2.0,
    ) -> ParsedFrame | None:
        if not serial_manager.is_connected():
            raise RuntimeError("No hay una FPGA conectada por UART.")

        async with self._command_lock:
            waiter: PendingWaiter | None = None
            if expected_kinds:
                loop = asyncio.get_running_loop()
                waiter = PendingWaiter(kinds=set(expected_kinds), future=loop.create_future())
                self._waiters.append(waiter)

            serial_manager.write(data)
            preview = [f"{byte:02X}" for byte in data[:16]]
            if len(data) > 16:
                preview.append("...")
            await publish_event(
                "uart_tx",
                {"bytes_hex": preview, "byte_count": len(data), "text": text},
            )

            if waiter is None:
                return None

            try:
                return await asyncio.wait_for(waiter.future, timeout=timeout)
            except asyncio.TimeoutError as exc:
                self._remove_waiter(waiter)
                session_state.mark_error(
                    "UART_TIMEOUT",
                    f"No se recibio la respuesta esperada para {text} dentro de {timeout:.2f} segundos.",
                )
                await publish_event(
                    "error",
                    {
                        "code": session_state.last_error_code,
                        "message": session_state.last_error,
                    },
                )
                await publish_event("backend_state", {"state": session_state.state})
                raise TimeoutError(session_state.last_error) from exc

    def consume_bytes(self, data: bytes) -> list[dict[str, Any]]:
        frames: list[ParsedFrame] = []
        for raw_byte in data:
            frames.extend(self._feed_byte(raw_byte))

        events: list[dict[str, Any]] = []
        for frame in frames:
            self._resolve_waiters(frame)
            events.extend(self._frame_to_events(frame))

        return events

    def _feed_byte(self, byte_value: int) -> list[ParsedFrame]:
        byte_hex = f"{byte_value:02X}"

        if self._parser_state == "idle":
            if byte_value in self.ACK_FRAMES:
                kind, text = self.ACK_FRAMES[byte_value]
                return [ParsedFrame(kind=kind, text=text, raw_bytes=[byte_hex])]

            if byte_value == self.RESP_DUMP_REGS:
                self._parser_state = "dump_regs_payload"
                self._payload = bytearray([byte_value])
                return []

            if byte_value == self.RESP_DUMP_LATCH:
                self._parser_state = "dump_pipeline_payload"
                self._payload = bytearray([byte_value])
                return []

            if byte_value == self.RESP_DUMP_MEM:
                self._parser_state = "dump_memory_payload"
                self._payload = bytearray([byte_value])
                return []

            if byte_value == self.RESP_DUMP_DONE:
                return [ParsedFrame(kind="dump_done", text="RESP_DUMP_DONE", raw_bytes=[byte_hex])]

            return [
                ParsedFrame(
                    kind="error",
                    text=f"Byte UART inesperado 0x{byte_hex} fuera de trama conocida.",
                    raw_bytes=[byte_hex],
                )
            ]

        if self._parser_state == "dump_regs_payload":
            self._payload.append(byte_value)
            if len(self._payload) == 1 + (32 * 4):
                self._parser_state = "dump_regs_done"
            return []

        if self._parser_state == "dump_regs_done":
            payload = bytes(self._payload)
            self._parser_state = "idle"
            self._payload = bytearray()
            if byte_value != self.RESP_DUMP_DONE:
                return [
                    ParsedFrame(
                        kind="error",
                        text="Trama DUMP_REGS incompleta: falta RESP_DUMP_DONE.",
                        raw_bytes=[f"{byte:02X}" for byte in payload] + [byte_hex],
                    )
                ]
            registers = self._decode_register_dump(payload[1:])
            raw_bytes = [f"{byte:02X}" for byte in payload] + [byte_hex]
            return [ParsedFrame(kind="regs_dump", text="RESP_DUMP_REGS", raw_bytes=raw_bytes, payload=registers)]

        if self._parser_state == "dump_pipeline_payload":
            self._payload.append(byte_value)
            if len(self._payload) == 1 + (self.PIPELINE_DUMP_WORD_COUNT * 4):
                self._parser_state = "dump_pipeline_done"
            return []

        if self._parser_state == "dump_pipeline_done":
            payload = bytes(self._payload)
            self._parser_state = "idle"
            self._payload = bytearray()
            if byte_value != self.RESP_DUMP_DONE:
                return [
                    ParsedFrame(
                        kind="error",
                        text="Trama DUMP_LATCH incompleta: falta RESP_DUMP_DONE.",
                        raw_bytes=[f"{byte:02X}" for byte in payload] + [byte_hex],
                    )
                ]
            pipeline_dump = self._decode_pipeline_dump(payload[1:])
            raw_bytes = [f"{byte:02X}" for byte in payload] + [byte_hex]
            return [
                ParsedFrame(
                    kind="pipeline_dump",
                    text="RESP_DUMP_LATCH",
                    raw_bytes=raw_bytes,
                    payload=pipeline_dump,
                )
            ]

        if self._parser_state == "dump_memory_payload":
            self._payload.append(byte_value)
            if len(self._payload) == 1 + (self.MEMORY_DUMP_WORD_COUNT * 4):
                self._parser_state = "dump_memory_done"
            return []

        if self._parser_state == "dump_memory_done":
            payload = bytes(self._payload)
            self._parser_state = "idle"
            self._payload = bytearray()
            if byte_value != self.RESP_DUMP_DONE:
                return [
                    ParsedFrame(
                        kind="error",
                        text="Trama DUMP_MEM incompleta: falta RESP_DUMP_DONE.",
                        raw_bytes=[f"{byte:02X}" for byte in payload] + [byte_hex],
                    )
                ]
            memory_dump = self._decode_memory_dump(payload[1:], self._memory_dump_offset)
            raw_bytes = [f"{byte:02X}" for byte in payload] + [byte_hex]
            return [ParsedFrame(kind="memory_dump", text="RESP_DUMP_MEM", raw_bytes=raw_bytes, payload=memory_dump)]

        self._parser_state = "idle"
        self._payload = bytearray()
        return [
            ParsedFrame(
                kind="error",
                text="La maquina de estados del parser entro en un estado invalido.",
                raw_bytes=[byte_hex],
            )
        ]

    def _resolve_waiters(self, frame: ParsedFrame) -> None:
        if frame.kind == "error":
            for waiter in self._waiters:
                if not waiter.future.done():
                    waiter.future.set_exception(RuntimeError(frame.text))
            self._waiters.clear()
            return

        to_remove: list[PendingWaiter] = []
        for waiter in self._waiters:
            if frame.kind in waiter.kinds and not waiter.future.done():
                waiter.future.set_result(frame)
                to_remove.append(waiter)

        for waiter in to_remove:
            self._remove_waiter(waiter)

    def _remove_waiter(self, waiter: PendingWaiter) -> None:
        if waiter in self._waiters:
            self._waiters.remove(waiter)

    def _frame_to_events(self, frame: ParsedFrame) -> list[dict[str, Any]]:
        events = [build_event("uart_rx", {"bytes_hex": frame.raw_bytes, "text": frame.text})]

        if frame.kind == "ack_clear":
            session_state.mark_program_cleared()
            events.append(build_event("backend_state", {"state": session_state.state}))
            return events

        if frame.kind == "ack_program":
            session_state.mark_program_loaded(self._pending_program_words)
            self._pending_program_words = 0
            events.append(build_event("backend_state", {"state": session_state.state}))
            return events

        if frame.kind == "ack_step":
            session_state.steps_executed += 1
            session_state.state = session_state.idle_state()
            events.append(build_event("backend_state", {"state": session_state.state}))
            return events

        if frame.kind in {"ack_stop", "ack_run_end"}:
            session_state.state = session_state.idle_state()
            events.append(build_event("backend_state", {"state": session_state.state}))
            return events

        if frame.kind == "regs_dump":
            session_state.record_regs_dump(frame.payload)
            events.append(build_event("regs_dump", frame.payload))
            return events

        if frame.kind == "pipeline_dump":
            session_state.record_pipeline_dump(frame.payload)
            events.append(build_event("pipeline_dump", frame.payload))
            return events

        if frame.kind == "memory_dump":
            session_state.record_memory_dump(frame.payload)
            events.append(build_event("mem_dump", frame.payload))
            return events

        if frame.kind == "dump_done":
            return events

        session_state.mark_error("UART_PROTOCOL_ERROR", frame.text)
        events.append(
            build_event(
                "error",
                {
                    "code": session_state.last_error_code,
                    "message": session_state.last_error,
                },
            )
        )
        events.append(build_event("backend_state", {"state": session_state.state}))
        return events

    def _decode_register_dump(self, payload: bytes) -> RegistersDumpPayload:
        registers: list[RegisterValue] = []
        for index in range(32):
            chunk = payload[index * 4 : (index + 1) * 4]
            value = int.from_bytes(chunk, byteorder="big", signed=False)
            signed_value = value if value < 0x80000000 else value - 0x100000000
            registers.append(
                RegisterValue(
                    index=index,
                    name=f"x{index}",
                    alias=REGISTER_ALIASES[index],
                    hex=f"0x{value:08X}",
                    dec=signed_value,
                    unsigned=value,
                )
            )
        return RegistersDumpPayload(registers=registers)

    def _decode_pipeline_dump(self, payload: bytes) -> PipelineDumpPayload:
        words = [
            int.from_bytes(payload[index * 4 : (index + 1) * 4], byteorder="big", signed=False)
            for index in range(self.PIPELINE_DUMP_WORD_COUNT)
        ]

        return PipelineDumpPayload(
            valid=True,
            source="rtl_dump_latches",
            stage_order=list(PIPELINE_STAGE_ORDER),
            stages={
                "Global": {
                    "dump_word_count": self.PIPELINE_DUMP_WORD_COUNT,
                    "pipeline_stall_or_debug_pause": bool(words[0] & 0x1),
                    "flush_ifid": bool(words[1] & 0x1),
                },
                "IF/ID": {
                    "pc": self._format_word(words[2]),
                    "pc_plus4": self._format_word(words[3]),
                    "instr": self._format_word(words[4]),
                },
                "ID/EX": {
                    "rs1_data": self._format_word(words[5]),
                    "rs2_data": self._format_word(words[6]),
                    "imm": self._format_signed_word(words[7]),
                    "alu_op_code": self._format_word(words[8]),
                    "alu_op_name": self._decode_alu_op(words[8]),
                    "reg_write": bool(words[9] & 0x1),
                    "mem_read": bool(words[10] & 0x1),
                    "mem_write": bool(words[11] & 0x1),
                    "mem_to_reg": bool(words[12] & 0x1),
                    "alu_src": bool(words[13] & 0x1),
                    "jump": bool(words[14] & 0x1),
                },
                "EX/MEM": {
                    "alu_result": self._format_word(words[15]),
                    "reg_write": bool(words[16] & 0x1),
                    "mem_write": bool(words[17] & 0x1),
                    "mem_to_reg": bool(words[18] & 0x1),
                    "jump": bool(words[19] & 0x1),
                },
                "MEM/WB": {
                    "rd_idx": words[20] & 0x1F,
                    "mem_rdata": self._format_word(words[21]),
                    "reg_write": bool(words[22] & 0x1),
                    "mem_to_reg": bool(words[23] & 0x1),
                    "jump": bool(words[24] & 0x1),
                },
            },
            raw_words=[self._format_word(word) for word in words],
        )

    def _decode_memory_dump(self, payload: bytes, offset: int) -> MemoryDumpPayload:
        words = [
            int.from_bytes(payload[index * 4 : (index + 1) * 4], byteorder="big", signed=False)
            for index in range(self.MEMORY_DUMP_WORD_COUNT)
        ]
        max_offset = max((self.MEMORY_DUMP_WORD_COUNT * 4) - 16, 0)
        normalized_offset = max(0, min(offset, max_offset))
        row_base = normalized_offset // 16

        rows = []
        for row_offset in range(self.MEMORY_ROWS_PER_RESPONSE):
            row_index = row_base + row_offset
            word_index = row_index * 4
            if word_index >= len(words):
                break

            address = row_index * 16
            row_words = words[word_index : word_index + 4]
            rows.append(
                MemoryDumpRow(
                    address=f"0x{address:08X}",
                    values=[self._format_word(word) for word in row_words],
                )
            )

        return MemoryDumpPayload(valid=True, source="rtl_dump_memory", rows=rows)

    def _decode_alu_op(self, value: int) -> str:
        return ALU_OP_NAMES.get(value & 0x3F, f"UNKNOWN_{value & 0x3F:06b}")

    def _format_word(self, value: int) -> str:
        return f"0x{value:08X}"

    def _format_signed_word(self, value: int) -> str:
        signed_value = value if value < 0x80000000 else value - 0x100000000
        return f"0x{value:08X} ({signed_value})"


protocol_manager = ProtocolManager()
