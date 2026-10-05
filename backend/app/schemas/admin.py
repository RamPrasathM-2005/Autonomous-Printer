from typing import List, Optional
from pydantic import BaseModel

class RecentPrintJob(BaseModel):
    id: str
    order_id: str
    document_name: str
    user_name: str
    user_email: Optional[str] = None
    department_name: str
    printer_name: str
    pages: int
    copies: int
    is_color: bool
    status: str
    created_at: str
    completed_at: Optional[str] = None
    error_message: Optional[str] = None

class DepartmentSummary(BaseModel):
    id: int
    code: str
    name: str
    users_count: int
    printers_count: int
    jobs_count: int
    pages_count: int

class AdminDashboardResponse(BaseModel):
    total_departments: int
    total_users: int
    total_printers: int
    total_print_jobs: int
    total_pages_printed: int
    successful_print_jobs: int
    failed_print_jobs: int
    color_pages: int
    bw_pages: int
    color_jobs: int
    bw_jobs: int
    success_rate: float
    recent_activity: List[RecentPrintJob]
    department_summary: List[DepartmentSummary]
