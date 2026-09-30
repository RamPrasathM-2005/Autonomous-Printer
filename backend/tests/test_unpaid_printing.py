from datetime import timedelta
from sqlalchemy.orm import sessionmaker
import pytest
from app.config.settings import settings
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment
from app.db.models.otp import OTP
from app.db.models.print_job import PrintJob
from app.db.models.refund import Refund
from app.services.refund_service import refund_service
from app.utils.common import now
from app.utils.errors import AppException
from tests.conftest import create_order, start_payment


def enable(monkeypatch):
    monkeypatch.setattr(settings, 'ALLOW_UNPAID_TEST_PRINTING', True)


def authorize(client, order):
    return client.post('/api/orders/' + order['id'] + '/test-print', json={})


@pytest.mark.parametrize('environment,key,enabled', [
    ('test', 'rzp_test_tests', False),
    ('production', 'rzp_test_tests', True),
    ('development', 'rzp_live_tests', True),
    ('staging', 'rzp_test_tests', True),
])
def test_unpaid_printing_fails_closed(client, test_print_server, db_session, monkeypatch, environment, key, enabled):
    order = create_order(client, test_print_server)
    monkeypatch.setattr(settings, 'ENVIRONMENT', environment)
    monkeypatch.setattr(settings, 'RAZORPAY_KEY_ID', key)
    monkeypatch.setattr(settings, 'ALLOW_UNPAID_TEST_PRINTING', enabled)
    assert client.get('/api/payments/capabilities').json()['unpaidTestPrinting'] is False
    assert authorize(client, order).status_code == 403
    assert db_session.query(OTP).count() == db_session.query(PrintJob).count() == 0


def test_unpaid_full_flow_no_gateway_payment_or_refund(client, test_print_server, test_agent_token, db_session, fake_gateway, monkeypatch):
    enable(monkeypatch)
    fake_gateway.unavailable = True
    order = create_order(client, test_print_server)
    assert authorize(client, order).status_code == 200
    code = client.get('/api/orders/' + order['id'] + '/otp').json()['otp']
    assert authorize(client, order).status_code == 200
    assert db_session.query(OTP).count() == db_session.query(PrintJob).count() == 1
    assert client.get('/api/orders/' + order['id'] + '/otp').json()['otp'] == code
    assert client.post('/api/payments/create', json={'orderId': order['id']}).status_code == 409
    headers = {'Authorization': 'Bearer ' + test_agent_token}
    released = client.post('/api/agent/release', headers=headers, json={'otp': code})
    assert released.status_code == 200, released.text
    job_id = released.json()['jobId']
    assert client.post('/api/agent/release', headers=headers, json={'otp': code}).status_code == 400
    claim = client.post('/api/agent/jobs/' + job_id + '/claim', headers=headers)
    assert claim.status_code == 200, claim.text
    assert claim.json()['allowMock'] is True
    assert claim.json()['settings']['unpaidTestPrint'] is True
    assert client.post('/api/agent/jobs/' + job_id + '/claim', headers=headers).status_code == 409
    completed = client.post('/api/agent/jobs/' + job_id + '/status', headers=headers,
        json={'status': 'COMPLETED', 'claimToken': claim.json()['claimToken'], 'cupsJobId': 'mock-unit'})
    assert completed.status_code == 200, completed.text
    assert client.get('/api/orders/' + order['id']).json()['status'] == 'COMPLETED'
    assert db_session.query(Payment).count() == db_session.query(Refund).count() == 0
    assert fake_gateway.creates == fake_gateway.refund_creates == 0


def test_existing_payment_cannot_be_converted(client, test_print_server, db_session, monkeypatch):
    enable(monkeypatch)
    order = create_order(client, test_print_server)
    start_payment(client, order)
    response = authorize(client, order)
    assert response.status_code == 409
    assert response.json()['error'] == 'PAYMENT_ALREADY_STARTED'
    assert db_session.query(OTP).count() == 0


def test_only_order_owner_can_request_free_test(client, test_print_server, db_session, monkeypatch):
    enable(monkeypatch)
    order = create_order(client, test_print_server)
    client.headers.pop('Authorization')
    assert authorize(client, order).status_code == 401
    session = client.post('/api/sessions').json()
    client.headers['Authorization'] = 'Bearer ' + session['token']
    assert authorize(client, order).status_code == 404
    assert db_session.query(OTP).count() == 0


def test_client_cannot_inject_test_marker(client, test_print_server, monkeypatch):
    enable(monkeypatch)
    order = create_order(client, test_print_server)
    response = client.post('/api/orders', json={
        'documentId': order['documentId'], 'printServerId': test_print_server.id,
        'settings': {'unpaidTestPrint': True}})
    assert response.status_code == 422
    assert client.get('/api/orders/' + order['id'] + '/otp').status_code == 409


def test_switch_off_blocks_existing_test_release_and_claim(client, test_print_server, db_session, test_agent_token, monkeypatch):
    enable(monkeypatch)
    order = create_order(client, test_print_server)
    assert authorize(client, order).status_code == 200
    code = client.get('/api/orders/' + order['id'] + '/otp').json()['otp']
    monkeypatch.setattr(settings, 'ALLOW_UNPAID_TEST_PRINTING', False)
    assert client.get('/api/orders/' + order['id'] + '/otp').status_code == 403
    assert client.post('/api/orders/' + order['id'] + '/release', json={'otp': code}).status_code == 403
    enable(monkeypatch)
    assert client.post('/api/orders/' + order['id'] + '/release', json={'otp': code}).status_code == 200
    job_id = db_session.query(PrintJob).one().id
    monkeypatch.setattr(settings, 'ALLOW_UNPAID_TEST_PRINTING', False)
    assert client.post('/api/agent/jobs/' + job_id + '/claim', headers={
        'Authorization': 'Bearer ' + test_agent_token}).status_code == 403


def test_expiry_never_creates_refund_or_regenerates_code(client, test_print_server, db_session, monkeypatch):
    from app import worker
    enable(monkeypatch)
    order = create_order(client, test_print_server)
    authorize(client, order)
    db_session.query(OTP).one().expires_at = now() - timedelta(minutes=1)
    db_session.commit()
    monkeypatch.setattr(worker, 'SessionLocal', sessionmaker(bind=db_session.get_bind()))
    worker.run_once()
    db_session.rollback()
    assert db_session.get(Order, order['id']).status == OrderStatus.EXPIRED
    assert authorize(client, order).json()['status'] == 'EXPIRED'
    assert not db_session.query(OTP).one().active
    assert db_session.query(Payment).count() == db_session.query(Refund).count() == 0
    with pytest.raises(AppException) as error:
        refund_service.process_refund(db_session, order['id'])
    assert error.value.error_code == 'REFUND_NOT_ELIGIBLE'


def test_pre_submission_failure_never_refunds_test(client, test_print_server, test_agent_token, db_session, monkeypatch):
    enable(monkeypatch)
    order = create_order(client, test_print_server)
    authorize(client, order)
    code = client.get('/api/orders/' + order['id'] + '/otp').json()['otp']
    client.post('/api/orders/' + order['id'] + '/release', json={'otp': code})
    job = db_session.query(PrintJob).one()
    headers = {'Authorization': 'Bearer ' + test_agent_token}
    claim = client.post('/api/agent/jobs/' + job.id + '/claim', headers=headers).json()
    response = client.post('/api/agent/jobs/' + job.id + '/status', headers=headers,
        json={'status': 'FAILED', 'claimToken': claim['claimToken'], 'errorCode': 'FILE_INTEGRITY'})
    assert response.status_code == 200, response.text
    assert db_session.query(Refund).count() == 0
