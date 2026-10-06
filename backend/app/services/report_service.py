from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_

from app.db.models.department import Department
from app.db.models.user import User
from app.db.models.printer import Printer
from app.db.models.order import Order
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.document import Document
from app.schemas.report import (
    DepartmentReportResponse,
    DepartmentSummaryReport,
    UserReportStat,
    PrinterUtilizationStat,
    PrintJobDetailResponse,
    PaginatedPrintJobsResponse,
)
from app.utils.errors import AppException
from fastapi import status

class ReportService:
    @staticmethod
    def generate_department_report(
        db: Session,
        department_id: Optional[int] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        user_id: Optional[int] = None,
        printer_id: Optional[str] = None,
        job_status: Optional[str] = None,
        is_color: Optional[bool] = None,
    ) -> DepartmentReportResponse:
        dept = None
        dept_name = "All Departments"
        dept_code = "ALL"

        if department_id is not None:
            dept = db.query(Department).filter(Department.id == department_id).first()
            if not dept:
                raise AppException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    error_code="DEPARTMENT_NOT_FOUND",
                    message=f"Department with ID {department_id} not found."
                )
            dept_name = dept.name
            dept_code = dept.code

        # Base query joining PrintJob, Order, User, Printer, Document
        query = (
            db.query(PrintJob, Order, Document, User, Printer)
            .join(Order, Order.id == PrintJob.order_id)
            .outerjoin(Document, Document.id == Order.document_id)
            .outerjoin(User, User.id == Order.user_id)
            .outerjoin(Printer, Printer.id == PrintJob.printer_id)
        )

        # Department filter
        if dept:
            query = query.filter(
                or_(
                    User.department_id == dept.id,
                    Order.department == dept.name,
                    Order.department == dept.code,
                )
            )

        # Date range filter
        parsed_start = None
        parsed_end = None
        if start_date:
            try:
                parsed_start = datetime.fromisoformat(start_date.replace("Z", "+00:00"))
                query = query.filter(PrintJob.created_at >= parsed_start)
            except Exception:
                pass

        if end_date:
            try:
                parsed_end = datetime.fromisoformat(end_date.replace("Z", "+00:00"))
                query = query.filter(PrintJob.created_at <= parsed_end)
            except Exception:
                pass

        # User filter
        if user_id is not None:
            query = query.filter(Order.user_id == user_id)

        # Printer filter
        if printer_id:
            query = query.filter(PrintJob.printer_id == printer_id)

        # Job Status filter
        if job_status and job_status.strip():
            st_clean = job_status.strip().upper()
            query = query.filter(PrintJob.status == st_clean)

        records = query.order_by(PrintJob.created_at.desc()).all()

        # Aggregation variables
        total_jobs = 0
        total_pages = 0
        successful_jobs = 0
        failed_jobs = 0
        cancelled_jobs = 0
        color_pages = 0
        bw_pages = 0
        color_jobs = 0
        bw_jobs = 0
        total_amount = 0.0

        user_data_map: Dict[int, Dict[str, Any]] = {}
        printer_data_map: Dict[str, Dict[str, Any]] = {}

        for job, order, doc, user, printer in records:
            # Color/BW filter if requested
            job_is_color = False
            if order and order.print_settings:
                c_val = order.print_settings.get("colour", order.print_settings.get("color", False))
                if isinstance(c_val, str):
                    job_is_color = c_val.lower() in ["true", "color", "colour", "1"]
                else:
                    job_is_color = bool(c_val)

            if is_color is not None and job_is_color != is_color:
                continue

            total_jobs += 1

            # Job status evaluation
            st_val = job.status.value if hasattr(job.status, "value") else str(job.status)
            is_success = st_val == PrintJobStatus.COMPLETED.value
            is_failed = st_val in [PrintJobStatus.FAILED.value, PrintJobStatus.FINAL_FAILED.value]
            is_cancelled = st_val == PrintJobStatus.CANCELLED.value

            if is_success:
                successful_jobs += 1
            elif is_failed:
                failed_jobs += 1
            elif is_cancelled:
                cancelled_jobs += 1

            # Pages calculation
            copies = order.copies if (order and order.copies) else 1
            pages_per_copy = (order.total_pages if order and order.total_pages else (doc.page_count if doc and doc.page_count else 1))
            job_pages = pages_per_copy * copies
            total_pages += job_pages

            if order and order.amount:
                total_amount += float(order.amount)

            if job_is_color:
                color_jobs += 1
                color_pages += job_pages
            else:
                bw_jobs += 1
                bw_pages += job_pages

            # User aggregation
            u_key = user.id if user else 0
            if u_key not in user_data_map:
                user_data_map[u_key] = {
                    "user_id": user.id if user else None,
                    "user_name": (user.full_name or user.email) if user else "Walk-in Guest",
                    "email": user.email if user else None,
                    "roll_number": user.roll_number if user else None,
                    "total_jobs": 0,
                    "successful_jobs": 0,
                    "total_pages": 0,
                    "color_pages": 0,
                    "bw_pages": 0,
                }
            user_data_map[u_key]["total_jobs"] += 1
            user_data_map[u_key]["total_pages"] += job_pages
            if is_success:
                user_data_map[u_key]["successful_jobs"] += 1
            if job_is_color:
                user_data_map[u_key]["color_pages"] += job_pages
            else:
                user_data_map[u_key]["bw_pages"] += job_pages

            # Printer aggregation
            p_id = printer.id if printer else (
                order.print_settings.get("printer_id", "unassigned") if order and order.print_settings else "unassigned"
            )
            p_name = printer.display_name if printer else (
                order.print_settings.get("printer_name", "Station Printer") if order and order.print_settings else "Station Printer"
            )
            cups_name = printer.cups_printer_name if printer else (
                order.print_settings.get("cups_printer_name", "default_cups") if order and order.print_settings else "default_cups"
            )

            if p_id not in printer_data_map:
                printer_data_map[p_id] = {
                    "printer_id": p_id,
                    "printer_name": p_name,
                    "cups_printer_name": cups_name,
                    "total_jobs": 0,
                    "successful_jobs": 0,
                    "total_pages": 0,
                }
            printer_data_map[p_id]["total_jobs"] += 1
            printer_data_map[p_id]["total_pages"] += job_pages
            if is_success:
                printer_data_map[p_id]["successful_jobs"] += 1

        # Calculate averages and lists
        avg_pages = round(total_pages / total_jobs, 2) if total_jobs > 0 else 0.0

        user_stats: List[UserReportStat] = []
        for u in user_data_map.values():
            s_rate = round(u["successful_jobs"] / u["total_jobs"] * 100, 1) if u["total_jobs"] > 0 else 100.0
            user_stats.append(
                UserReportStat(
                    user_id=u["user_id"],
                    user_name=u["user_name"],
                    email=u["email"],
                    roll_number=u["roll_number"],
                    total_jobs=u["total_jobs"],
                    total_pages=u["total_pages"],
                    color_pages=u["color_pages"],
                    bw_pages=u["bw_pages"],
                    success_rate=s_rate,
                )
            )
        user_stats.sort(key=lambda x: x.total_pages, reverse=True)

        printer_stats: List[PrinterUtilizationStat] = []
        for p in printer_data_map.values():
            p_util = round(p["total_pages"] / total_pages * 100, 1) if total_pages > 0 else 0.0
            s_rate = round(p["successful_jobs"] / p["total_jobs"] * 100, 1) if p["total_jobs"] > 0 else 100.0
            printer_stats.append(
                PrinterUtilizationStat(
                    printer_id=p["printer_id"],
                    printer_name=p["printer_name"],
                    cups_printer_name=p["cups_printer_name"],
                    total_jobs=p["total_jobs"],
                    total_pages=p["total_pages"],
                    utilization_percentage=p_util,
                    success_rate=s_rate,
                )
            )
        printer_stats.sort(key=lambda x: x.total_pages, reverse=True)

        summary = DepartmentSummaryReport(
            department_id=dept.id if dept else None,
            department_name=dept_name,
            department_code=dept_code,
            start_date=start_date,
            end_date=end_date,
            total_jobs=total_jobs,
            total_pages=total_pages,
            successful_jobs=successful_jobs,
            failed_jobs=failed_jobs,
            cancelled_jobs=cancelled_jobs,
            color_pages=color_pages,
            bw_pages=bw_pages,
            color_jobs=color_jobs,
            bw_jobs=bw_jobs,
            avg_pages_per_job=avg_pages,
            total_amount=round(total_amount, 2),
        )

        return DepartmentReportResponse(
            summary=summary,
            user_stats=user_stats,
            printer_stats=printer_stats,
        )

    @staticmethod
    def _format_job_detail(
        job: PrintJob,
        order: Optional[Order],
        doc: Optional[Document],
        user: Optional[User],
        printer: Optional[Printer],
        dept: Optional[Department] = None,
    ) -> PrintJobDetailResponse:
        is_job_color = False
        is_duplex = False
        print_settings_dict = {}
        if order and order.print_settings:
            if isinstance(order.print_settings, dict):
                print_settings_dict = order.print_settings
            c_val = print_settings_dict.get("colour", print_settings_dict.get("color", False))
            if isinstance(c_val, str):
                is_job_color = c_val.lower() in ["true", "color", "colour", "1"]
            else:
                is_job_color = bool(c_val)
            sides = str(print_settings_dict.get("sides", "one-sided")).lower()
            is_duplex = "two" in sides or "duplex" in sides

        pages = order.total_pages if order and order.total_pages else (doc.page_count if doc else 1)
        copies = order.copies if order and order.copies else 1
        total_sheets = pages * copies
        if is_duplex:
            total_sheets = ((pages + 1) // 2) * copies

        dept_id = dept.id if dept else (user.department_id if user else None)
        dept_name = dept.name if dept else (user.department if user and user.department else (order.department if order and order.department else "General"))

        st_val = job.status.value if hasattr(job.status, "value") else str(job.status)

        return PrintJobDetailResponse(
            id=job.id,
            order_id=job.order_id,
            user_id=user.id if user else (order.user_id if order else None),
            user_name=user.full_name if user and user.full_name else (user.email if user and user.email else "Customer"),
            user_email=user.email if user else None,
            user_roll_number=user.roll_number if user else (order.roll_number if order else None),
            department_id=dept_id,
            department_name=dept_name,
            printer_id=printer.id if printer else job.printer_id,
            printer_name=printer.display_name if printer else "Local Station",
            cups_printer_name=printer.cups_printer_name if printer else "Default Queue",
            cups_job_id=job.cups_job_id,
            document_name=doc.original_filename if doc else "Document",
            document_id=doc.id if doc else (order.document_id if order else None),
            file_size_bytes=doc.file_size if doc else None,
            mime_type=doc.mime_type if doc else None,
            pages=pages,
            copies=copies,
            total_sheets=total_sheets,
            is_color=is_job_color,
            is_duplex=is_duplex,
            print_settings=print_settings_dict,
            amount=float(order.amount) if order and order.amount is not None else 0.0,
            currency=order.currency if order and order.currency else "INR",
            status=st_val,
            retry_count=job.retry_count or 0,
            error_code=job.error_code,
            error_message=job.error_message,
            created_at=job.created_at.isoformat() if job.created_at else "",
            completed_at=job.completed_at.isoformat() if job.completed_at else None,
        )

    @staticmethod
    def get_print_job_logs(
        db: Session,
        department_id: Optional[int] = None,
        user_id: Optional[int] = None,
        printer_id: Optional[str] = None,
        job_status: Optional[str] = None,
        is_color: Optional[bool] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        search: Optional[str] = None,
        page: int = 1,
        page_size: int = 20,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> PaginatedPrintJobsResponse:
        dept = None
        if department_id is not None:
            dept = db.query(Department).filter(Department.id == department_id).first()

        query = (
            db.query(PrintJob, Order, Document, User, Printer, Department)
            .join(Order, Order.id == PrintJob.order_id)
            .outerjoin(Document, Document.id == Order.document_id)
            .outerjoin(User, User.id == Order.user_id)
            .outerjoin(Printer, Printer.id == PrintJob.printer_id)
            .outerjoin(Department, Department.id == User.department_id)
        )

        if dept:
            query = query.filter(
                or_(
                    User.department_id == dept.id,
                    Order.department == dept.name,
                    Order.department == dept.code,
                )
            )

        if start_date:
            try:
                parsed_start = datetime.fromisoformat(start_date.replace("Z", "+00:00"))
                query = query.filter(PrintJob.created_at >= parsed_start)
            except Exception:
                pass

        if end_date:
            try:
                parsed_end = datetime.fromisoformat(end_date.replace("Z", "+00:00"))
                query = query.filter(PrintJob.created_at <= parsed_end)
            except Exception:
                pass

        if user_id is not None:
            query = query.filter(Order.user_id == user_id)

        if printer_id:
            query = query.filter(PrintJob.printer_id == printer_id)

        if job_status and job_status.strip():
            query = query.filter(PrintJob.status == job_status.strip().upper())

        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    PrintJob.id.ilike(term),
                    PrintJob.cups_job_id.ilike(term),
                    Order.id.ilike(term),
                    Document.original_filename.ilike(term),
                    User.full_name.ilike(term),
                    User.email.ilike(term),
                    User.roll_number.ilike(term),
                    Order.roll_number.ilike(term),
                    Printer.display_name.ilike(term),
                    Department.name.ilike(term),
                )
            )

        # Ordering
        if sort_by == "pages":
            order_col = Order.total_pages.asc() if sort_order.lower() == "asc" else Order.total_pages.desc()
        elif sort_by == "amount":
            order_col = Order.amount.asc() if sort_order.lower() == "asc" else Order.amount.desc()
        else:
            order_col = PrintJob.created_at.asc() if sort_order.lower() == "asc" else PrintJob.created_at.desc()

        records = query.order_by(order_col).all()

        formatted_jobs: List[PrintJobDetailResponse] = []
        for job, order, doc, user, printer, d in records:
            job_resp = ReportService._format_job_detail(job, order, doc, user, printer, d)
            if is_color is not None and job_resp.is_color != is_color:
                continue
            formatted_jobs.append(job_resp)

        total = len(formatted_jobs)
        page = max(1, page)
        page_size = max(1, min(5000, page_size))
        total_pages = (total + page_size - 1) // page_size if total > 0 else 1
        start_idx = (page - 1) * page_size
        end_idx = start_idx + page_size
        paged_jobs = formatted_jobs[start_idx:end_idx]

        return PaginatedPrintJobsResponse(
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
            jobs=paged_jobs,
        )

    @staticmethod
    def get_print_job_detail(db: Session, job_id: str) -> PrintJobDetailResponse:
        record = (
            db.query(PrintJob, Order, Document, User, Printer, Department)
            .join(Order, Order.id == PrintJob.order_id)
            .outerjoin(Document, Document.id == Order.document_id)
            .outerjoin(User, User.id == Order.user_id)
            .outerjoin(Printer, Printer.id == PrintJob.printer_id)
            .outerjoin(Department, Department.id == User.department_id)
            .filter(PrintJob.id == job_id)
            .first()
        )
        if not record:
            raise AppException(
                status_code=status.HTTP_404_NOT_FOUND,
                error_code="PRINT_JOB_NOT_FOUND",
                message=f"Print job '{job_id}' not found.",
            )
        job, order, doc, user, printer, dept = record
        return ReportService._format_job_detail(job, order, doc, user, printer, dept)

report_service = ReportService()

