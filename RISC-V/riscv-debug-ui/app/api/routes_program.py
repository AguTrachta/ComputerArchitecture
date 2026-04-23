from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.core.events import publish_event
from app.core.state import session_state
from app.models.requests import ProgramTextRequest
from app.models.responses import (
    AssemblyResponse,
    OperationResponse,
    ProgramLoadResponse,
    ProgramValidationResponse,
)
from app.program.assembler import AssemblerError, assembler
from app.serial.protocol_manager import protocol_manager

router = APIRouter()


def _require_connection() -> None:
    if not session_state.connected:
        raise HTTPException(status_code=409, detail="No hay una FPGA conectada.")


def _require_program_idle() -> None:
    if session_state.state in {"PROGRAMMING", "STEPPING", "DUMPING"}:
        raise HTTPException(status_code=409, detail=f"Hay una operacion en curso ({session_state.state}).")


async def _stop_if_running() -> None:
    if session_state.state != "RUNNING":
        return

    try:
        await protocol_manager.send_stop()
    except TimeoutError as exc:
        raise HTTPException(status_code=504, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


async def _finish_programming() -> None:
    if session_state.state == "PROGRAMMING":
        session_state.state = session_state.idle_state()
        await publish_event("backend_state", {"state": session_state.state})


@router.post("/api/program/validate", response_model=ProgramValidationResponse)
async def validate_program(req: ProgramTextRequest) -> ProgramValidationResponse:
    try:
        result = assembler.validate(req.asm)
        return ProgramValidationResponse(
            errors=[],
            warnings=result.warnings,
            inst_count=len(result.words),
            imem_usage=len(result.words) * 4,
            imem_limit=session_state.imem_size * 4,
            within_imem_limit=len(result.words) <= session_state.imem_size,
        )
    except AssemblerError as exc:
        return ProgramValidationResponse(
            errors=exc.errors,
            warnings=[],
            inst_count=0,
            imem_usage=0,
            imem_limit=session_state.imem_size * 4,
            within_imem_limit=False,
        )


@router.post("/api/program/assemble", response_model=AssemblyResponse)
async def assemble_program(req: ProgramTextRequest) -> AssemblyResponse:
    try:
        result = assembler.assemble(req.asm)
    except AssemblerError as exc:
        raise HTTPException(status_code=400, detail={"errors": exc.errors}) from exc

    return AssemblyResponse(
        hex=result.hex_lines,
        words=[f"0x{word:08X}" for word in result.words],
        inst_count=len(result.words),
        imem_usage=len(result.words) * 4,
    )


@router.post("/api/program/load", response_model=ProgramLoadResponse)
async def load_program(req: ProgramTextRequest) -> ProgramLoadResponse:
    _require_connection()
    _require_program_idle()

    try:
        result = assembler.assemble(req.asm)
    except AssemblerError as exc:
        raise HTTPException(status_code=400, detail={"errors": exc.errors}) from exc

    if not result.words:
        raise HTTPException(status_code=400, detail="El programa no contiene instrucciones.")

    if len(result.words) > session_state.imem_size:
        raise HTTPException(
            status_code=400,
            detail=f"Program too big: {len(result.words)} words > {session_state.imem_size}.",
        )

    await _stop_if_running()
    session_state.state = "PROGRAMMING"
    await publish_event("backend_state", {"state": session_state.state})

    try:
        await protocol_manager.clear_imem()
        session_state.state = "PROGRAMMING"
        await publish_event("backend_state", {"state": session_state.state})
        await protocol_manager.program_words(result.words)
    except TimeoutError as exc:
        raise HTTPException(status_code=504, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    finally:
        await _finish_programming()

    return ProgramLoadResponse(
        success=True,
        message="Program loaded successfully.",
        state=session_state.state,
        inst_count=len(result.words),
    )


@router.post("/api/program/clear-imem", response_model=OperationResponse)
async def clear_imem() -> OperationResponse:
    _require_connection()
    _require_program_idle()

    await _stop_if_running()
    session_state.state = "PROGRAMMING"
    await publish_event("backend_state", {"state": session_state.state})

    try:
        await protocol_manager.clear_imem()
    except TimeoutError as exc:
        raise HTTPException(status_code=504, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    finally:
        await _finish_programming()

    return OperationResponse(success=True, message="IMEM cleared.", state=session_state.state)
