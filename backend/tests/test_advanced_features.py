import pytest
from datetime import timedelta
from app.config.security import hash_token
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.document import Document
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment
from app.db.models.refund import Refund, RefundStatus
from app.db.models.otp import OTP
from app.services.refund_service import refund_service
from app.services.storage_service import storage_service
from app.utils.common import now
from tests.conftest import create_order,paid_order,create_sample_pdf

def test_cross_session_orders_documents_payments_denied(client,test_print_server):
    order=create_order(client,test_print_server)
    token=client.post('/api/sessions').json()['token']
    other={'Authorization':'Bearer '+token}
    for path in ['/api/orders/'+order['id'],'/api/orders/'+order['id']+'/otp','/api/documents/'+order['documentId']]:
        assert client.get(path,headers=other).status_code==404
    assert client.post('/api/payments/create',json={'orderId':order['id']},headers=other).status_code==404
    assert client.get('/api/orders',headers=other).json()==[]
    assert client.delete('/api/documents/'+order['documentId'],headers=other).status_code==404
    assert client.post('/api/orders',headers=other,json={'documentId':order['documentId'],'printServerId':test_print_server.id}).status_code==404

def test_anonymous_upload_and_listing_denied(client):
    client.headers.pop('Authorization')
    assert client.get('/api/orders').status_code==401
    assert client.post('/api/documents/upload',files={'file':('x.pdf',create_sample_pdf(),'application/pdf')}).status_code==401

def test_wrong_station_cannot_release(client,test_print_server,test_agent_token,fake_gateway,db_session):
    order,_=paid_order(client,test_print_server,fake_gateway)
    code=client.get('/api/orders/'+order['id']+'/otp').json()['otp']
    other='another-agent-token-'+ 'z'*32
    db_session.add(PrintServer(id='OTHER',name='Other',device_token_hash=hash_token(other),status=PrintServerStatus.ONLINE))
    db_session.commit()
    assert client.post('/api/agent/release',headers={'Authorization':'Bearer '+other},json={'otp':code}).status_code==400

def test_otp_attempts_limited_without_victim_lockout(client,test_print_server,test_agent_token):
    for _ in range(5):
        assert client.post('/api/agent/release',headers={'Authorization':'Bearer '+test_agent_token},json={'otp':'000000'}).status_code==400
    assert client.post('/api/agent/release',headers={'Authorization':'Bearer '+test_agent_token},json={'otp':'000000'}).status_code==429

def test_order_idempotency(client,test_print_server):
    up=client.post('/api/documents/upload',files={'file':('x.pdf',create_sample_pdf(),'application/pdf')}).json()
    body={'documentId':up['documentId'],'printServerId':test_print_server.id}
    headers={'Idempotency-Key':'repeat-key-123456789'}
    first=client.post('/api/orders',json=body,headers=headers)
    repeat=client.post('/api/orders',json=body,headers=headers)
    assert first.status_code==repeat.status_code==201
    assert first.json()['id']==repeat.json()['id']
    body['settings']={'copies':2}
    assert client.post('/api/orders',json=body,headers=headers).status_code==409

@pytest.mark.parametrize('options',[{'copies':0},{'copies':-1},{'copies':True},{'copies':101},{'colour':'false'},
 {'sides':'--evil'},{'paperSize':'../../x'},{'orientation':'injected'},{'amount':0}])
def test_tampered_print_settings_rejected(client,test_print_server,options):
    assert client.post('/api/orders',json={'documentId':'doc','printServerId':test_print_server.id,'settings':options}).status_code==422

def test_storage_tampering_blocks_release(client,test_print_server,fake_gateway,db_session):
    order,_=paid_order(client,test_print_server,fake_gateway)
    otp=client.get('/api/orders/'+order['id']+'/otp').json()['otp']
    doc=db_session.get(Document,order['documentId'])
    storage_service.resolve_storage_key(doc.storage_key).write_bytes(b'changed')
    res=client.post('/api/orders/'+order['id']+'/release',json={'otp':otp})
    assert res.status_code==409 and res.json()['error']=='DOCUMENT_INTEGRITY'

@pytest.mark.parametrize('key',['../outside.pdf','/etc/passwd','C:/secret','documents/../../secret','documents/a.pdf:stream'])
def test_storage_path_escape_rejected(key):
    from app.utils.errors import AppException
    with pytest.raises(AppException): storage_service.resolve_storage_key(key)

def test_refund_not_completed_until_provider_processed(client,test_print_server,fake_gateway,db_session):
    order,remote=paid_order(client,test_print_server,fake_gateway)
    record=db_session.get(Order,order['id']);record.status=OrderStatus.EXPIRED;db_session.commit()
    refund=refund_service.process_refund(db_session,order['id'],'Expired')
    refund_service.process(db_session,refund.id)
    db_session.refresh(refund)
    assert refund.status==RefundStatus.PROCESSING
    assert fake_gateway.refund_creates==1
    refund_service.process(db_session,refund.id)
    assert fake_gateway.refund_creates==1
    fake_gateway.refunds[refund.razorpay_refund_id]['status']='processed'
    refund_service.process(db_session,refund.id)
    db_session.refresh(refund)
    assert refund.status==RefundStatus.COMPLETED

def test_refund_timeout_never_retried_blindly(client,test_print_server,fake_gateway,db_session,monkeypatch):
    from app.utils.errors import AppException
    order,_=paid_order(client,test_print_server,fake_gateway)
    record=db_session.get(Order,order['id']);record.status=OrderStatus.EXPIRED;db_session.commit()
    refund=refund_service.process_refund(db_session,order['id'],'Expired')
    original=fake_gateway.request
    def refund_timeout(method,path,**kwargs):
        if method=='POST' and path.endswith('/refund'):
            from app.utils.common import fail
            fail('GATEWAY_UNAVAILABLE','Response lost',502)
        return original(method,path,**kwargs)
    monkeypatch.setattr('app.services.gateway.gateway.request',refund_timeout)
    with pytest.raises(AppException):refund_service.process(db_session,refund.id)
    monkeypatch.setattr('app.services.gateway.gateway.request',original)
    refund_service.process(db_session,refund.id)
    db_session.refresh(refund)
    assert refund.status==RefundStatus.PROCESSING
    assert fake_gateway.refund_creates==0
    assert 'UNKNOWN' in refund.error_message

def test_origin_and_payload_limits(client):
    assert client.get('/health',headers={'Origin':'https://attacker.example'}).status_code==403
    assert client.post('/api/payments/webhook',content=b'x'*(256*1024+1)).status_code==413

def test_removed_public_bypasses(client):
    assert client.post('/api/agent/release-kiosk',json={'otp':'123456'}).status_code==404
    assert client.get('/kiosk').status_code==404
