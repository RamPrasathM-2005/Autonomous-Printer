from fastapi import Depends, Header, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.config.security import decode_token, hash_token
from app.db.models.user import User, UserRole
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.utils.errors import AppException

security = HTTPBearer(auto_error=False)

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    if not credentials or credentials.scheme.lower() != "bearer":
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="UNAUTHENTICATED",
            message="Missing or invalid Authorization header."
        )

    token = credentials.credentials
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="INVALID_TOKEN",
            message="Invalid, expired, or malformed access token."
        )

    user_id = payload.get("sub")
    if not user_id:
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="INVALID_TOKEN",
            message="Token payload contains no user identity."
        )

    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user or not user.is_active:
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="UNAUTHENTICATED",
            message="User account is inactive or not found."
        )

    return user

def get_current_admin(user: User = Depends(get_current_user)) -> User:
    if user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        raise AppException(
            status_code=status.HTTP_403_FORBIDDEN,
            error_code="FORBIDDEN",
            message="Administrator privileges required."
        )
    return user

def get_authenticated_agent(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> PrintServer:
    if not credentials or credentials.scheme.lower() != "bearer":
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="UNAUTHENTICATED",
            message="Missing or invalid agent Authorization token."
        )

    device_token = credentials.credentials.strip()
    hashed_token = hash_token(device_token)

    server = db.query(PrintServer).filter(PrintServer.device_token_hash == hashed_token).first()
    if not server:
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="INVALID_TOKEN",
            message="Unrecognized agent device token."
        )

    if server.status == PrintServerStatus.DISABLED:
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="PRINT_SERVER_DISABLED",
            message="This print server station has been disabled."
        )

    return server
