from __future__ import annotations

from typing import Dict

from pydantic import BaseModel, Field


StageValue = str | int | bool | None


class RegisterValue(BaseModel):
    index: int
    name: str
    alias: str
    hex: str
    dec: int
    unsigned: int


class RegistersDumpPayload(BaseModel):
    registers: list[RegisterValue] = Field(default_factory=list)
    source: str = "rtl_dump_regs"


class PipelineDumpPayload(BaseModel):
    valid: bool = False
    source: str = "rtl_placeholder_until_latch_dump"
    stages: Dict[str, Dict[str, StageValue]] = Field(default_factory=dict)


class MemoryDumpRow(BaseModel):
    address: str
    values: list[str] = Field(default_factory=list)


class MemoryDumpPayload(BaseModel):
    valid: bool = False
    source: str = "rtl_placeholder_until_memory_dump"
    rows: list[MemoryDumpRow] = Field(default_factory=list)
