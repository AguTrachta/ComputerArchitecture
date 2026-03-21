from fastapi import APIRouter
from app.serial.protocol_manager import protocol_manager

router = APIRouter()

@router.post("/api/dump/regs")
async def dump_regs():
    protocol_manager.dump_regs()
    return {"success": True, "message": "Regs dumped"}

@router.post("/api/dump/pipeline")
async def dump_pipeline():
    protocol_manager.dump_pipeline()
    return {"success": True, "message": "Pipeline dumped"}

@router.post("/api/dump/memory")
async def dump_memory():
    protocol_manager.dump_memory()
    return {"success": True, "message": "Memory dumped"}
