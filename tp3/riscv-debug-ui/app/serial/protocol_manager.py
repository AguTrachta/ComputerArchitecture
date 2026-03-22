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
        return await self._send_command(
            bytes([self.CMD_DUMP_MEM]),
            "CMD_DUMP_MEM",
            expected_kinds={"memory_dump"},
            timeout=2.0,
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
                self._parser_state = "dump_pipeline_done"
                self._payload = bytearray([byte_value])
                return []

            if byte_value == self.RESP_DUMP_MEM:
                self._parser_state = "dump_memory_done"
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

        if self._parser_state == "dump_pipeline_done":
            header = bytes(self._payload)
            self._parser_state = "idle"
            self._payload = bytearray()
            if byte_value != self.RESP_DUMP_DONE:
                return [
                    ParsedFrame(
                        kind="error",
                        text="Trama DUMP_LATCH incompleta: falta RESP_DUMP_DONE.",
                        raw_bytes=[f"{byte:02X}" for byte in header] + [byte_hex],
                    )
                ]
            payload = self._build_placeholder_pipeline_dump()
            raw_bytes = [f"{byte:02X}" for byte in header] + [byte_hex]
            return [ParsedFrame(kind="pipeline_dump", text="RESP_DUMP_LATCH", raw_bytes=raw_bytes, payload=payload)]

        if self._parser_state == "dump_memory_done":
            header = bytes(self._payload)
            self._parser_state = "idle"
            self._payload = bytearray()
            if byte_value != self.RESP_DUMP_DONE:
                return [
                    ParsedFrame(
                        kind="error",
                        text="Trama DUMP_MEM incompleta: falta RESP_DUMP_DONE.",
                        raw_bytes=[f"{byte:02X}" for byte in header] + [byte_hex],
                    )
                ]
            payload = self._build_placeholder_memory_dump(self._memory_dump_offset)
            raw_bytes = [f"{byte:02X}" for byte in header] + [byte_hex]
            return [ParsedFrame(kind="memory_dump", text="RESP_DUMP_MEM", raw_bytes=raw_bytes, payload=payload)]

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
            events.append(
                build_event(
                    "warning",
                    {"message": "El RTL actual solo devuelve un placeholder para dump_pipeline."},
                )
            )
            return events

        if frame.kind == "memory_dump":
            session_state.record_memory_dump(frame.payload)
            events.append(build_event("mem_dump", frame.payload))
            events.append(
                build_event(
                    "warning",
                    {"message": "El RTL actual solo devuelve un placeholder para dump_memory."},
                )
            )
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

    def _build_placeholder_pipeline_dump(self) -> PipelineDumpPayload:
        return PipelineDumpPayload(
            valid=False,
            stages={
                "Global": {"status": "placeholder", "reason": "RTL latch dump pendiente"},
                "IF/ID": {"status": "unavailable"},
                "ID/EX": {"status": "unavailable"},
                "EX/MEM": {"status": "unavailable"},
                "MEM/WB": {"status": "unavailable"},
            },
        )

    def _build_placeholder_memory_dump(self, offset: int) -> MemoryDumpPayload:
        rows = []
        for row_index in range(8):
            address = offset + (row_index * 16)
            rows.append(
                MemoryDumpRow(
                    address=f"0x{address:08X}",
                    values=["--------", "--------", "--------", "--------"],
                )
            )

        return MemoryDumpPayload(valid=False, rows=rows)


protocol_manager = ProtocolManager()
