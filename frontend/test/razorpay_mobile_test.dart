import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/razorpay_platform_mobile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('razorpay_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  Future<dynamic> checkout() => RazorpayWebService.openCheckout(
    keyId: 'rzp_test_unit',
    orderId: 'order_unit',
    amount: 2,
  );

  test('native callback returns evidence for backend verification', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'resync') return null;
      expect(call.arguments['order_id'], 'order_unit');
      expect(call.arguments['amount'], 200);
      expect(call.arguments.containsKey('prefill'), isFalse);
      return {
        'type': 0,
        'data': {
          'razorpay_payment_id': 'pay_unit',
          'razorpay_order_id': 'order_unit',
          'razorpay_signature': 'signature',
        },
      };
    });
    final result = await checkout();
    expect(result.success, isTrue);
    expect(result.razorpaySignature, 'signature');
  });

  for (final data in [
    {
      'razorpay_payment_id': 'pay_unit',
      'razorpay_order_id': 'order_other',
      'razorpay_signature': 'signature',
    },
    {'razorpay_payment_id': 'pay_unit', 'razorpay_order_id': 'order_unit'},
  ]) {
    test('incomplete or mismatched callback fails: $data', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'resync' ? null : {'type': 0, 'data': data},
      );
      expect((await checkout()).success, isFalse);
    });
  }

  test(
    'async SDK exception fails safely and permits a later attempt',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'resync') return null;
        throw PlatformException(
          code: 'unavailable',
          message: 'internal details',
        );
      });
      for (var i = 0; i < 2; i++) {
        final result = await checkout();
        expect(result.success, isFalse);
        expect(result.errorMessage, isNot(contains('internal details')));
      }
    },
  );

  test('only one checkout opens at a time', () async {
    final response = Completer<Map<String, dynamic>>();
    var opens = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'resync') return null;
      opens++;
      return response.future;
    });
    final first = checkout();
    expect((await checkout()).success, isFalse);
    response.complete({
      'type': 1,
      'data': {'code': 2, 'message': 'cancelled'},
    });
    expect((await first).success, isFalse);
    expect(opens, 1);
  });

  test('desktop fails without invoking a mobile SDK', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    messenger.setMockMethodCallHandler(channel, (call) async {
      fail('Native checkout must not open on desktop');
    });
    expect((await checkout()).success, isFalse);
  });
}
