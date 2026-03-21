from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import asyncio
import os

# Routing imports
from app.api import routes_connection, routes_program, routes_control, routes_dump, routes_status
from app.ws.websocket_manager import manager
from app.serial.serial_manager import serial_manager

async def uart_listener_task():
    while True:
        await asyncio.sleep(0.05) # non-blocking sleep
        if serial_manager.is_connected():
            try:
                data = serial_manager.read(1)
                if data:
                    await manager.broadcast({
                        "type": "uart_rx", 
                        "payload": {"text": f"Raw Decode (1B): 0x{data.hex().upper()}"}
                    })
            except Exception:
                pass

@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(uart_listener_task())
    yield
    task.cancel()

app = FastAPI(title="RISC-V Debug UI Backend MVP", lifespan=lifespan)

# CORS setup for MVP
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
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
            data = await websocket.receive_text()
            # Handle incoming WS commands if necessary
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# Serve Frontend statically at the root path
frontend_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "frontend")
app.mount("/", StaticFiles(directory=frontend_path, html=True), name="frontend")
