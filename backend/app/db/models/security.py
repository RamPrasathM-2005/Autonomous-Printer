"""Durable security and reconciliation state. No browser-supplied payment truth."""
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Integer, JSON
from app.config.database import Base

def utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)

class CustomerSession(Base):
    __tablename__ = 'customer_sessions'
    id = Column(String(64), primary_key=True)
    token_hash = Column(String(64), unique=True, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)
    created_at = Column(DateTime, nullable=False, default=utcnow)

class RateLimitBucket(Base):
    __tablename__ = 'rate_limit_buckets'
    key = Column(String(64), primary_key=True)
    count = Column(Integer, nullable=False, default=0)
    expires_at = Column(DateTime, nullable=False, index=True)

class WebhookEvent(Base):
    __tablename__ = 'webhook_events'
    id = Column(String(128), primary_key=True)
    body_hash = Column(String(64), nullable=False)
    event_type = Column(String(64), nullable=False)
    # Only identifiers are retained. Never store card, UPI or customer payloads.
    references = Column(JSON, nullable=False)
    status = Column(String(24), nullable=False, default='PENDING', index=True)
    attempts = Column(Integer, nullable=False, default=0)
    next_attempt_at = Column(DateTime, nullable=False, default=utcnow, index=True)
    last_error = Column(String(128), nullable=True)
    created_at = Column(DateTime, nullable=False, default=utcnow)
    processed_at = Column(DateTime, nullable=True)

class WorkerState(Base):
    __tablename__ = 'worker_state'
    name = Column(String(64), primary_key=True)
    last_success_at = Column(DateTime, nullable=True)
    last_error = Column(String(128), nullable=True)
