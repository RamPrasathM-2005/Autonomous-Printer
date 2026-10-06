import io
import csv
import time
import secrets
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from sqlalchemy import func, text
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

from app.db.models.department import Department
from app.db.models.user import User, UserRole
from app.db.models.printer import Printer
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.order import Order
from app.db.models.document import Document
from app.config.security import hash_password
from app.schemas.admin import (
    AdminDashboardResponse,
    RecentPrintJob,
    DepartmentSummary,
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
from app.utils.errors import AppException

class AdminService:
    @staticmethod
    def get_dashboard_metrics(db: Session) -> AdminDashboardResponse:
        total_departments = db.query(Department).count()
        total_users = db.query(User).count()
        total_printers = db.query(Printer).count()
        
        # Load all print jobs with linked order and document
        query_results = (
            db.query(PrintJob, Order, Document, User, Printer, Department)
            .outerjoin(Order, Order.id == PrintJob.order_id)
            .outerjoin(Document, Document.id == Order.document_id)
            .outerjoin(User, User.id == Order.user_id)
            .outerjoin(Printer, Printer.id == PrintJob.printer_id)
            .outerjoin(Department, (Department.id == User.department_id) | (Department.name == Order.department) | (Department.code == Order.department))
            .order_by(PrintJob.created_at.desc())
            .all()
        )
        
        total_print_jobs = len(query_results)
        successful_print_jobs = 0
        failed_print_jobs = 0
        total_pages_printed = 0
        color_pages = 0
        bw_pages = 0
        color_jobs = 0
        bw_jobs = 0
        
        recent_activity: List[RecentPrintJob] = []
        
        # Maps for department aggregation
        dept_jobs_map: Dict[int, int] = {}
        dept_pages_map: Dict[int, int] = {}
        
        for idx, (job, order, doc, user, printer, dept) in enumerate(query_results):
            # Status check
            status_val = job.status.value if hasattr(job.status, "value") else str(job.status)
            is_success = status_val == PrintJobStatus.COMPLETED.value
            is_failed = status_val in [
                PrintJobStatus.FAILED.value,
                PrintJobStatus.FINAL_FAILED.value,
                PrintJobStatus.CANCELLED.value
            ]
            
            if is_success:
                successful_print_jobs += 1
            elif is_failed:
                failed_print_jobs += 1
                
            # Pages & Color check
            copies = order.copies if (order and order.copies) else 1
            pages_per_copy = (order.total_pages if order and order.total_pages else (doc.page_count if doc and doc.page_count else 1))
            job_pages = pages_per_copy * copies
            
            is_color = False
            if order and order.print_settings:
                c_val = order.print_settings.get("colour", order.print_settings.get("color", False))
                if isinstance(c_val, str):
                    is_color = c_val.lower() in ["true", "color", "colour", "1"]
                else:
                    is_color = bool(c_val)
                    
            if is_color:
                color_jobs += 1
            else:
                bw_jobs += 1
                
            if is_success:
                total_pages_printed += job_pages
                if is_color:
                    color_pages += job_pages
                else:
                    bw_pages += job_pages
                    
            # Department tracking
            dept_id = dept.id if dept else (user.department_id if user and user.department_id else None)
            if dept_id:
                dept_jobs_map[dept_id] = dept_jobs_map.get(dept_id, 0) + 1
                if is_success:
                    dept_pages_map[dept_id] = dept_pages_map.get(dept_id, 0) + job_pages
                    
            # Recent items (limit to 15)
            if idx < 15:
                # Find printer display name
                printer_name = "Default Printer"
                if printer and printer.display_name:
                    printer_name = printer.display_name
                elif order and order.print_settings:
                    printer_name = order.print_settings.get("printer_name") or order.print_settings.get("cups_printer_name") or "Local Station Printer"
                    
                recent_activity.append(RecentPrintJob(
                    id=job.id,
                    order_id=order.id if order else "",
                    document_name=doc.original_filename if doc else (order.id if order else "Document"),
                    user_name=(user.full_name or user.email) if user else "Walk-in Guest",
                    user_email=user.email if user else None,
                    department_name=dept.name if dept else (order.department if order and order.department else (user.department if user and user.department else "General")),
                    printer_name=printer_name,
                    pages=job_pages,
                    copies=copies,
                    is_color=is_color,
                    status=status_val,
                    created_at=job.created_at.strftime("%Y-%m-%d %H:%M:%S") if job.created_at else "",
                    completed_at=job.completed_at.strftime("%Y-%m-%d %H:%M:%S") if job.completed_at else None,
                    error_message=job.error_message
                ))
                
        # Calculate success rate
        decided_jobs = successful_print_jobs + failed_print_jobs
        success_rate = round((successful_print_jobs / decided_jobs * 100), 1) if decided_jobs > 0 else 100.0
        
        # Build department summaries
        all_departments = db.query(Department).all()
        department_summaries: List[DepartmentSummary] = []
        for d in all_departments:
            users_count = db.query(User).filter(
                (User.department_id == d.id) | (User.department == d.name) | (User.department == d.code)
            ).count()
            printers_count = db.query(Printer).filter(Printer.department_id == d.id).count()
            department_summaries.append(DepartmentSummary(
                id=d.id,
                code=d.code,
                name=d.name,
                users_count=users_count,
                printers_count=printers_count,
                jobs_count=dept_jobs_map.get(d.id, 0),
                pages_count=dept_pages_map.get(d.id, 0),
            ))
            
        return AdminDashboardResponse(
            total_departments=total_departments,
            total_users=total_users,
            total_printers=total_printers,
            total_print_jobs=total_print_jobs,
            total_pages_printed=total_pages_printed,
            successful_print_jobs=successful_print_jobs,
            failed_print_jobs=failed_print_jobs,
            color_pages=color_pages,
            bw_pages=bw_pages,
            color_jobs=color_jobs,
            bw_jobs=bw_jobs,
            success_rate=success_rate,
            recent_activity=recent_activity,
            department_summary=department_summaries
        )

    @staticmethod
    def get_printers(db: Session) -> List[AdminPrinterItem]:
        from datetime import datetime, timezone, timedelta
        from app.db.models.print_server import PrintServer, PrintServerStatus
        from app.config.settings import settings

        now = datetime.now(timezone.utc)
        timeout = timedelta(seconds=settings.HEARTBEAT_TIMEOUT_SECONDS)

        printers = db.query(Printer).all()
        results: List[AdminPrinterItem] = []

        for p in printers:
            server = db.query(PrintServer).filter(PrintServer.id == p.server_id).first()
            dept = db.query(Department).filter(Department.id == p.department_id).first() if p.department_id else None
            job_count = db.query(PrintJob).filter(PrintJob.printer_id == p.id).count()

            # Determine dynamic server status
            server_status = server.status.value if (server and hasattr(server.status, "value")) else ("OFFLINE" if not server else str(server.status))
            if server and server.status not in [PrintServerStatus.DISABLED, PrintServerStatus.MAINTENANCE]:
                hb = server.last_heartbeat
                if hb:
                    if hb.tzinfo is None:
                        hb = hb.replace(tzinfo=timezone.utc)
                    if hb < now - timeout:
                        server_status = "OFFLINE"
                else:
                    server_status = "OFFLINE"

            results.append(AdminPrinterItem(
                id=p.id,
                server_id=p.server_id,
                server_name=server.name if server else None,
                server_status=server_status,
                server_location=server.location if server else None,
                department_id=p.department_id,
                department_name=dept.name if dept else None,
                cups_printer_name=p.cups_printer_name,
                display_name=p.display_name,
                supports_color=p.supports_color,
                supports_duplex=p.supports_duplex,
                is_active=p.is_active,
                printer_state=server.printer_state if server else "UNKNOWN",
                paper_state=server.paper_state if server else "UNKNOWN",
                last_heartbeat=server.last_heartbeat.strftime("%Y-%m-%d %H:%M:%S") if (server and server.last_heartbeat) else None,
                total_jobs_count=job_count,
                created_at=p.created_at.strftime("%Y-%m-%d %H:%M:%S") if p.created_at else "",
            ))

        return results

    @staticmethod
    def update_printer(printer_id: str, data: AdminPrinterUpdate, db: Session) -> AdminPrinterItem:
        printer = db.query(Printer).filter(Printer.id == printer_id).first()
        if not printer:
            raise AppException(f"Printer '{printer_id}' not found", status_code=404)

        if data.display_name is not None:
            printer.display_name = data.display_name.strip()
        if data.department_id is not None:
            if data.department_id > 0:
                dept = db.query(Department).filter(Department.id == data.department_id).first()
                if not dept:
                    raise AppException("Selected department does not exist", status_code=400)
                printer.department_id = data.department_id
            else:
                printer.department_id = None
        if data.is_active is not None:
            printer.is_active = data.is_active

        db.commit()
        db.refresh(printer)

        printers = AdminService.get_printers(db)
        for p in printers:
            if p.id == printer.id:
                return p
        raise AppException("Failed to load updated printer", status_code=500)

    @staticmethod
    def update_print_server(server_id: str, data: AdminPrintServerUpdate, db: Session) -> bool:
        from app.db.models.print_server import PrintServer, PrintServerStatus
        server = db.query(PrintServer).filter(PrintServer.id == server_id).first()
        if not server:
            raise AppException(f"Print Server '{server_id}' not found", status_code=404)

        if data.status is not None:
            try:
                server.status = PrintServerStatus(data.status.upper())
            except ValueError:
                raise AppException(f"Invalid server status '{data.status}'", status_code=400)

        if data.location is not None:
            server.location = data.location.strip()

        db.commit()
        return True

    @staticmethod
    def get_users(
        db: Session,
        page: int = 1,
        limit: int = 15,
        search: Optional[str] = None,
        department_id: Optional[int] = None,
        role: Optional[str] = None,
        is_active: Optional[bool] = None,
    ) -> PaginatedAdminUsersResponse:
        import math
        query = db.query(User)

        if search:
            term = f"%{search.strip()}%"
            query = query.filter(
                (User.full_name.ilike(term)) |
                (User.email.ilike(term)) |
                (User.roll_number.ilike(term))
            )

        if department_id:
            query = query.filter(User.department_id == department_id)

        if role:
            query = query.filter(User.role == role)

        if is_active is not None:
            query = query.filter(User.is_active == is_active)

        total = query.count()
        total_pages = max(1, math.ceil(total / limit)) if limit > 0 else 1

        users = query.order_by(User.id.desc()).offset((page - 1) * limit).limit(limit).all()

        user_items: List[AdminUserItem] = []
        for u in users:
            dept = db.query(Department).filter(Department.id == u.department_id).first() if u.department_id else None
            orders = db.query(Order).filter(Order.user_id == u.id).all()
            total_orders = len(orders)
            total_pages_sum = sum(o.total_pages or 0 for o in orders)
            total_spent = sum(float(o.total_amount or 0.0) for o in orders)

            user_items.append(AdminUserItem(
                id=u.id,
                email=u.email,
                phone=getattr(u, "phone", None),
                full_name=u.full_name,
                roll_number=u.roll_number,
                department_id=u.department_id,
                department_name=dept.name if dept else (u.department or None),
                role=u.role.value if hasattr(u.role, "value") else str(u.role),
                is_active=u.is_active,
                total_orders=total_orders,
                total_pages=total_pages_sum,
                total_spent=round(total_spent, 2),
                created_at=u.created_at.strftime("%Y-%m-%d %H:%M:%S") if u.created_at else "",
            ))

        return PaginatedAdminUsersResponse(
            users=user_items,
            total=total,
            page=page,
            limit=limit,
            total_pages=total_pages,
        )

    @staticmethod
    def update_user(user_id: int, data: AdminUserUpdate, db: Session) -> AdminUserItem:
        from app.db.models.user import UserRole
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise AppException(f"User with ID {user_id} not found", status_code=404)

        if data.full_name is not None:
            user.full_name = data.full_name.strip()

        if data.department_id is not None:
            if data.department_id > 0:
                dept = db.query(Department).filter(Department.id == data.department_id).first()
                if not dept:
                    raise AppException("Selected department does not exist", status_code=400)
                user.department_id = data.department_id
                user.department = dept.name
            else:
                user.department_id = None
                user.department = None

        if data.role is not None:
            try:
                user.role = UserRole(data.role.upper())
            except ValueError:
                raise AppException(f"Invalid user role '{data.role}'", status_code=400)

        if data.is_active is not None:
            user.is_active = data.is_active

        db.commit()
        db.refresh(user)

        res = AdminService.get_users(db, page=1, limit=1, search=user.email or str(user.id))
        if res.users:
            for item in res.users:
                if item.id == user.id:
                    return item
        dept = db.query(Department).filter(Department.id == user.department_id).first() if user.department_id else None
        return AdminUserItem(
            id=user.id,
            email=user.email,
            phone=getattr(user, "phone", None),
            full_name=user.full_name,
            roll_number=user.roll_number,
            department_id=user.department_id,
            department_name=dept.name if dept else user.department,
            role=user.role.value if hasattr(user.role, "value") else str(user.role),
            is_active=user.is_active,
            total_orders=0,
            total_pages=0,
            total_spent=0.0,
            created_at=user.created_at.strftime("%Y-%m-%d %H:%M:%S") if user.created_at else "",
        )

    @staticmethod
    def get_settings(current_admin_email: str) -> AdminSystemSettings:
        from app.config.settings import settings
        return AdminSystemSettings(
            app_name=settings.APP_NAME,
            per_page_rate=settings.PER_PAGE_RATE,
            base_fee=settings.BASE_FEE,
            max_upload_mb=settings.MAX_UPLOAD_MB,
            otp_ttl_minutes=settings.OTP_TTL_MINUTES,
            max_otp_attempts=settings.MAX_OTP_ATTEMPTS,
            max_print_retries=settings.MAX_PRINT_RETRIES,
            heartbeat_timeout_seconds=settings.HEARTBEAT_TIMEOUT_SECONDS,
            email_provider=settings.EMAIL_PROVIDER,
            smtp_host=settings.SMTP_HOST,
            smtp_user=settings.SMTP_USER,
            current_admin_email=current_admin_email,
        )

    @staticmethod
    def update_settings(data: AdminSystemSettingsUpdate, current_admin_email: str) -> AdminSystemSettings:
        from app.config.settings import settings
        if data.per_page_rate is not None:
            if data.per_page_rate < 0:
                raise AppException("Per page rate must be non-negative", status_code=400)
            settings.PER_PAGE_RATE = float(data.per_page_rate)

        if data.base_fee is not None:
            if data.base_fee < 0:
                raise AppException("Base fee must be non-negative", status_code=400)
            settings.BASE_FEE = float(data.base_fee)

        if data.max_upload_mb is not None:
            if data.max_upload_mb <= 0:
                raise AppException("Max upload MB must be greater than zero", status_code=400)
            settings.MAX_UPLOAD_MB = int(data.max_upload_mb)

        if data.otp_ttl_minutes is not None:
            if data.otp_ttl_minutes <= 0:
                raise AppException("OTP TTL must be greater than zero", status_code=400)
            settings.OTP_TTL_MINUTES = int(data.otp_ttl_minutes)

        if data.max_otp_attempts is not None:
            if data.max_otp_attempts <= 0:
                raise AppException("Max OTP attempts must be greater than zero", status_code=400)
            settings.MAX_OTP_ATTEMPTS = int(data.max_otp_attempts)

        if data.max_print_retries is not None:
            if data.max_print_retries < 0:
                raise AppException("Max print retries cannot be negative", status_code=400)
            settings.MAX_PRINT_RETRIES = int(data.max_print_retries)

        if data.heartbeat_timeout_seconds is not None:
            if data.heartbeat_timeout_seconds < 5:
                raise AppException("Heartbeat timeout must be at least 5 seconds", status_code=400)
            settings.HEARTBEAT_TIMEOUT_SECONDS = int(data.heartbeat_timeout_seconds)

        return AdminService.get_settings(current_admin_email)

    @staticmethod
    def get_database_status(db: Session) -> AdminDatabaseStatusResponse:
        from app.config.settings import settings
        start = time.perf_counter()
        db.execute(text("SELECT 1"))
        latency_ms = round((time.perf_counter() - start) * 1000, 2)

        # Mask password in URL
        raw_url = settings.DATABASE_URL
        if "@" in raw_url:
            masked_url = raw_url.split("://")[0] + "://***:***@" + raw_url.split("@")[-1]
        else:
            masked_url = raw_url

        return AdminDatabaseStatusResponse(
            status="CONNECTED",
            database_url_masked=masked_url,
            environment=settings.ENVIRONMENT,
            latency_ms=latency_ms,
            total_users=db.query(User).count(),
            total_departments=db.query(Department).count(),
            total_printers=db.query(Printer).count(),
            total_orders=db.query(Order).count(),
            total_print_jobs=db.query(PrintJob).count(),
        )

    @staticmethod
    def generate_roster_template() -> bytes:
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Student Roster Template"
        ws.views.sheetView[0].showGridLines = True

        header_fill = PatternFill(start_color="1A56DB", end_color="1A56DB", fill_type="solid")
        header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
        regular_font = Font(name="Calibri", size=11)
        thin_border = Border(
            left=Side(style="thin", color="E2E8F0"),
            right=Side(style="thin", color="E2E8F0"),
            top=Side(style="thin", color="E2E8F0"),
            bottom=Side(style="thin", color="E2E8F0"),
        )

        headers = ["Roll Number", "Full Name", "Email", "Phone", "Department Code", "Department Name", "Role"]
        ws.append(headers)
        for col_idx in range(1, 8):
            c = ws.cell(row=1, column=col_idx)
            c.fill = header_fill
            c.font = header_font
            c.alignment = Alignment(horizontal="center")

        sample_rows = [
            ["2026-CS-001", "Jane Doe", "jane.doe@campus.edu", "9876543210", "CS", "Computer Science", "USER"],
            ["2026-MECH-002", "John Smith", "john.smith@campus.edu", "9876543211", "MECH", "Mechanical Engineering", "USER"],
            ["FAC-EE-101", "Dr. Alan Turing", "alan.turing@campus.edu", "9876543212", "EE", "Electrical Engineering", "USER"],
        ]

        for r_idx, row in enumerate(sample_rows, start=2):
            ws.append(row)
            for col_idx in range(1, 8):
                c = ws.cell(row=r_idx, column=col_idx)
                c.font = regular_font
                c.border = thin_border

        for col in ws.columns:
            max_len = max(len(str(cell.value or "")) for cell in col)
            col_letter = get_column_letter(col[0].column)
            ws.column_dimensions[col_letter].width = max(max_len + 4, 16)

        out = io.BytesIO()
        wb.save(out)
        return out.getvalue()

    @staticmethod
    def import_roster(file_bytes: bytes, filename: str, db: Session) -> UserImportSummary:
        records = []
        is_xlsx = filename.lower().endswith(".xlsx") or filename.lower().endswith(".xls")

        if is_xlsx:
            wb = openpyxl.load_workbook(io.BytesIO(file_bytes), data_only=True)
            ws = wb.active
            rows = list(ws.iter_rows(values_only=True))
            if not rows or len(rows) < 2:
                return UserImportSummary(total_rows=0, created=0, updated=0, failed=0, errors=["The uploaded spreadsheet is empty."])
            header = [str(h or "").strip().lower() for h in rows[0]]
            for row in rows[1:]:
                if not any(row):
                    continue
                row_dict = {}
                for idx, col_val in enumerate(row):
                    if idx < len(header):
                        row_dict[header[idx]] = str(col_val or "").strip()
                records.append(row_dict)
        else:
            text_content = file_bytes.decode("utf-8-sig", errors="replace")
            reader = csv.DictReader(io.StringIO(text_content))
            for r in reader:
                records.append({k.strip().lower(): str(v or "").strip() for k, v in r.items() if k})

        if not records:
            return UserImportSummary(total_rows=0, created=0, updated=0, failed=0, errors=["No valid records found in file."])

        created_cnt = 0
        updated_cnt = 0
        failed_cnt = 0
        errors: List[str] = []

        # Cache existing departments
        depts_by_code = {d.code.upper(): d for d in db.query(Department).all()}
        depts_by_name = {d.name.lower(): d for d in db.query(Department).all()}

        for row_idx, r in enumerate(records, start=2):
            email = r.get("email", "")
            full_name = r.get("full name", r.get("name", ""))
            roll_number = r.get("roll number", r.get("roll", r.get("roll_number", "")))
            phone = r.get("phone", r.get("mobile", ""))
            dept_code = r.get("department code", r.get("dept_code", r.get("dept", ""))).upper()
            dept_name = r.get("department name", r.get("department", ""))
            role_str = r.get("role", "USER").upper()

            if not email or "@" not in email:
                failed_cnt += 1
                errors.append(f"Row {row_idx}: Missing or invalid email '{email}'")
                continue

            target_dept = None
            if dept_code and dept_code in depts_by_code:
                target_dept = depts_by_code[dept_code]
            elif dept_name and dept_name.lower() in depts_by_name:
                target_dept = depts_by_name[dept_name.lower()]
            elif dept_code or dept_name:
                # Auto-create missing department
                new_code = dept_code or dept_name[:4].upper()
                new_name = dept_name or dept_code
                target_dept = Department(code=new_code, name=new_name, description=f"Imported Department {new_name}")
                db.add(target_dept)
                db.flush()
                depts_by_code[new_code] = target_dept
                depts_by_name[new_name.lower()] = target_dept

            # Check if user exists by email or roll_number
            existing_user = db.query(User).filter(User.email == email).first()
            if not existing_user and roll_number:
                existing_user = db.query(User).filter(User.roll_number == roll_number).first()

            role_val = UserRole.ADMIN if role_str == "ADMIN" else UserRole.USER

            if existing_user:
                if full_name:
                    existing_user.full_name = full_name
                if roll_number:
                    existing_user.roll_number = roll_number
                if target_dept:
                    existing_user.department_id = target_dept.id
                    existing_user.department = target_dept.name
                existing_user.role = role_val
                updated_cnt += 1
            else:
                default_pw = secrets.token_urlsafe(16)
                new_user = User(
                    email=email,
                    full_name=full_name or email.split("@")[0],
                    roll_number=roll_number or None,
                    password_hash=hash_password(default_pw),
                    department_id=target_dept.id if target_dept else None,
                    department=target_dept.name if target_dept else None,
                    role=role_val,
                    is_active=True,
                )
                db.add(new_user)
                created_cnt += 1

        db.commit()

        return UserImportSummary(
            total_rows=len(records),
            created=created_cnt,
            updated=updated_cnt,
            failed=failed_cnt,
            errors=errors[:15],
        )

admin_service = AdminService()

