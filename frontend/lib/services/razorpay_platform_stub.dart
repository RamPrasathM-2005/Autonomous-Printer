import 'dart:async';
import 'package:flutter/foundation.dart';
import 'razorpay_web_service.dart';

Future<RazorpayWebPaymentResult> openRazorpayCheckoutPlatform({
  required String keyId,
  required String orderId,
  required double amount,
}) async {
  debugPrint('[RAZORPAY_STUB] Mobile / Non-web platform detected. Simulating instant approval for dev/test.');
  return RazorpayWebPaymentResult(
    success: true,
    razorpayPaymentId: 'pay_mobile_${DateTime.now().millisecondsSinceEpoch}',
    razorpayOrderId: orderId,
    razorpaySignature: 'sim_sig_${DateTime.now().millisecondsSinceEpoch}',
  );
}
