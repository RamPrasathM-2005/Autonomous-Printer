import 'dart:async';
import 'razorpay_platform_mobile.dart'
    if (dart.library.js_interop) 'razorpay_platform_web.dart';

class RazorpayWebPaymentResult {
  final bool success;
  final String razorpayPaymentId;
  final String razorpayOrderId;
  final String razorpaySignature;
  final String? errorMessage;

  RazorpayWebPaymentResult({
    required this.success,
    this.razorpayPaymentId = '',
    this.razorpayOrderId = '',
    this.razorpaySignature = '',
    this.errorMessage,
  });
}

class RazorpayWebService {
  static Future<RazorpayWebPaymentResult> openCheckout({
    required String keyId,
    required String orderId,
    required double amount,
  }) {
    return openRazorpayCheckoutPlatform(
      keyId: keyId,
      orderId: orderId,
      amount: amount,
    );
  }
}
