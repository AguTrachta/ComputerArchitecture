from __future__ import annotations

from pydantic import BaseModel, Field


class ProgramTextRequest(BaseModel):
    asm: str = Field(min_length=1)


class MemoryDumpRequest(BaseModel):
    offset: int = Field(default=0, ge=0, le=0xFFC)
