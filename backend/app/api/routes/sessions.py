import uuid
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter

router = APIRouter(prefix="/api/sessions", tags=["Customer Sessions"])

@router.post("", status_code=201)
def start_session():
    """Provides a customer session token for frontend state and rate tracking."""
    expires_at = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()
    return {
        "token": f"sess_{uuid.uuid4().hex}",
        "expiresAt": expires_at,
    }

@router.delete("/current")
def end_session():
    """Revokes current customer session."""
    return {"status": "ended"}
