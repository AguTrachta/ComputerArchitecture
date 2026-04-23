from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.core.events import publish_event
from app.core.state import session_state
from app.models.responses import OperationResponse
from app.serial.protocol_manager import protocol_manager
from app.serial.serial_manager import serial_manager

router = APIRouter()


@router.get("/ports", response_model=list[str])
async def get_ports() -> list[str]:
    return serial_manager.get_ports()


@router.post("/connect", response_model=OperationResponse)
async def connect(port: str = "COM3", baudrate: int = 9600) -> OperationResponse:
    try:
        serial_manager.connect(port, baudrate)
        protocol_manager.reset_runtime()
        session_state.mark_connected(port, baudrate)
        await publish_event(
            "connection_status",
            {"connected": True, "port": session_state.port, "baudrate": session_state.baudrate},
        )
        await publish_event("backend_state", {"state": session_state.state})
        return OperationResponse(
            success=True,
            message=f"Connected to {port} at {baudrate} baud.",
            state=session_state.state,
        )
    except Exception as exc:
        session_state.mark_error("SERIAL_CONNECT_ERROR", str(exc))
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/disconnect", response_model=OperationResponse)
async def disconnect() -> OperationResponse:
    protocol_manager.reset_runtime()
    serial_manager.disconnect()
    session_state.mark_disconnected()
    await publish_event("connection_status", {"connected": False, "port": None, "baudrate": None})
    await publish_event("backend_state", {"state": session_state.state})
    return OperationResponse(success=True, message="Disconnected.", state=session_state.state)
