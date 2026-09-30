import os
import io
import uuid
import hashlib
import hmac
from datetime import datetime, timezone
os.environ['DATABASE_URL'] = 'sqlite:///:memory:'
os.environ['RAZORPAY_KEY_ID'] = 'rzp_test_securitytests'
os.environ['RAZORPAY_KEY_SECRET'] = 'test-key-secret-never-used-outside-tests'
os.environ['RAZORPAY_WEBHOOK_SECRET'] = 'test-webhook-secret-never-used-outside-tests'
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from cryptography.fernet import Fernet
from pypdf import PdfWriter
from app.config.settings import settings
from app.config.security import hash_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.printer import Printer
from app.db.models.user import User, UserRole
from app.main import app
from app.services.gateway import gateway
from app.services.storage_service import storage_service

class FakeGateway:
    def __init__(self):
        self.orders = {}; self.payments = {}; self.refunds = {}; self.creates = 0; self.refund_creates = 0
        self.unavailable = False
    def request(self, method, path, **kwargs):
        from app.utils.common import fail
        if self.unavailable: fail('GATEWAY_UNAVAILABLE', 'Provider unavailable', 502)
        body = kwargs.get('json', {})
        if method == 'POST' and path == 'orders':
            self.creates += 1
            oid = 'order_' + uuid.uuid4().hex
            row = dict(body, id=oid, status='created', amount_paid=0, amount_due=body['amount'])
            self.orders[oid] = row
            return dict(row)
        if method == 'GET' and path == 'orders':
            return {'items': [dict(o) for o in self.orders.values() if o['receipt'] == kwargs['params']['receipt']]}
        if path.startswith('orders/'):
            oid = path.split('/')[1]
            if path.endswith('/payments'): return {'items':[dict(p) for p in self.payments.values() if p['order_id']==oid]}
            return dict(self.orders[oid])
        if path.startswith('payments/') and path.endswith('/refund'):
            self.refund_creates += 1
            rid = 'rfnd_' + uuid.uuid4().hex
            row = dict(body, id=rid, payment_id=path.split('/')[1], currency='INR', status='pending')
            self.refunds[rid] = row
            return dict(row)
        if path.startswith('payments/') and path.endswith('/refunds'):
            return {'items':[dict(r) for r in self.refunds.values() if r['payment_id']==path.split('/')[1]]}
        if path.startswith('payments/'): return dict(self.payments[path.split('/')[1]])
        if path.startswith('refunds/'): return dict(self.refunds[path.split('/')[1]])
        raise AssertionError((method,path))
    def capture(self, oid, status='captured'):
        order=self.orders[oid]
        pid='pay_'+uuid.uuid4().hex
        payment={'id':pid,'order_id':oid,'amount':order['amount'],'currency':order['currency'],
                 'status':status,'captured':status=='captured','amount_refunded':0}
        self.payments[pid]=payment
        if status=='captured': order.update(status='paid',amount_paid=order['amount'],amount_due=0)
        return payment

@pytest.fixture(autouse=True)
def configuration(monkeypatch, tmp_path):
    monkeypatch.setattr(settings,'JWT_SECRET_KEY','test-jwt-'+'x'*40)
    monkeypatch.setattr(settings,'OTP_HASH_KEY','test-otp-'+'y'*40)
    monkeypatch.setattr(settings,'OTP_ENCRYPTION_KEY',Fernet.generate_key().decode())
    monkeypatch.setattr(settings,'ALLOW_MOCK_PRINTING',True)
    monkeypatch.setattr(storage_service,'storage_root',tmp_path/'storage')
    storage_service._ensure_directories()

@pytest.fixture
def db_session(tmp_path):
    test_url=os.getenv('MYSQL_SECURITY_TEST_URL')
    if test_url:
        from sqlalchemy.engine import make_url
        if not make_url(test_url).database.startswith('printer_security_test_'):
            raise RuntimeError('Refusing to run destructive tests outside an isolated security test database')
        engine=create_engine(test_url, isolation_level="READ COMMITTED")
    else:
        engine=create_engine('sqlite:///'+str(tmp_path/'test.db'),connect_args={'check_same_thread':False})
    Base.metadata.create_all(engine)
    factory=sessionmaker(bind=engine)
    with factory() as db:
        yield db
    Base.metadata.drop_all(engine)
    engine.dispose()

@pytest.fixture
def fake_gateway(monkeypatch):
    fake=FakeGateway()
    monkeypatch.setattr(gateway,'request',fake.request)
    return fake

class Client(TestClient):
    def post(self, url, **kwargs):
        if url == '/api/orders':
            kwargs['headers'] = {'Idempotency-Key':uuid.uuid4().hex, **kwargs.get('headers',{})}
        return super().post(url, **kwargs)

@pytest.fixture
def client(db_session, fake_gateway):
    app.dependency_overrides[get_db]=lambda:db_session
    with Client(app) as client:
        session=client.post('/api/sessions').json()
        client.headers['Authorization']='Bearer '+session['token']
        yield client
    app.dependency_overrides.clear()

@pytest.fixture
def test_agent_token(): return 'test-agent-'+ 'z'*40

@pytest.fixture
def test_print_server(db_session,test_agent_token):
    server=PrintServer(id='PRINT-SERVER-001',name='Test station',device_token_hash=hash_token(test_agent_token),
        status=PrintServerStatus.ONLINE,last_heartbeat=datetime.now(timezone.utc),printer_state='READY',paper_state='AVAILABLE')
    db_session.add(server); db_session.flush()
    db_session.add(Printer(id='printer1',server_id=server.id,cups_printer_name='test',display_name='Test',
        supports_color=True,supports_duplex=True,is_active=True))
    db_session.commit()
    return server

@pytest.fixture
def test_user(db_session):
    user=User(email='student@example.test',full_name='Test',password_hash=hash_password('test-password'),role=UserRole.USER,is_active=True)
    db_session.add(user);db_session.commit();return user

def create_sample_pdf(page_count=3):
    writer=PdfWriter()
    for _ in range(page_count): writer.add_blank_page(width=72,height=72)
    buf=io.BytesIO();writer.write(buf);return buf.getvalue()

def create_order(client,station, pages=1, **settings):
    upload=client.post('/api/documents/upload',files={'file':('test.pdf',create_sample_pdf(pages),'application/pdf')})
    assert upload.status_code==201,upload.text
    response=client.post('/api/orders',json={'documentId':upload.json()['documentId'],'printServerId':station.id,'settings':settings})
    assert response.status_code==201,response.text
    return response.json()

def start_payment(client,order):
    response=client.post('/api/payments/create',json={'orderId':order['id']})
    assert response.status_code==201,response.text
    return response.json()

def proof(order,payment):
    oid=payment['order_id'];pid=payment['id']
    signature=hmac.new(settings.RAZORPAY_KEY_SECRET.encode(),f'{oid}|{pid}'.encode(),hashlib.sha256).hexdigest()
    return {'orderId':order['id'],'razorpayOrderId':oid,'razorpayPaymentId':pid,'razorpaySignature':signature}

def paid_order(client,station,fake):
    order=create_order(client,station)
    initiated=start_payment(client,order)
    payment=fake.capture(initiated['razorpayOrderId'])
    response=client.post('/api/payments/verify',json=proof(order,payment))
    assert response.status_code==200,response.text
    return order,payment
