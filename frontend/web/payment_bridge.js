/* Checkout callbacks are untrusted input. Only the backend authorizes fulfilment. */
let checkoutScript;
function loadCheckout() {
  if (window.Razorpay) return Promise.resolve();
  if (!checkoutScript) checkoutScript = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.onload = resolve;
    script.onerror = () => { checkoutScript = null; reject(new Error('Checkout unavailable')); };
    document.head.appendChild(script);
  });
  return checkoutScript;
}
window.openRazorpayModal = async function(key, order, amount, success, failure) {
  if (!/^rzp_(test|live)_/.test(key) || !/^order_[A-Za-z0-9]+$/.test(order) || !Number.isSafeInteger(amount) || amount <= 0) {
    failure('Checkout unavailable. Try again later.'); return;
  }
  try {
    await loadCheckout();
    const checkout = new window.Razorpay({key, order_id:order, amount, currency:'INR',
      name:'Autonomous Printer', description:'Print order', theme:{color:'#2563EB'},
      handler: response => success(response.razorpay_payment_id || '', response.razorpay_order_id || '', response.razorpay_signature || ''),
      modal:{ondismiss:() => failure('DISMISSED')}});
    checkout.on('payment.failed', () => failure('Payment failed. Check status before retrying.'));
    checkout.open();
  } catch (_) { failure('Checkout unavailable. Check payment status.'); }
};
