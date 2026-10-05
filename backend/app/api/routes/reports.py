from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models.user import User
from app.api.dependencies import get_current_admin
from app.schemas.report import (
    DepartmentReportResponse,
    PaginatedPrintJobsResponse,
    PrintJobDetailResponse,
)
from app.services.report_service import report_service

router = APIRouter(prefix="/api/reports", tags=["Department Reports"])

@router.get("/department", response_model=DepartmentReportResponse)
def get_department_report(
    department_id: Optional[int] = Query(None, description="Department ID to filter by, or omit for all"),
    start_date: Optional[str] = Query(None, description="ISO start date filter"),
    end_date: Optional[str] = Query(None, description="ISO end date filter"),
    user_id: Optional[int] = Query(None, description="User ID filter"),
    printer_id: Optional[str] = Query(None, description="Printer ID filter"),
    status: Optional[str] = Query(None, description="Job status filter (e.g. COMPLETED, FAILED)"),
    is_color: Optional[bool] = Query(None, description="Color or B&W filter"),
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Generate comprehensive department printing report with KPI metrics,
    user-wise statistics, and printer workload utilization.
    Accessible only to authenticated administrators.
    """
    return report_service.generate_department_report(
        db=db,
        department_id=department_id,
        start_date=start_date,
        end_date=end_date,
        user_id=user_id,
        printer_id=printer_id,
        job_status=status,
        is_color=is_color,
    )

@router.get("/departments/{department_id}", response_model=DepartmentReportResponse)
def get_single_department_report_shortcut(
    department_id: int,
    start_date: Optional[str] = Query(None, description="ISO start date filter"),
    end_date: Optional[str] = Query(None, description="ISO end date filter"),
    user_id: Optional[int] = Query(None, description="User ID filter"),
    printer_id: Optional[str] = Query(None, description="Printer ID filter"),
    status: Optional[str] = Query(None, description="Job status filter"),
    is_color: Optional[bool] = Query(None, description="Color or B&W filter"),
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Shortcut endpoint to generate report for a specific department.
    Accessible only to authenticated administrators.
    """
    return report_service.generate_department_report(
        db=db,
        department_id=department_id,
        start_date=start_date,
        end_date=end_date,
        user_id=user_id,
        printer_id=printer_id,
        job_status=status,
        is_color=is_color,
    )

@router.get("/jobs", response_model=PaginatedPrintJobsResponse)
def get_detailed_print_jobs(
    department_id: Optional[int] = Query(None, description="Filter jobs by department ID"),
    user_id: Optional[int] = Query(None, description="Filter jobs by user ID"),
    printer_id: Optional[str] = Query(None, description="Filter jobs by printer ID"),
    status: Optional[str] = Query(None, description="Filter jobs by status"),
    is_color: Optional[bool] = Query(None, description="Filter by color (true) or B&W (false)"),
    start_date: Optional[str] = Query(None, description="ISO start date filter"),
    end_date: Optional[str] = Query(None, description="ISO end date filter"),
    search: Optional[str] = Query(None, description="Search by document name, user, roll no, or job ID"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    sort_by: str = Query("created_at", description="Sort by field: created_at, pages, amount"),
    sort_order: str = Query("desc", description="Sort order: asc or desc"),
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Retrieve paginated, filtered detailed print job logs.
    Supports filtering across departments, users, printers, dates, color modes, and search query.
    Accessible only to authenticated administrators.
    """
    return report_service.get_print_job_logs(
        db=db,
        department_id=department_id,
        user_id=user_id,
        printer_id=printer_id,
        job_status=status,
        is_color=is_color,
        start_date=start_date,
        end_date=end_date,
        search=search,
        page=page,
        page_size=page_size,
        sort_by=sort_by,
        sort_order=sort_order,
    )

@router.get("/jobs/{job_id}", response_model=PrintJobDetailResponse)
def get_print_job_detail(
    job_id: str,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Retrieve full audit and diagnostic details for a specific print job.
    Accessible only to authenticated administrators.
    """
    return report_service.get_print_job_detail(db=db, job_id=job_id)

