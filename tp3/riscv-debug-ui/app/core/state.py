# app/core/state.py
from pydantic import BaseModel
from typing import Optional

class SystemState(BaseModel):
    state: str = "DISCONNECTED" # "CONNECTED", "IDLE", "PROGRAMMING", "RUNNING", "ERROR"
    connected: bool = False
    port: Optional[str] = None
    baudrate: int = 9600
    imem_size: int = 1024
    
    # Internal capabilities declaration
    capabilities: dict = {
        "can_clear_imem": True,
        "can_clear_dmem": False,
        "can_dump_regs": True,
        "can_dump_pipeline": True,
    }

# Global singleton state for MVP
session_state = SystemState()
