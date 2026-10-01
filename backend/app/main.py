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

from app.api.routes.documents import router as documents_router
from app.api.routes.print_servers import router as print_servers_router
from app.api.routes.orders import router as orders_router
from app.api.routes.payments import router as payments_router
from app.api.routes.agent import router as agent_router
from app.api.routes.maintenance import router as maintenance_router
from app.api.routes.kiosk import router as kiosk_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure tables and storage dirs exist
    Base.metadata.create_all(bind=engine)
    storage_service._ensure_directories()
    yield
    # Shutdown

app = FastAPI(
    title=settings.APP_NAME,
    description="Smart Self-Service Printing Platform FastAPI Backend",
    version="1.0.0",
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.ENVIRONMENT == "development" else [],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

import time

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
app.include_router(documents_router)
app.include_router(print_servers_router)
app.include_router(orders_router)
app.include_router(payments_router)
app.include_router(agent_router)
app.include_router(maintenance_router)
app.include_router(kiosk_router)

from app.schemas.agent import AgentReleaseRequest
from app.db.session import get_db
from sqlalchemy.orm import Session
from fastapi import Depends

@app.post("/agent/release-kiosk", include_in_schema=False)
def alias_release_kiosk(req: AgentReleaseRequest, db: Session = Depends(get_db)):
    from app.api.routes.agent import release_job_kiosk
    return release_job_kiosk(req, db)

@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "environment": settings.ENVIRONMENT
    }

@app.get("/api/tunnel", tags=["System"])
def get_tunnel_status():
    """Returns the active Cloudflare quick tunnel URL if available."""
    candidates = [
        Path(settings.STORAGE_DIR) / "tunnel_url.txt",
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

from fastapi.staticfiles import StaticFiles

# Mount downloads directory for mobile APK package
downloads_dir = Path(__file__).resolve().parent.parent.parent / "downloads"
if downloads_dir.exists():
    app.mount("/downloads", StaticFiles(directory=str(downloads_dir)), name="downloads")

# Mount customer web client if built (e.g. for tunneled remote access)
react_dist = Path(__file__).resolve().parent.parent.parent / "frontend-react" / "dist"
if react_dist.exists() and (react_dist / "index.html").exists():
    app.mount("/", StaticFiles(directory=str(react_dist), html=True), name="frontend-web")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=True)
