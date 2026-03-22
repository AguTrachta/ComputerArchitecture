from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.core.events import publish_event
from app.core.state import session_state
from app.models.responses import OperationResponse
from app.serial.protocol_manager import protocol_manager

router = APIRouter()


def _require_ready_program() -> None:
    if not session_state.connected:
        raise HTTPException(status_code=409, detail="No hay una FPGA conectada.")
    if not session_state.program_loaded:
        raise HTTPException(status_code=409, detail="No hay un programa cargado en IMEM.")


@router.post("/api/control/run", response_model=OperationResponse)
async def run_cpu() -> OperationResponse:
    _require_ready_program()

    if session_state.state == "RUNNING":
        raise HTTPException(status_code=409, detail="La CPU ya esta corriendo.")

    try:
        await protocol_manager.send_run()
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    session_state.state = "RUNNING"
    await publish_event("backend_state", {"state": session_state.state})
    return OperationResponse(success=True, message="CPU running.", state=session_state.state)


@router.post("/api/control/stop", response_model=OperationResponse)
async def stop_cpu() -> OperationResponse:
    if not session_state.connected:
        raise HTTPException(status_code=409, detail="No hay una FPGA conectada.")
    if session_state.state != "RUNNING":
        raise HTTPException(status_code=409, detail="La CPU no esta corriendo.")

    try:
        await protocol_manager.send_stop()
    except TimeoutError as exc:
        raise HTTPException(status_code=504, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    return OperationResponse(success=True, message="CPU stopped.", state=session_state.state)


@router.post("/api/control/step", response_model=OperationResponse)
async def step_cpu() -> OperationResponse:
    _require_ready_program()

    if session_state.state == "RUNNING":
        raise HTTPException(status_code=409, detail="No se puede ejecutar STEP mientras RUN esta activo.")

    session_state.state = "STEPPING"
    await publish_event("backend_state", {"state": session_state.state})

    try:
        await protocol_manager.send_step()
        if session_state.capabilities.can_dump_regs:
            await protocol_manager.dump_regs()
        if session_state.capabilities.can_dump_pipeline:
            await protocol_manager.dump_pipeline()
    except TimeoutError as exc:
        raise HTTPException(status_code=504, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    finally:
        # Always reset state — never leave it stuck at STEPPING
        if session_state.state == "STEPPING":
            session_state.state = session_state.idle_state()
            await publish_event("backend_state", {"state": session_state.state})

    return OperationResponse(
        success=True,
        message="Step completed and observable dumps refreshed.",
        state=session_state.state,
    )
