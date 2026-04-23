from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi.encoders import jsonable_encoder

from app.ws.websocket_manager import manager


def build_event(event_type: str, payload: Any) -> dict[str, Any]:
    return {
        "type": event_type,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "payload": jsonable_encoder(payload),
    }


async def publish_event(event_type: str, payload: Any) -> None:
    await manager.broadcast(build_event(event_type, payload))
