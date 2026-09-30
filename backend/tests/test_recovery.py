from datetime import timedelta
from sqlalchemy.orm import sessionmaker
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment
from app.db.models.otp import OTP
from app.db.models.refund import Refund, RefundStatus
from app.services.payment_service import payment_service
from app.services.refund_service import refund_service
from app.utils.common import now
from tests.conftest import create_order, start_payment, paid_order


def test_session_end_revokes_access(client):
    assert client.delete('/api/sessions/current').status_code == 200
    assert client.get('/api/orders').status_code == 401


def test_order_creation_response_lost_recovered_without_second_post(client, test_print_server, fake_gateway, db_session, monkeypatch):
    order = create_order(client, test_print_server)
    original = fake_gateway.request
    def lose_response(method, path, **kwargs):
        result = original(method, path, **kwargs)
        if method == 'POST' and path == 'orders':
            from app.utils.common import fail
            fail('GATEWAY_UNAVAILABLE', 'Response lost', 502)
        return result
    monkeypatch.setattr('app.services.gateway.gateway.request', lose_response)
    assert client.post('/api/payments/create', json={'orderId': order['id']}).status_code == 502
    payment = db_session.query(Payment).one()
    payment.created_at = now() - timedelta(minutes=1)
    db_session.commit()
    payment_service.reconcile(db_session, order['id'])
    assert start_payment(client, order)['razorpayOrderId'] in fake_gateway.orders
    assert fake_gateway.creates == 1


def test_worker_expires_otp_and_dispatches_refund_once(client, test_print_server, fake_gateway, db_session, monkeypatch):
    from app import worker
    order, _ = paid_order(client, test_print_server, fake_gateway)
    db_session.query(OTP).one().expires_at = now() - timedelta(minutes=1)
    db_session.commit()
    monkeypatch.setattr(worker, 'SessionLocal', sessionmaker(bind=db_session.get_bind()))
    worker.run_once()
    worker.run_once()
    db_session.rollback()
    assert db_session.get(Order, order['id']).status == OrderStatus.EXPIRED
    assert not db_session.query(OTP).one().active
    assert db_session.query(Refund).one().status == RefundStatus.PROCESSING
    assert fake_gateway.refund_creates == 1


def test_external_partial_refund_blocks_release(client, test_print_server, fake_gateway, db_session):
    order, remote = paid_order(client, test_print_server, fake_gateway)
    code = client.get('/api/orders/' + order['id'] + '/otp').json()['otp']
    remote['amount_refunded'] = 1
    payment = db_session.query(Payment).one()
    refund_service.reconcile_external(db_session, payment, remote)
    assert client.post('/api/orders/' + order['id'] + '/release', json={'otp': code}).status_code == 400
    assert db_session.get(Order, order['id']).status == OrderStatus.FAILED


def test_provider_recovery_clears_transient_hold(client, test_print_server, fake_gateway, db_session):
    _, remote = paid_order(client, test_print_server, fake_gateway)
    payment = db_session.query(Payment).one()
    payment.last_error = 'GATEWAY_UNAVAILABLE'
    db_session.commit()
    refund_service.reconcile_external(db_session, payment, remote)
    assert payment.last_error is None


def test_external_full_refund_satisfies_pending_outbox(client, test_print_server, fake_gateway, db_session):
    order, remote = paid_order(client, test_print_server, fake_gateway)
    db_session.get(Order, order['id']).status = OrderStatus.EXPIRED
    db_session.commit()
    refund = refund_service.process_refund(db_session, order['id'])
    remote['amount_refunded'] = remote['amount']
    remote['status'] = 'refunded'
    refund_service.process(db_session, refund.id)
    assert refund.status == RefundStatus.COMPLETED
    assert fake_gateway.refund_creates == 0
