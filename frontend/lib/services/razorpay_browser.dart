import 'dart:async';
import 'dart:js_interop';

import 'razorpay_result.dart';

@JS('openRazorpayModal')
external void _open(
  JSString key,
  JSString order,
  JSNumber amount,
  JSFunction success,
  JSFunction failure,
);

class RazorpayWebService {
  static Future<RazorpayWebPaymentResult> openCheckout({
    required String keyId,
    required String orderId,
    required double amount,
  }) async {
    final done = Completer<RazorpayWebPaymentResult>();
    final success = (JSString payment, JSString order, JSString signature) {
      if (!done.isCompleted) {
        done.complete(
          RazorpayWebPaymentResult(
            success: true,
            razorpayPaymentId: payment.toDart,
            razorpayOrderId: order.toDart,
            razorpaySignature: signature.toDart,
          ),
        );
      }
    }.toJS;
    final failure = (JSString reason) {
      if (!done.isCompleted) {
        done.complete(
          RazorpayWebPaymentResult(success: false, errorMessage: reason.toDart),
        );
      }
    }.toJS;
    try {
      _open(
        keyId.toJS,
        orderId.toJS,
        (amount * 100).round().toJS,
        success,
        failure,
      );
    } catch (_) {
      return const RazorpayWebPaymentResult(
        success: false,
        errorMessage: 'Checkout could not load. Please retry.',
      );
    }
    return done.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () => const RazorpayWebPaymentResult(
        success: false,
        errorMessage:
            'Checkout timed out. Check payment status before paying again.',
      ),
    );
  }
}
