from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models.user import User
from app.api.dependencies import get_current_admin
from app.schemas.admin import AdminDashboardResponse
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
