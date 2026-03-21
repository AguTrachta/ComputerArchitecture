from fastapi import APIRouter
from app.core.state import session_state

router = APIRouter()

@router.get("/status")
async def get_status():
    return session_state.model_dump()
