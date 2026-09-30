from fastapi import APIRouter, Depends, Request, Header
from app.db.session import get_db
from app.schemas.payment import PaymentCreateRequest, PaymentCreateResponse, PaymentVerifyRequest
from app.services.payment_service import payment_service
from app.services.access_service import current_session, owned_order, rate_limit

router = APIRouter(prefix='/api/payments', tags=['Payments'])

@router.get('/capabilities')
def payment_capabilities(session=Depends(current_session)):
    from app.services.print_authorization import unpaid_test_enabled
    from app.config.settings import settings
    return {'unpaidTestPrinting': unpaid_test_enabled(),
            'paymentMode': 'test' if settings.RAZORPAY_KEY_ID.startswith('rzp_test_') else 'live'}

@router.post('/create', response_model=PaymentCreateResponse, status_code=201)
def create_payment(req: PaymentCreateRequest, session=Depends(current_session), db=Depends(get_db)):
    owned_order(db, req.orderId, session)
    rate_limit(db, 'payment-create:' + session.id, 10, 60)
    return payment_service.create_payment(db, req.orderId)

@router.post('/verify')
def verify_payment(req: PaymentVerifyRequest, session=Depends(current_session), db=Depends(get_db)):
    owned_order(db, req.orderId, session)
    rate_limit(db, 'payment-verify:' + session.id, 10, 60)
    return payment_service.verify_or_confirm_payment(db, req.orderId, req.razorpayOrderId,
        req.razorpayPaymentId, req.razorpaySignature)

@router.post('/reconcile')
def reconcile_payment(req: PaymentCreateRequest, session=Depends(current_session), db=Depends(get_db)):
    owned_order(db, req.orderId, session)
    rate_limit(db, 'payment-reconcile:' + session.id, 5, 60)
    return payment_service.reconcile(db, req.orderId)

@router.post('/webhook', status_code=202)
async def webhook(request: Request, db=Depends(get_db),
    signature: str | None = Header(None, alias='X-Razorpay-Signature'),
    event_id: str | None = Header(None, alias='X-Razorpay-Event-Id')):
    return payment_service.handle_webhook(db, await request.body(), signature, event_id)
