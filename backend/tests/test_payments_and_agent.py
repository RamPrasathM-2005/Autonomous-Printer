import hashlib
import hmac
import json
import pytest
from app.config.settings import settings
from app.db.models.otp import OTP
from app.db.models.payment import Payment, PaymentStatus
from app.db.models.print_job import PrintJob
from app.db.models.security import WebhookEvent
from app.services.payment_service import payment_service
from tests.conftest import create_order, start_payment, paid_order, proof

@pytest.mark.parametrize('signature',['test_sig','dev_simulated_sig','', '0'*64])
def test_forged_payment_does_not_issue_otp(client,test_print_server,signature):
    order=create_order(client,test_print_server)
    pay=start_payment(client,order)
    res=client.post('/api/payments/verify',json={'orderId':order['id'],'razorpayOrderId':pay['razorpayOrderId'],
        'razorpayPaymentId':'pay_forged','razorpaySignature':signature})
    assert res.status_code in (400,422)
    assert client.get('/api/orders/'+order['id']+'/otp').status_code==409

@pytest.mark.parametrize('field,value',[('amount',1),('currency','USD'),('order_id','order_other'),('captured',False),('status','authorized'),('amount_refunded',1)])
def test_valid_signature_cannot_override_provider_state(client,test_print_server,fake_gateway,field,value):
    order=create_order(client,test_print_server);pay=start_payment(client,order)
    remote=fake_gateway.capture(pay['razorpayOrderId']);valid=proof(order,remote)
    remote[field]=value
    res=client.post('/api/payments/verify',json=valid)
    assert res.status_code==409,res.text
    assert client.get('/api/orders/'+order['id']+'/otp').status_code==409

def test_capture_idempotent_and_otp_single_use(client,test_print_server,test_agent_token,fake_gateway,db_session):
    order,remote=paid_order(client,test_print_server,fake_gateway)
    otp=client.get('/api/orders/'+order['id']+'/otp').json()['otp']
    assert client.post('/api/payments/verify',json=proof(order,remote)).status_code==200
    assert db_session.query(OTP).count()==1 and db_session.query(PrintJob).count()==1
    headers={'Authorization':'Bearer '+test_agent_token}
    release=client.post('/api/agent/release',headers=headers,json={'otp':otp})
    assert release.status_code==200,release.text
    job=release.json()['jobId']
    assert client.post('/api/agent/release',headers=headers,json={'otp':otp}).status_code==400
    claim=client.post('/api/agent/jobs/'+job+'/claim',headers=headers)
    assert claim.status_code==200
    assert client.post('/api/agent/jobs/'+job+'/claim',headers=headers).status_code==409
    assert client.post('/api/agent/jobs/'+job+'/status',headers=headers,
        json={'status':'COMPLETED','claimToken':'bad'*16,'cupsJobId':'123'}).status_code==403
    report=client.post('/api/agent/jobs/'+job+'/status',headers=headers,
        json={'status':'COMPLETED','claimToken':claim.json()['claimToken'],'cupsJobId':'123'})
    assert report.status_code==200,report.text
    assert client.get('/api/orders/'+order['id']).json()['status']=='COMPLETED'
    assert client.post('/api/payments/verify',json=proof(order,remote)).status_code==200
    assert client.get('/api/orders/'+order['id']).json()['status']=='COMPLETED'
    assert client.get('/api/orders/'+order['id']+'/otp').status_code==409

def test_gateway_outage_never_creates_fake_payment(client,test_print_server,fake_gateway,db_session):
    order=create_order(client,test_print_server);fake_gateway.unavailable=True
    assert client.post('/api/payments/create',json={'orderId':order['id']}).status_code==502
    row=db_session.query(Payment).one()
    assert row.razorpay_order_id is None and row.creation_state=='UNKNOWN'
    assert client.post('/api/payments/create',json={'orderId':order['id']}).status_code==409
    assert fake_gateway.creates==0

def test_reconcile_recovers_lost_checkout_callback(client,test_print_server,fake_gateway):
    order=create_order(client,test_print_server);pay=start_payment(client,order)
    fake_gateway.capture(pay['razorpayOrderId'])
    res=client.post('/api/payments/reconcile',json={'orderId':order['id']})
    assert res.status_code==200,res.text
    assert client.get('/api/orders/'+order['id']+'/otp').status_code==200

def webhook(client,body,event_id='evt_1',signature=None):
    raw=json.dumps(body).encode()
    sig=signature if signature is not None else hmac.new(settings.RAZORPAY_WEBHOOK_SECRET.encode(),raw,hashlib.sha256).hexdigest()
    return client.post('/api/payments/webhook',content=raw,headers={'Content-Type':'application/json',
        'X-Razorpay-Signature':sig,'X-Razorpay-Event-Id':event_id})

@pytest.mark.parametrize('signature',['test_sig','dev_simulated_sig','', '0'*64])
def test_webhook_always_requires_hmac(client,signature):
    assert webhook(client,{'event':'payment.captured'},signature=signature).status_code==400

def test_webhook_durable_duplicate_and_reorder(client,test_print_server,fake_gateway,db_session):
    from app.worker import process_event
    order=create_order(client,test_print_server);pay=start_payment(client,order)
    remote=fake_gateway.capture(pay['razorpayOrderId'])
    body={'event':'payment.captured','payload':{'payment':{'entity':remote}}}
    assert webhook(client,body).status_code==202
    assert webhook(client,body).status_code==202
    assert db_session.query(WebhookEvent).count()==1
    assert client.get('/api/orders/'+order['id']+'/otp').status_code==409
    process_event(db_session,db_session.get(WebhookEvent,'evt_1'))
    assert client.get('/api/orders/'+order['id']+'/otp').status_code==200
    body['event']='payment.failed'
    assert webhook(client,body).status_code==409
    assert webhook(client,body,event_id='evt_2').status_code==202
    process_event(db_session,db_session.get(WebhookEvent,'evt_2'))
    assert db_session.query(Payment).one().status==PaymentStatus.CAPTURED
