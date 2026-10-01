import 'razorpay_result.dart';

class RazorpayWebService {
  static Future<RazorpayWebPaymentResult> openCheckout({
    required String keyId,
    required String orderId,
    required double amount,
  }) async => const RazorpayWebPaymentResult(
    success: false,
    errorMessage: 'Payments are available in the web app.',
  );
}
