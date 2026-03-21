from fastapi import APIRouter, HTTPException
from app.core.state import session_state
from app.serial.serial_manager import serial_manager

router = APIRouter()

@router.get("/ports")
async def get_ports():
    return serial_manager.get_ports()

@router.post("/connect")
async def connect(port: str = "COM3", baudrate: int = 9600):
    try:
        serial_manager.connect(port, baudrate)
        session_state.connected = True
        session_state.port = port
        session_state.baudrate = baudrate
        session_state.state = "CONNECTED"
        return {"success": True, "message": f"Connected to {port} at {baudrate}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/disconnect")
async def disconnect():
    serial_manager.disconnect()
    session_state.connected = False
    session_state.port = None
    session_state.state = "DISCONNECTED"
    return {"success": True, "message": "Disconnected"}
