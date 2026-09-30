import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_result.dart';

class RazorpayWebService {
  static bool _checkoutOpen = false;

  static Future<RazorpayWebPaymentResult> openCheckout({
    required String keyId,
    required String orderId,
    required double amount,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return const RazorpayWebPaymentResult(
        success: false,
        errorMessage: 'Use the web app to pay on this device.',
      );
    }
    if (_checkoutOpen ||
        keyId.isEmpty ||
        orderId.isEmpty ||
        !amount.isFinite ||
        amount <= 0) {
      return const RazorpayWebPaymentResult(
        success: false,
        errorMessage: 'Checkout is unavailable. Check payment status.',
      );
    }
    _checkoutOpen = true;
    final done = Completer<RazorpayWebPaymentResult>();
    Razorpay? razorpay;
    void finish(RazorpayWebPaymentResult result) {
      if (!done.isCompleted) done.complete(result);
    }

    try {
      // The SDK exposes async-void open/resync methods. Capture their platform
      // errors in this zone so a missing plugin cannot crash the application.
      runZonedGuarded(
        () {
          final checkout = Razorpay();
          razorpay = checkout;
          checkout.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
            PaymentSuccessResponse response,
          ) {
            final payment = response.paymentId ?? '';
            final order = response.orderId ?? '';
            final signature = response.signature ?? '';
            if (payment.isEmpty || order != orderId || signature.isEmpty) {
              finish(
                const RazorpayWebPaymentResult(
                  success: false,
                  errorMessage: 'Payment unconfirmed. Check payment status.',
                ),
              );
              return;
            }
            // A checkout callback is not proof of payment. PaymentScreen asks the
            // backend to verify the signature and capture before releasing a code.
            finish(
              RazorpayWebPaymentResult(
                success: true,
                razorpayPaymentId: payment,
                razorpayOrderId: order,
                razorpaySignature: signature,
              ),
            );
          });
          checkout.on(Razorpay.EVENT_PAYMENT_ERROR, (
            PaymentFailureResponse response,
          ) {
            finish(
              const RazorpayWebPaymentResult(
                success: false,
                errorMessage: 'Payment unconfirmed. Check payment status.',
              ),
            );
          });
          checkout.on(Razorpay.EVENT_EXTERNAL_WALLET, (
            ExternalWalletResponse response,
          ) {
            finish(
              const RazorpayWebPaymentResult(
                success: false,
                errorMessage:
                    'Check payment status after completing your payment.',
              ),
            );
          });
          checkout.open({
            'key': keyId,
            'order_id': orderId,
            'amount': (amount * 100).round(),
            'currency': 'INR',
            'name': 'Autonomous Printer',
            'description': 'Print order',
            'theme': {'color': '#2563EB'},
          });
        },
        (error, stack) {
          finish(
            const RazorpayWebPaymentResult(
              success: false,
              errorMessage: 'Checkout could not load. Check payment status.',
            ),
          );
        },
      );
      return await done.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () => const RazorpayWebPaymentResult(
          success: false,
          errorMessage:
              'Checkout timed out. Check payment status before paying again.',
        ),
      );
    } catch (_) {
      return const RazorpayWebPaymentResult(
        success: false,
        errorMessage: 'Checkout could not load. Check payment status.',
      );
    } finally {
      razorpay?.clear();
      _checkoutOpen = false;
    }
  }
}
