"""Opt-in tests against a separately provisioned, disposable MySQL database."""
import os
import time
from concurrent.futures import ThreadPoolExecutor
import pytest
from sqlalchemy.orm import sessionmaker
from app.services.payment_service import payment_service
from app.services.otp_service import otp_service
from app.services.job_service import job_service
from app.db.models.payment import Payment
from app.db.models.otp import OTP
from app.db.models.print_job import PrintJob
from app.utils.errors import AppException
from tests.conftest import create_order,start_payment,proof,paid_order
pytestmark=pytest.mark.skipif(not os.getenv('MYSQL_SECURITY_TEST_URL'),reason='Isolated MySQL database required')

def parallel(db, operation):
    factory=sessionmaker(bind=db.get_bind())
    def run(_):
        with factory() as session:
            try: return operation(session)
            except AppException as e:
                session.rollback();return e.error_code
    with ThreadPoolExecutor(max_workers=4) as pool:return list(pool.map(run,range(4)))


def test_concurrent_order_creation_reuses_same_snapshot(client,test_print_server,db_session):
    from app.services.order_service import order_service
    from app.schemas.order import OrderCreateRequest
    from app.db.models.document import Document
    from app.db.models.order import Order
    from tests.conftest import create_sample_pdf
    upload=client.post('/api/documents/upload',files={'file':('x.pdf',create_sample_pdf(1),'application/pdf')}).json()
    document=db_session.get(Document,upload['documentId'])
    owner=document.session_id
    req=OrderCreateRequest(documentId=document.id,printServerId=test_print_server.id)
    db_session.rollback()
    ids=parallel(db_session,lambda db:order_service.create_order(db,req,session_id=owner,
        idempotency_key='same-request-concurrent-1234').id)
    assert len(set(ids))==1
    db_session.rollback()
    assert db_session.query(Order).count()==1

def test_concurrent_provider_order_creation_once(client,test_print_server,fake_gateway,db_session,monkeypatch):
    order=create_order(client,test_print_server)
    original=fake_gateway.request
    def slow(method,path,**kwargs):
        if method=='POST' and path=='orders':time.sleep(.2)
        return original(method,path,**kwargs)
    monkeypatch.setattr('app.services.gateway.gateway.request',slow)
    parallel(db_session,lambda db:payment_service.create_payment(db,order['id']))
    assert fake_gateway.creates==1
    db_session.rollback()  # End the pre-worker REPEATABLE READ snapshot.
    assert db_session.query(Payment).count()==1

def test_concurrent_capture_creates_one_job_and_otp(client,test_print_server,fake_gateway,db_session):
    order=create_order(client,test_print_server);created=start_payment(client,order)
    remote=fake_gateway.capture(created['razorpayOrderId']);data=proof(order,remote)
    outcomes=parallel(db_session,lambda db:payment_service.verify_or_confirm_payment(db,order['id'],
        data['razorpayOrderId'],data['razorpayPaymentId'],data['razorpaySignature']))
    assert all(isinstance(o,dict) and o['success'] for o in outcomes)
    db_session.rollback()
    assert db_session.query(OTP).count()==1
    assert db_session.query(PrintJob).count()==1

def test_concurrent_release_and_claim_only_once(client,test_print_server,fake_gateway,db_session):
    order,_=paid_order(client,test_print_server,fake_gateway)
    code=client.get('/api/orders/'+order['id']+'/otp').json()['otp']
    result=parallel(db_session,lambda db:otp_service.verify_and_release_job(db,test_print_server.id,code))
    assert sum(not isinstance(o,str) for o in result)==1
    db_session.expire_all();job=db_session.query(PrintJob).one()
    result=parallel(db_session,lambda db:job_service.claim(db,test_print_server.id,job.id))
    assert sum(isinstance(o,dict) for o in result)==1


def test_concurrent_unpaid_authorization_issues_one_code(client,test_print_server,db_session,monkeypatch):
    from app.config.settings import settings
    from app.services.test_print_service import authorize_test_print
    monkeypatch.setattr(settings,'ALLOW_UNPAID_TEST_PRINTING',True)
    order=create_order(client,test_print_server)
    outcomes=parallel(db_session,lambda db:authorize_test_print(db,order['id']))
    assert all(isinstance(o,dict) for o in outcomes)
    db_session.rollback()
    assert db_session.query(OTP).count()==1
    assert db_session.query(PrintJob).count()==1
    assert db_session.query(Payment).count()==0


def test_payment_and_unpaid_test_are_mutually_exclusive(client,test_print_server,db_session,monkeypatch):
    from threading import Barrier
    from app.config.settings import settings
    from app.services.test_print_service import authorize_test_print
    monkeypatch.setattr(settings,'ALLOW_UNPAID_TEST_PRINTING',True)
    order=create_order(client,test_print_server)
    factory=sessionmaker(bind=db_session.get_bind())
    barrier=Barrier(2)
    def run(test):
        with factory() as db:
            barrier.wait()
            try:
                return authorize_test_print(db,order['id']) if test else payment_service.create_payment(db,order['id'])
            except AppException as error:
                db.rollback()
                return error.error_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes=list(pool.map(run,[True,False]))
    assert sum(isinstance(o,str) for o in outcomes)==1
    db_session.rollback()
    assert db_session.query(Payment).count()+db_session.query(PrintJob).count()==1
