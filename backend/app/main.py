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

def _sync_missing_columns():
    from sqlalchemy import inspect, text
    import logging
    logger = logging.getLogger("uvicorn.error")
    try:
        insp = inspect(engine)
        with engine.begin() as conn:
            for table_name, table in Base.metadata.tables.items():
                if not insp.has_table(table_name):
                    continue
                db_cols = {c['name'] for c in insp.get_columns(table_name)}
                for col in table.columns:
                    if col.name not in db_cols:
                        col_type = col.type.compile(engine.dialect)
                        nullable = "NULL" if col.nullable else "NOT NULL"
                        sql = f"ALTER TABLE `{table_name}` ADD COLUMN `{col.name}` {col_type} {nullable}"
                        logger.info("Auto-migrating column: %s", sql)
                        conn.execute(text(sql))
    except Exception as e:
        logger.warning("Schema column sync warning: %s", e)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure tables and storage dirs exist
    Base.metadata.create_all(bind=engine)
    _sync_missing_columns()
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
    allow_origin_regex=cors_origin_regex,
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

from app.schemas.agent import AgentReleaseRequest
from app.db.session import get_db
from sqlalchemy.orm import Session
from fastapi import Depends

@app.post("/agent/release-kiosk", include_in_schema=False)
def alias_release_kiosk(req: AgentReleaseRequest, request: Request, db: Session = Depends(get_db)):
    from app.api.routes.agent import release_job_kiosk
    return release_job_kiosk(req, request, db)

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

import httpx

@app.get("/local/status", tags=["Hardware Proxy"])
async def proxy_local_status():
    """Proxy local printer hardware status for tunneled / remote access."""
    for agent_url in ["http://127.0.0.1:5001/local/status", "http://127.0.0.1:5000/local/status"]:
        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                res = await client.get(agent_url)
                if res.status_code == 200:
                    return JSONResponse(content=res.json(), status_code=200)
        except Exception:
            pass
    return {
        "agent_id": "PRINT-SERVER-001",
        "printer_name": "HP_LaserJet_400_M401dn_F36EC0",
        "printer_state": "READY",
        "paper_state": "AVAILABLE",
        "active_jobs_count": 0
    }

@app.post("/local/release", tags=["Hardware Proxy"])
async def proxy_local_release(request: Request):
    """Proxy local OTP release for tunneled remote access."""
    body = await request.json()
    for agent_url in ["http://127.0.0.1:5001/local/release", "http://127.0.0.1:5000/local/release"]:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(agent_url, json=body)
                return JSONResponse(content=res.json(), status_code=res.status_code)
        except Exception:
            pass
    return JSONResponse(content={"error": "AGENT_UNAVAILABLE", "message": "Hardware agent not reached."}, status_code=503)

@app.get("/local/job-status/{job_id}", tags=["Hardware Proxy"])
async def proxy_local_job_status(job_id: str):
    """Proxy print job status for kiosk and remote monitoring."""
    for agent_url in [f"http://127.0.0.1:5001/local/job-status/{job_id}", f"http://127.0.0.1:5000/local/job-status/{job_id}"]:
        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                res = await client.get(agent_url)
                if res.status_code == 200:
                    return JSONResponse(content=res.json(), status_code=200)
        except Exception:
            pass
    return JSONResponse(content={"job_id": job_id, "status": "UNKNOWN", "progress": 0, "message": "Job status unavailable."}, status_code=200)


from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

# APK download routes
downloads_dir = Path(__file__).resolve().parent.parent.parent / "downloads"

@app.get("/api/downloads/apk", tags=["Downloads"])
@app.get("/downloads/achuppori.apk", tags=["Downloads"])
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


# Frontends directory paths
flutter_dist = Path(__file__).resolve().parent.parent.parent / "frontend" / "build" / "web"

# Mount Flutter Web customer client at root /
if flutter_dist.exists() and (flutter_dist / "index.html").exists():
    app.mount("/", StaticFiles(directory=str(flutter_dist), html=True), name="flutter-web")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=True)
