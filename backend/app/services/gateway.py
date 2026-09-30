"""Small, fail-closed Razorpay REST adapter with bounded HTTPS requests."""
import re
import requests
from app.config.settings import settings
from app.utils.common import fail

class RazorpayGateway:
    def request(self, method, path, **kwargs):
        if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
            fail('PAYMENTS_UNAVAILABLE', 'Payment credentials are not configured.', 503)
        try:
            response = requests.request(method, 'https://api.razorpay.com/v1/' + path,
                auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET),
                timeout=(5, settings.PAYMENT_HTTP_TIMEOUT), allow_redirects=False, **kwargs)
            if response.status_code >= 300:
                fail('GATEWAY_UNAVAILABLE', 'The payment provider could not complete the request. Check payment status before retrying.', 502)
            result = response.json()
            if not isinstance(result, dict):
                raise ValueError('Invalid response')
            return result
        except (requests.RequestException, ValueError):
            fail('GATEWAY_UNAVAILABLE', 'Payment provider unavailable. No payment or refund has been assumed successful.', 502)

    @staticmethod
    def identifier(value, prefix):
        if not isinstance(value, str) or not re.fullmatch(prefix + r'_[A-Za-z0-9]{1,100}', value):
            fail('INVALID_GATEWAY_ID', 'Invalid payment provider identifier.')
        return value

    def create_order(self, amount, receipt):
        return self.request('POST', 'orders', json={'amount': amount, 'currency': 'INR',
            'receipt': receipt, 'partial_payment': False, 'notes': {'local_order_id': receipt}})

    def fetch_order(self, order_id):
        return self.request('GET', 'orders/' + self.identifier(order_id, 'order'))

    def find_orders(self, receipt):
        return self.request('GET', 'orders', params={'receipt': receipt, 'count': 100})['items']

    def fetch_payment(self, payment_id):
        return self.request('GET', 'payments/' + self.identifier(payment_id, 'pay'))

    def order_payments(self, order_id):
        return self.request('GET', 'orders/' + self.identifier(order_id, 'order') + '/payments')['items']

    def create_refund(self, payment_id, amount, refund_id):
        return self.request('POST', 'payments/' + self.identifier(payment_id, 'pay') + '/refund',
            json={'amount': amount, 'speed': 'normal', 'receipt': refund_id,
                  'notes': {'local_refund_id': refund_id}})

    def fetch_refund(self, refund_id):
        return self.request('GET', 'refunds/' + self.identifier(refund_id, 'rfnd'))

    def payment_refunds(self, payment_id):
        # Bounded pagination; do not assume an omitted refund never existed.
        results = []
        for skip in range(0, 1000, 100):
            items = self.request('GET', 'payments/' + self.identifier(payment_id, 'pay') + '/refunds',
                                 params={'count': 100, 'skip': skip})['items']
            results.extend(items)
            if len(items) < 100:
                return results
        fail('RECONCILIATION_REVIEW', 'Refund history requires operator review.', 409)

gateway = RazorpayGateway()
