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

class AdminPrinterItem(BaseModel):
    id: str
    server_id: str
    server_name: Optional[str] = None
    server_status: str
    server_location: Optional[str] = None
    department_id: Optional[int] = None
    department_name: Optional[str] = None
    cups_printer_name: str
    display_name: str
    supports_color: bool
    supports_duplex: bool
    is_active: bool
    printer_state: Optional[str] = None
    paper_state: Optional[str] = None
    last_heartbeat: Optional[str] = None
    total_jobs_count: int = 0
    created_at: str

class AdminPrinterUpdate(BaseModel):
    display_name: Optional[str] = None
    department_id: Optional[int] = None
    is_active: Optional[bool] = None

class AdminPrintServerUpdate(BaseModel):
    status: Optional[str] = None
    location: Optional[str] = None

class AdminUserItem(BaseModel):
    id: int
    email: Optional[str] = None
    phone: Optional[str] = None
    full_name: Optional[str] = None
    roll_number: Optional[str] = None
    department_id: Optional[int] = None
    department_name: Optional[str] = None
    role: str
    is_active: bool
    total_orders: int = 0
    total_pages: int = 0
    total_spent: float = 0.0
    created_at: str

class AdminUserUpdate(BaseModel):
    full_name: Optional[str] = None
    department_id: Optional[int] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None

class PaginatedAdminUsersResponse(BaseModel):
    users: List[AdminUserItem]
    total: int
    page: int
    limit: int
    total_pages: int

class AdminSystemSettings(BaseModel):
    app_name: str
    per_page_rate: float
    base_fee: float
    max_upload_mb: int
    otp_ttl_minutes: int
    max_otp_attempts: int
    max_print_retries: int
    heartbeat_timeout_seconds: int
    email_provider: str
    smtp_host: str
    smtp_user: str
    current_admin_email: str

class AdminSystemSettingsUpdate(BaseModel):
    per_page_rate: Optional[float] = None
    base_fee: Optional[float] = None
    max_upload_mb: Optional[int] = None
    otp_ttl_minutes: Optional[int] = None
    max_otp_attempts: Optional[int] = None
    max_print_retries: Optional[int] = None
    heartbeat_timeout_seconds: Optional[int] = None

class AdminDatabaseStatusResponse(BaseModel):
    status: str
    database_url_masked: str
    environment: str
    latency_ms: float
    total_users: int
    total_departments: int
    total_printers: int
    total_orders: int
    total_print_jobs: int

class UserImportSummary(BaseModel):
    total_rows: int
    created: int
    updated: int
    failed: int
    errors: List[str] = []

