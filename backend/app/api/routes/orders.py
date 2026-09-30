from fastapi import APIRouter, Depends, Header
from app.db.session import get_db
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment, PaymentStatus
from app.schemas.order import OrderCreateRequest, OrderResponse, OTPResponse
from app.schemas.agent import AgentReleaseRequest
from app.services.order_service import order_service
from app.services.otp_service import otp_service
from app.services.access_service import current_session, owned_order, rate_limit
from app.utils.common import fail
from app.services.print_authorization import require_print_authorization

router = APIRouter(prefix='/api/orders', tags=['Orders'])

def response(order):
    return OrderResponse(id=order.id, user_id=order.user_id, document_id=order.document_id,
        print_server_id=order.print_server_id, print_settings=order.print_settings,
        total_pages=order.total_pages, copies=order.copies, amount=float(order.amount),
        currency=order.currency, status=order.status, created_at=order.created_at)

@router.post('', response_model=OrderResponse, status_code=201)
def create_order(req: OrderCreateRequest, session=Depends(current_session), db=Depends(get_db),
                 idempotency_key: str = Header(..., min_length=16, max_length=128, alias='Idempotency-Key')):
    return response(order_service.create_order(db, req, session_id=session.id, idempotency_key=idempotency_key))

@router.get('', response_model=list[OrderResponse])
def list_orders(session=Depends(current_session), db=Depends(get_db)):
    return [response(o) for o in db.query(Order).filter_by(session_id=session.id).order_by(Order.created_at.desc()).limit(50)]

@router.get('/{order_id}', response_model=OrderResponse)
def get_order(order_id: str, session=Depends(current_session), db=Depends(get_db)):
    return response(owned_order(db, order_id, session))

@router.get('/{order_id}/otp', response_model=OTPResponse)
def get_order_otp(order_id: str, session=Depends(current_session), db=Depends(get_db)):
    order = owned_order(db, order_id, session)
    payment = db.query(Payment).filter_by(order_id=order_id).first()
    if order.status != OrderStatus.WAITING_FOR_OTP:
        fail('OTP_NOT_AVAILABLE', 'An unreleased order is required.', 409)
    require_print_authorization(order, payment)
    code, expires = otp_service.get_otp_for_order(db, order.id)
    return OTPResponse(order_id=order.id, otp=code, expires_at=expires)

@router.post('/{order_id}/release')
def release_order(order_id: str, req: AgentReleaseRequest, session=Depends(current_session), db=Depends(get_db)):
    order = owned_order(db, order_id, session)
    rate_limit(db, 'release-session:' + session.id, 5, 60)
    job = otp_service.verify_and_release_job(db, order.print_server_id, req.otp, order_id=order.id)
    return {'status': 'RELEASED', 'orderId': order.id, 'jobId': job.id}

@router.post('/{order_id}/test-print')
def test_print(order_id: str, session=Depends(current_session), db=Depends(get_db)):
    from app.services.test_print_service import authorize_test_print
    owned_order(db, order_id, session)
    rate_limit(db, 'test-print:' + session.id, 5, 60)
    return authorize_test_print(db, order_id)
