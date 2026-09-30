from fastapi import APIRouter, Depends
from app.db.session import get_db
from app.db.models.print_server import PrintServerStatus
from app.schemas.print_server import HeartbeatRequest, HeartbeatResponse
from app.schemas.agent import AgentReleaseRequest, AgentJobStatusUpdate
from app.services.otp_service import otp_service
from app.services.job_service import job_service
from app.services.access_service import rate_limit
from app.api.dependencies import get_authenticated_agent
from app.config.settings import settings
from app.utils.common import now, fail

router = APIRouter(prefix='/api/agent', tags=['Authenticated print agents'])

@router.post('/heartbeat', response_model=HeartbeatResponse)
def heartbeat(req: HeartbeatRequest, server=Depends(get_authenticated_agent), db=Depends(get_db)):
    server.last_heartbeat = now()
    server.printer_state = req.printerState
    server.paper_state = req.paperState
    if req.mockPrinting and not settings.ALLOW_MOCK_PRINTING:
        server.printer_state = 'ERROR'
    if server.status != PrintServerStatus.DISABLED:
        server.status = PrintServerStatus.ONLINE
    db.commit()
    return HeartbeatResponse(status='OK', server_time=server.last_heartbeat)

@router.get('/jobs')
def jobs(server=Depends(get_authenticated_agent), db=Depends(get_db)):
    return job_service.get_pending_jobs_for_server(db, server.id)

@router.post('/jobs/{job_id}/claim')
def claim(job_id: str, server=Depends(get_authenticated_agent), db=Depends(get_db)):
    return job_service.claim(db, server.id, job_id)

@router.post('/release')
def release(req: AgentReleaseRequest, server=Depends(get_authenticated_agent), db=Depends(get_db)):
    rate_limit(db, 'otp-station:' + server.id, settings.MAX_OTP_ATTEMPTS, 60)
    job = otp_service.verify_and_release_job(db, server.id, req.otp)
    return {'jobId': job.id, 'orderId': job.order_id, 'status': job.status.value}

@router.post('/jobs/{job_id}/status')
def report(job_id: str, update: AgentJobStatusUpdate, server=Depends(get_authenticated_agent), db=Depends(get_db)):
    job_service.update_job_status(db, server.id, job_id, update)
    return {'message': 'Status recorded.'}
