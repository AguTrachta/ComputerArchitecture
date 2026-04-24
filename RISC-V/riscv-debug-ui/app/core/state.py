from __future__ import annotations

from app.models.dumps import MemoryDumpPayload, PipelineDumpPayload, RegistersDumpPayload
from app.models.responses import StatusResponse


class SystemState(StatusResponse):
    def idle_state(self) -> str:
        return "PROGRAMMED" if self.program_loaded else "IDLE"

    def mark_connected(self, port: str, baudrate: int) -> None:
        self.connected = True
        self.port = port
        self.baudrate = baudrate
        self.state = "CONNECTED"
        self.program_loaded = False
        self.loaded_program_words = 0
        self.steps_executed = 0
        self.last_register_dump = None
        self.last_pipeline_dump = None
        self.last_memory_dump = None
        self.last_error = None
        self.last_error_code = None

    def mark_disconnected(self) -> None:
        self.connected = False
        self.port = None
        self.state = "DISCONNECTED"
        self.program_loaded = False
        self.loaded_program_words = 0
        self.steps_executed = 0
        self.last_register_dump = None
        self.last_pipeline_dump = None
        self.last_memory_dump = None
        self.last_error = None
        self.last_error_code = None

    def mark_program_loaded(self, word_count: int) -> None:
        self.program_loaded = True
        self.loaded_program_words = word_count
        self.state = "PROGRAMMED"
        self.last_error = None
        self.last_error_code = None

    def mark_program_cleared(self) -> None:
        self.program_loaded = False
        self.loaded_program_words = 0
        self.state = "IDLE" if self.connected else "DISCONNECTED"

    def record_regs_dump(self, dump: RegistersDumpPayload) -> None:
        self.last_register_dump = dump

    def record_pipeline_dump(self, dump: PipelineDumpPayload) -> None:
        self.last_pipeline_dump = dump

    def record_memory_dump(self, dump: MemoryDumpPayload) -> None:
        self.last_memory_dump = dump

    def mark_error(self, code: str, message: str) -> None:
        self.state = "ERROR"
        self.last_error_code = code
        self.last_error = message


session_state = SystemState()
