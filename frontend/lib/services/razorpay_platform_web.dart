import 'razorpay_browser.dart' as browser;
import 'razorpay_result.dart';

Future<RazorpayWebPaymentResult> openRazorpayCheckoutPlatform({
  required String keyId,
  required String orderId,
  required double amount,
}) => browser.RazorpayWebService.openCheckout(
  keyId: keyId,
  orderId: orderId,
  amount: amount,
);
