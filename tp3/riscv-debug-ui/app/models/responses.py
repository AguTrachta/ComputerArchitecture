from __future__ import annotations

from pydantic import BaseModel, Field

from app.models.dumps import MemoryDumpPayload, PipelineDumpPayload, RegistersDumpPayload


class CapabilityFlags(BaseModel):
    can_clear_imem: bool = True
    can_clear_dmem: bool = False
    can_dump_regs: bool = True
    can_dump_pipeline: bool = True
    can_dump_pipeline_full_payload: bool = True
    can_dump_memory: bool = True
    can_dump_memory_full_payload: bool = True
    can_reset_exec_independent: bool = False


class OperationResponse(BaseModel):
    success: bool
    message: str
    state: str | None = None


class ProgramValidationResponse(BaseModel):
    errors: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    inst_count: int = 0
    imem_usage: int = 0
    imem_limit: int = 0
    within_imem_limit: bool = False


class AssemblyResponse(BaseModel):
    hex: str
    words: list[str] = Field(default_factory=list)
    inst_count: int
    imem_usage: int


class ProgramLoadResponse(OperationResponse):
    inst_count: int = 0


class RegistersDumpResponse(OperationResponse):
    dump: RegistersDumpPayload | None = None


class PipelineDumpResponse(OperationResponse):
    dump: PipelineDumpPayload | None = None


class MemoryDumpResponse(OperationResponse):
    dump: MemoryDumpPayload | None = None
    page: int = 0
    page_size: int = 32
    total_pages: int = 0


class StatusResponse(BaseModel):
    state: str = "DISCONNECTED"
    connected: bool = False
    port: str | None = None
    baudrate: int = 9600
    imem_size: int = 1024
    program_loaded: bool = False
    loaded_program_words: int = 0
    steps_executed: int = 0
    capabilities: CapabilityFlags = Field(default_factory=CapabilityFlags)
    last_register_dump: RegistersDumpPayload | None = None
    last_pipeline_dump: PipelineDumpPayload | None = None
    last_memory_dump: MemoryDumpPayload | None = None
    last_error_code: str | None = None
    last_error: str | None = None
