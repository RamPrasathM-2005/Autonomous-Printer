"""Regression: the removed development shortcut must never authorize printing."""
import pytest
from app.db.models.order import Order, OrderStatus
from app.db.models.otp import OTP
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.services.otp_service import otp_service
from tests.conftest import create_order


def test_removed_endpoint_cannot_issue_code(client, test_print_server, db_session):
    order = create_order(client, test_print_server)
    assert client.post('/api/orders/' + order['id'] + '/test-print', json={}).status_code == 404
    assert db_session.query(OTP).count() == 0
    assert 'unpaidTestPrinting' not in client.get('/api/payments/capabilities').json()


def test_legacy_free_order_cannot_release_or_claim(client, test_print_server, test_agent_token, db_session):
    data = create_order(client, test_print_server)
    order = db_session.get(Order, data['id'])
    order.print_settings = {**order.print_settings, 'unpaidTestPrint': True}
    order.status = OrderStatus.WAITING_FOR_OTP
    job = PrintJob(id='legacy_free_job', order_id=order.id, server_id=test_print_server.id, status=PrintJobStatus.QUEUED)
    db_session.add(job)
    code = otp_service.generate_and_store_otp(db_session, order.id)
    db_session.commit()
    assert client.get('/api/orders/' + order.id + '/otp').status_code == 409
    assert client.post('/api/orders/' + order.id + '/release', json={'otp': code}).status_code == 409
    order.status = OrderStatus.RELEASED
    job.status = PrintJobStatus.RELEASED
    db_session.commit()
    assert client.post('/api/agent/jobs/' + job.id + '/claim', headers={
        'Authorization': 'Bearer ' + test_agent_token}).status_code == 409
    assert job.claim_token_hash is None
