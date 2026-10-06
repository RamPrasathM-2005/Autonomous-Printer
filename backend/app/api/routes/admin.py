from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, UploadFile, File, Response
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models.user import User
from app.api.dependencies import get_current_admin
from app.schemas.admin import (
    AdminDashboardResponse,
    AdminPrinterItem,
    AdminPrinterUpdate,
    AdminPrintServerUpdate,
    AdminUserItem,
    AdminUserUpdate,
    PaginatedAdminUsersResponse,
    AdminSystemSettings,
    AdminSystemSettingsUpdate,
    AdminDatabaseStatusResponse,
    UserImportSummary,
)
from app.services.admin_service import admin_service

router = APIRouter(prefix="/api/admin", tags=["Admin Portal"])

@router.get("/dashboard", response_model=AdminDashboardResponse)
def get_admin_dashboard(
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """
    Returns aggregated metrics for the enterprise admin dashboard.
    Only accessible by authenticated administrators.
    """
    return admin_service.get_dashboard_metrics(db)

# ----------------- PRINTER MANAGEMENT -----------------

@router.get("/printers", response_model=List[AdminPrinterItem])
def get_admin_printers(
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """
    Returns all registered printer hardware stations with real-time status and diagnostics.
    """
    return admin_service.get_printers(db)

@router.patch("/printers/{printer_id}", response_model=AdminPrinterItem)
def update_admin_printer(
    printer_id: str,
    data: AdminPrinterUpdate,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """
    Updates printer display details, department assignment, or active toggle.
    """
    return admin_service.update_printer(printer_id, data, db)

@router.patch("/print-servers/{server_id}")
def update_admin_print_server(
    server_id: str,
    data: AdminPrintServerUpdate,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """
    Updates print server state (ONLINE, OFFLINE, MAINTENANCE, DISABLED) or physical location.
    """
    admin_service.update_print_server(server_id, data, db)
    return {"message": "Print server updated successfully"}

# ----------------- USER MANAGEMENT -----------------

@router.get("/users", response_model=PaginatedAdminUsersResponse)
def get_admin_users(
    page: int = Query(1, ge=1),
    limit: int = Query(15, ge=1, le=100),
    search: Optional[str] = Query(None),
    department_id: Optional[int] = Query(None),
    role: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """
    Search and paginate user directory with department links and printing metrics.
    """
    return admin_service.get_users(
        db=db,
        page=page,
        limit=limit,
        search=search,
        department_id=department_id,
        role=role,
        is_active=is_active
    )

@router.patch("/users/{user_id}", response_model=AdminUserItem)
def update_admin_user(
    user_id: int,
    data: AdminUserUpdate,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """
    Updates user details: department assignment, role, or active status toggle.
    """
    return admin_service.update_user(user_id, data, db)

# ----------------- SYSTEM SETTINGS -----------------

@router.get("/settings", response_model=AdminSystemSettings)
def get_admin_settings(
    admin: User = Depends(get_current_admin)
):
    """
    Returns platform runtime configurations, rates, and operational parameters.
    """
    return admin_service.get_settings(admin.email)

@router.patch("/settings", response_model=AdminSystemSettings)
def update_admin_settings(
    data: AdminSystemSettingsUpdate,
    admin: User = Depends(get_current_admin)
):
    """
    Updates platform operational parameters (pricing rates, quotas, timeouts).
    """
    return admin_service.update_settings(data, admin.email)
 
# ----------------- DATABASE & PRODUCTION DATA -----------------

@router.get("/database/status", response_model=AdminDatabaseStatusResponse)
def get_database_status(
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """
    Returns live database health, latency, masked URL, and table record counts.
    """
    return admin_service.get_database_status(db)

@router.get("/users/import/template")
def download_roster_template(
    admin: User = Depends(get_current_admin)
):
    """
    Downloads pre-formatted Excel template for importing campus/student rosters.
    """
    template_bytes = admin_service.generate_roster_template()
    return Response(
        content=template_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=student_roster_template.xlsx"}
    )

@router.post("/users/import", response_model=UserImportSummary)
async def import_user_roster(
    file: UploadFile = File(...),
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """
    Imports real user and department rosters from an uploaded .xlsx or .csv file.
    """
    contents = await file.read()
    return admin_service.import_roster(contents, file.filename or "roster.xlsx", db)

