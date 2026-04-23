from __future__ import annotations

from pydantic import BaseModel, Field


class ProgramTextRequest(BaseModel):
    asm: str = Field(min_length=1)



class MemoryDumpRequest(BaseModel):
    page: int = Field(default=0, ge=0)
    page_size: int = Field(default=32, ge=1, le=255)
