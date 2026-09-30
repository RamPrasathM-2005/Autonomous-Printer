import hashlib
import secrets
import calendar
from datetime import timedelta
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.exc import IntegrityError
from app.api.dependencies import security
from app.config.settings import settings
from app.config.security import hash_token
from app.db.session import get_db
from app.db.models.security import CustomerSession, RateLimitBucket
from app.utils.common import now, naive, fail

def rate_limit(db, identity: str, limit: int, seconds: int):
    """Transactionally shared across API processes; no X-Forwarded-For trust."""
    timestamp = now()
    window = calendar.timegm(timestamp.utctimetuple()) // seconds
    key = hashlib.sha256(f'{identity}:{window}'.encode()).hexdigest()
    # A nested transaction handles concurrent first inserts without rolling back callers.
    try:
        with db.begin_nested():
            if not db.get(RateLimitBucket, key):
                db.add(RateLimitBucket(key=key, count=0,
                    expires_at=timestamp + timedelta(seconds=seconds * 2)))
                db.flush()
    except IntegrityError:
        pass
    bucket = db.query(RateLimitBucket).filter_by(key=key).with_for_update().populate_existing().one()
    if bucket.count >= limit:
        db.commit()
        fail('RATE_LIMITED', 'Too many requests. Please wait before retrying.', 429)
    bucket.count += 1
    db.commit()

def create_session(db, request: Request):
    rate_limit(db, 'sessions:' + request.client.host, 20, 3600)
    token = secrets.token_urlsafe(32)
    session = CustomerSession(id=secrets.token_hex(16), token_hash=hash_token(token),
        expires_at=now() + timedelta(hours=settings.SESSION_TTL_HOURS))
    db.add(session)
    db.commit()
    return {'token': token, 'expiresAt': session.expires_at.isoformat() + 'Z'}

def current_session(request: Request, credentials: HTTPAuthorizationCredentials = Depends(security), db=Depends(get_db)):
    if not credentials or credentials.scheme.lower() != 'bearer':
        fail('UNAUTHENTICATED', 'A customer session is required.', 401)
    session = db.query(CustomerSession).filter_by(token_hash=hash_token(credentials.credentials)).first()
    if not session or naive(session.expires_at) <= now():
        fail('SESSION_EXPIRED', 'Your session has expired. Start a new session.', 401)
    if request.method not in ('GET', 'HEAD', 'OPTIONS'):
        rate_limit(db, 'write:' + session.id, 60, 60)
    return session

def owned_order(db, order_id, session, lock=False):
    from app.db.models.order import Order
    query = db.query(Order).filter_by(id=order_id, session_id=session.id)
    if lock:
        query = query.with_for_update()
    order = query.first()
    if not order:
        fail('NOT_FOUND', 'Order not found.', 404)
    return order
