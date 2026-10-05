from typing import List, Optional
from pydantic import BaseModel

class DepartmentSummaryReport(BaseModel):
    department_id: Optional[int] = None
    department_name: str
    department_code: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    total_jobs: int
    total_pages: int
    successful_jobs: int
    failed_jobs: int
    cancelled_jobs: int
    color_pages: int
    bw_pages: int
    color_jobs: int
    bw_jobs: int
    avg_pages_per_job: float
    total_amount: float

class UserReportStat(BaseModel):
    user_id: Optional[int] = None
    user_name: str
    email: Optional[str] = None
    roll_number: Optional[str] = None
    total_jobs: int
    total_pages: int
    color_pages: int
    bw_pages: int
    success_rate: float

class PrinterUtilizationStat(BaseModel):
    printer_id: str
    printer_name: str
    cups_printer_name: str
    total_jobs: int
    total_pages: int
    utilization_percentage: float
    success_rate: float

class DepartmentReportResponse(BaseModel):
    summary: DepartmentSummaryReport
    user_stats: List[UserReportStat]
    printer_stats: List[PrinterUtilizationStat]

class PrintJobDetailResponse(BaseModel):
    id: str
    order_id: str
    user_id: Optional[int] = None
    user_name: Optional[str] = None
    user_email: Optional[str] = None
    user_roll_number: Optional[str] = None
    department_id: Optional[int] = None
    department_name: Optional[str] = None
    printer_id: Optional[str] = None
    printer_name: Optional[str] = None
    cups_printer_name: Optional[str] = None
    cups_job_id: Optional[str] = None
    document_name: str
    document_id: Optional[str] = None
    file_size_bytes: Optional[int] = None
    mime_type: Optional[str] = None
    pages: int
    copies: int
    total_sheets: int
    is_color: bool
    is_duplex: bool
    print_settings: Optional[dict] = None
    amount: float
    currency: str = "INR"
    status: str
    retry_count: int = 0
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    created_at: str
    completed_at: Optional[str] = None

class PaginatedPrintJobsResponse(BaseModel):
    total: int
    page: int
    page_size: int
    total_pages: int
    jobs: List[PrintJobDetailResponse]

