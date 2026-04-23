from __future__ import annotations

from fastapi import APIRouter

from app.core.state import session_state
from app.models.responses import StatusResponse

router = APIRouter()


@router.get("/status", response_model=StatusResponse)
async def get_status() -> StatusResponse:
    return StatusResponse.model_validate(session_state.model_dump())
