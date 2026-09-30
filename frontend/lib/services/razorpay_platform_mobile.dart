import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_web_service.dart';

Future<RazorpayWebPaymentResult> openRazorpayCheckoutPlatform({
  required String keyId,
  required String orderId,
  required double amount,
}) async {
  final completer = Completer<RazorpayWebPaymentResult>();
  final razorpay = Razorpay();

  final safeKeyId = keyId.trim().isNotEmpty ? keyId.trim() : 'rzp_test_RFxhjAiTxwrpAJ';
  final amountPaise = (amount * 100).round();

  void handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('[RAZORPAY_MOBILE] Payment Succeeded! paymentId=${response.paymentId}, orderId=${response.orderId}');
    if (!completer.isCompleted) {
      completer.complete(
        RazorpayWebPaymentResult(
          success: true,
          razorpayPaymentId: response.paymentId ?? '',
          razorpayOrderId: response.orderId ?? orderId,
          razorpaySignature: response.signature ?? '',
        ),
      );
    }
    razorpay.clear();
  }

  void handlePaymentError(PaymentFailureResponse response) {
    debugPrint('[RAZORPAY_MOBILE] Payment Error: code=${response.code}, message=${response.message}');
    if (!completer.isCompleted) {
      completer.complete(
        RazorpayWebPaymentResult(
          success: false,
          errorMessage: response.message ?? 'Payment cancelled or failed (code: ${response.code})',
        ),
      );
    }
    razorpay.clear();
  }

  void handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('[RAZORPAY_MOBILE] External Wallet selected: ${response.walletName}');
    if (!completer.isCompleted) {
      completer.complete(
        RazorpayWebPaymentResult(
          success: false,
          errorMessage: 'External wallet ${response.walletName} selected',
        ),
      );
    }
    razorpay.clear();
  }

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWallet);

  final options = {
    'key': safeKeyId,
    'amount': amountPaise,
    'name': 'AutosPrint Hub',
    'description': 'Instant Print Payment',
    'order_id': orderId,
    'prefill': {
      'contact': '9876543210',
      'email': 'student@printstation.edu',
    },
    'theme': {
      'color': '#2563EB',
    },
  };

  try {
    debugPrint('[RAZORPAY_MOBILE] Launching Razorpay Mobile SDK modal: amount=₹$amount, key=$safeKeyId, order=$orderId');
    razorpay.open(options);
  } catch (e) {
    debugPrint('[RAZORPAY_MOBILE] Exception while opening Razorpay modal: $e');
    if (!completer.isCompleted) {
      completer.complete(
        RazorpayWebPaymentResult(
          success: false,
          errorMessage: 'Failed to launch Razorpay: $e',
        ),
      );
    }
    razorpay.clear();
  }

  return completer.future;
}
