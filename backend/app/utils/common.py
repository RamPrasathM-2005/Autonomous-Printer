from datetime import datetime, timezone
from app.utils.errors import AppException
from app.db.models.audit_log import AuditLog

def now():
    return datetime.now(timezone.utc).replace(tzinfo=None)

def naive(value):
    return value.replace(tzinfo=None) if value else None

def fail(code, message, status=400):
    raise AppException(status, code, message)

def audit(db, action, entity_id, actor='SYSTEM', **data):
    db.add(AuditLog(actor_type=actor, action=action, entity_id=entity_id,
                    meta_data=data or None))
