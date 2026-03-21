from fastapi import APIRouter
from pydantic import BaseModel
from typing import List
from app.program.assembler import assembler
from app.serial.protocol_manager import protocol_manager
from app.core.state import session_state

router = APIRouter()

class ValidateRequest(BaseModel):
    asm: str

@router.post("/api/program/validate")
async def validate_program(req: ValidateRequest):
    words = assembler.assemble(req.asm)
    return {
        "errors": [],
        "warnings": [],
        "inst_count": len(words),
        "imem_usage": len(words) * 4
    }

@router.post("/api/program/assemble")
async def assemble_program(req: ValidateRequest):
    words = assembler.assemble(req.asm)
    hex_lines = "\n".join([f"{(i*4):08x}: {w:08x}" for i, w in enumerate(words)])
    return {"hex": hex_lines}

@router.post("/api/program/load")
async def load_program(req: ValidateRequest):
    words = assembler.assemble(req.asm)
    if len(words) > session_state.imem_size:
        return {"success": False, "message": "Program too big"}
    
    session_state.state = "PROGRAMMING"
    # Llamamos a protocol manager nativo para enviar UART
    protocol_manager.program_words(words)
    session_state.state = "PROGRAMMED"
    
    return {"success": True, "message": "Program loaded successfully"}

@router.post("/api/program/clear-imem")
async def clear_imem():
    protocol_manager.clear_imem()
    return {"success": True, "message": "IMEM cleared"}
