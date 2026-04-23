from __future__ import annotations

import asyncio
import contextlib
from contextlib import asynccontextmanager
import os

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import routes_connection, routes_control, routes_dump, routes_program, routes_status
from app.core.events import publish_event
from app.core.state import session_state
from app.serial.protocol_manager import protocol_manager
from app.serial.serial_manager import serial_manager
from app.ws.websocket_manager import manager


async def uart_listener_task() -> None:
    while True:
        await asyncio.sleep(0.02)
        if not serial_manager.is_connected():
            continue

        try:
            data = serial_manager.read_available()
            if not data:
                continue

            for event in protocol_manager.consume_bytes(data):
                await manager.broadcast(event)
        except Exception as exc:
            session_state.mark_error("UART_LISTENER_ERROR", str(exc))
            await publish_event(
                "error",
                {"code": session_state.last_error_code, "message": session_state.last_error},
            )
            await publish_event("backend_state", {"state": session_state.state})


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(uart_listener_task())
    try:
        yield
    finally:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


app = FastAPI(title="RISC-V Debug UI Backend", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(routes_connection.router)
app.include_router(routes_program.router)
app.include_router(routes_control.router)
app.include_router(routes_dump.router)
app.include_router(routes_status.router)


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)


frontend_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "frontend")
app.mount("/", StaticFiles(directory=frontend_path, html=True), name="frontend")
