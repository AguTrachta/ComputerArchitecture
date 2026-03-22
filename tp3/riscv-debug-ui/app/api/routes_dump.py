from __future__ import annotations

import math

from fastapi import APIRouter, HTTPException

from app.core.state import session_state
from app.models.requests import MemoryDumpRequest
from app.models.responses import MemoryDumpResponse, PipelineDumpResponse, RegistersDumpResponse
from app.serial.protocol_manager import protocol_manager

router = APIRouter()


def _require_connection() -> None:
    if not session_state.connected:
        raise HTTPException(status_code=409, detail="No hay una FPGA conectada.")


@router.post("/api/dump/regs", response_model=RegistersDumpResponse)
async def dump_regs() -> RegistersDumpResponse:
    _require_connection()

    try:
        frame = await protocol_manager.dump_regs()
    except TimeoutError as exc:
        raise HTTPException(status_code=504, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    return RegistersDumpResponse(success=True, message="Regs dumped.", state=session_state.state, dump=frame.payload)


@router.post("/api/dump/pipeline", response_model=PipelineDumpResponse)
async def dump_pipeline() -> PipelineDumpResponse:
    _require_connection()

    try:
        frame = await protocol_manager.dump_pipeline()
    except TimeoutError as exc:
        raise HTTPException(status_code=504, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    return PipelineDumpResponse(
        success=True,
        message="Pipeline dump received.",
        state=session_state.state,
        dump=frame.payload,
    )



@router.post("/api/dump/memory", response_model=MemoryDumpResponse)
async def dump_memory(req: MemoryDumpRequest | None = None) -> MemoryDumpResponse:
    _require_connection()
    request = req or MemoryDumpRequest()

    try:
        frame = await protocol_manager.dump_memory(request.page, request.page_size)
    except TimeoutError as exc:
        raise HTTPException(status_code=504, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    total_pages = math.ceil(protocol_manager.MEMORY_DUMP_WORD_COUNT / request.page_size)

    return MemoryDumpResponse(
        success=True,
        message=f"Memory dump page {request.page}/{total_pages - 1} received.",
        state=session_state.state,
        dump=frame.payload,
        page=request.page,
        page_size=request.page_size,
        total_pages=total_pages,
    )
