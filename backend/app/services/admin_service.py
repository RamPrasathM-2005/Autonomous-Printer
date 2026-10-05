from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.models.department import Department
from app.db.models.user import User
from app.db.models.printer import Printer
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.order import Order
from app.db.models.document import Document
from app.schemas.admin import AdminDashboardResponse, RecentPrintJob, DepartmentSummary

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

admin_service = AdminService()
