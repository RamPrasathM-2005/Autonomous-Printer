import os
import sys
from pathlib import Path
from contextlib import asynccontextmanager

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.config.settings import settings
from app.config.database import engine
from app.db.base import Base
from app.services.storage_service import storage_service
from app.utils.errors import (
    AppException,
    app_exception_handler,
    validation_exception_handler,
    general_exception_handler,
)

from app.api.routes.auth import router as auth_router
from app.api.routes.documents import router as documents_router
from app.api.routes.print_servers import router as print_servers_router
from app.api.routes.orders import router as orders_router
from app.api.routes.payments import router as payments_router
from app.api.routes.agent import router as agent_router
from app.api.routes.maintenance import router as maintenance_router
from app.api.routes.kiosk import router as kiosk_router
from app.api.routes.sessions import router as sessions_router
from app.api.routes.admin import router as admin_router
from app.api.routes.departments import router as departments_router
from app.api.routes.reports import router as reports_router

def _sync_missing_columns():
    from app.db.migrate import sync_schema
    sync_schema(engine)

def _ensure_admin_user():
    if not settings.ADMIN_EMAIL or not settings.ADMIN_PASSWORD:
        return
    from app.config.database import SessionLocal
    from app.db.models.user import User, UserRole
    from app.config.security import hash_password, verify_password
    import logging
    logger = logging.getLogger("uvicorn.error")
    db = SessionLocal()
    try:
        admin_email = settings.ADMIN_EMAIL.strip().lower()
        admin = db.query(User).filter(User.email == admin_email).first()
        if not admin:
            admin = User(
                email=admin_email,
                full_name=settings.ADMIN_NAME or "Platform Administrator",
                password_hash=hash_password(settings.ADMIN_PASSWORD),
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin)
            db.commit()
            logger.info("Initialized administrator account from environment: %s", admin_email)
        else:
            changed = False
            if admin.role not in (UserRole.ADMIN, UserRole.SUPER_ADMIN):
                admin.role = UserRole.ADMIN
                changed = True
            if not admin.is_active:
                admin.is_active = True
                changed = True
            if not admin.password_hash or not verify_password(settings.ADMIN_PASSWORD, admin.password_hash):
                admin.password_hash = hash_password(settings.ADMIN_PASSWORD)
                changed = True
            if changed:
                db.commit()
                logger.info("Synchronized administrator credentials from environment: %s", admin_email)
    except Exception as e:
        logger.warning("Could not auto-sync admin user: %s", e)
    finally:
        db.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure tables and storage dirs exist
    Base.metadata.create_all(bind=engine)
    _sync_missing_columns()
    _ensure_admin_user()
    storage_service._ensure_directories()
    yield
    # Shutdown

is_production = settings.ENVIRONMENT.lower() in ("production", "prod")

app = FastAPI(
    title=settings.APP_NAME,
    description="Smart Self-Service Printing Platform FastAPI Backend",
    version="1.0.0",
    lifespan=lifespan,
    docs_url=None if is_production else "/docs",
    redoc_url=None if is_production else "/redoc",
    openapi_url=None if is_production else "/openapi.json",
)

# CORS configuration: Restrict to configured origins, localhost, LAN, and Cloudflare tunnel
cors_origins = settings.ALLOWED_ORIGINS if isinstance(settings.ALLOWED_ORIGINS, list) else [settings.ALLOWED_ORIGINS]

cors_origin_regex = (
    r"^https?://(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+)(:\d+)?$"
    r"|^https://[a-zA-Z0-9-]+\.trycloudflare\.com$"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_origin_regex=None if is_production else cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


import time
import subprocess

@app.middleware("http")
async def log_requests_middleware(request: Request, call_next):
    start = time.time()
    method = request.method
    path = request.url.path
    print(f"[BACKEND_LOG] >>> {method} {path}")
    try:
        response = await call_next(request)
        duration_ms = (time.time() - start) * 1000
        print(f"[BACKEND_LOG] <<< {method} {path} - Status: {response.status_code} ({duration_ms:.1f}ms)")
        if path == "/" or path.endswith(".html") or path.endswith(".js") or "flutter" in path:
            response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
            response.headers["Pragma"] = "no-cache"
            response.headers["Expires"] = "0"
        return response
    except Exception as e:
        duration_ms = (time.time() - start) * 1000
        print(f"[BACKEND_LOG] !!! {method} {path} - Error: {e} ({duration_ms:.1f}ms)")
        raise

# Exception handlers
app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
if settings.ENVIRONMENT != "development":
    app.add_exception_handler(Exception, general_exception_handler)

# Routers
app.include_router(auth_router)
app.include_router(documents_router)
app.include_router(print_servers_router)
app.include_router(orders_router)
app.include_router(payments_router)
app.include_router(agent_router)
app.include_router(maintenance_router)
app.include_router(kiosk_router)
app.include_router(sessions_router)
app.include_router(admin_router)
app.include_router(departments_router)
app.include_router(reports_router)

from app.schemas.agent import AgentReleaseRequest
from app.db.session import get_db
from sqlalchemy.orm import Session
from fastapi import Depends

@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "environment": settings.ENVIRONMENT
    }

def _is_cloudflared_running() -> bool:
    try:
        res = subprocess.run(["pgrep", "-f", "cloudflared.*tunnel"], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False

@app.get("/api/tunnel", tags=["System"])
def get_tunnel_status():
    """Returns the active Cloudflare quick tunnel URL if cloudflared is running."""
    if not _is_cloudflared_running():
        return {"active": False, "tunnel_url": None}

    candidates = [
        Path(settings.STORAGE_ROOT) / "tunnel_url.txt",
        Path(__file__).resolve().parent.parent.parent / "storage" / "tunnel_url.txt",
    ]
    for p in candidates:
        if p.exists():
            try:
                url = p.read_text().strip()
                if url.startswith("http"):
                    return {"active": True, "tunnel_url": url}
            except Exception:
                pass
    return {"active": False, "tunnel_url": None}

@app.get("/local/status", include_in_schema=False)
@app.post("/local/release", include_in_schema=False)
@app.get("/local/job-status/{job_id}", include_in_schema=False)
def retired_hardware_proxy(job_id: str = ""):
    return JSONResponse(status_code=410, content={"error": "STATION_RELEASE_REQUIRED",
        "message": "Use the physical station touchscreen. Customer status is available through the order API."})

from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

# APK download routes
downloads_dir = Path(__file__).resolve().parent.parent.parent / "downloads"

@app.get("/api/downloads/apk", tags=["Downloads"], operation_id="download_apk_api")
def download_achuppori_apk():
    apk_file = downloads_dir / "achuppori.apk"
    if apk_file.exists():
        return FileResponse(
            path=str(apk_file),
            filename="achuppori.apk",
            media_type="application/vnd.android.package-archive"
        )
    raise AppException(
        status_code=status.HTTP_404_NOT_FOUND,
        error_code="APK_NOT_FOUND",
        message="Android APK file is not available."
    )

@app.get("/downloads/achuppori.apk", tags=["Downloads"], include_in_schema=False)
def download_achuppori_apk_direct():
    return download_achuppori_apk()


# Frontends directory paths
flutter_dist = Path(__file__).resolve().parent.parent.parent / "frontend" / "build" / "web"

# Mount Flutter Web customer client at root /
if flutter_dist.exists() and (flutter_dist / "index.html").exists():
    app.mount("/", StaticFiles(directory=str(flutter_dist), html=True), name="flutter-web")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=True)
