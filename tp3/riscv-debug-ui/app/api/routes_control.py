from fastapi import APIRouter
from app.core.state import session_state
from app.serial.protocol_manager import protocol_manager

router = APIRouter()

@router.post("/api/control/run")
async def run_cpu():
    protocol_manager.send_run()
    session_state.state = "RUNNING"
    return {"success": True, "state": session_state.state}

@router.post("/api/control/stop")
async def stop_cpu():
    protocol_manager.send_stop()
    session_state.state = "IDLE"
    return {"success": True, "state": session_state.state}

@router.post("/api/control/step")
async def step_cpu():
    protocol_manager.send_step()
    return {"success": True, "message": "Stepped 1 cycle"}
